package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
	"time"
)

const (
	pollIntervalMs   = 30 * 1000  // 30 seconds
	thresholdPercent = 99.8
)

func getCodexBin() string {
	if bin := os.Getenv("CODEX_BIN"); bin != "" {
		return bin
	}
	// Default to common locations
	homeDir, _ := os.UserHomeDir()
	return homeDir + "/.local/bin/codex"
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

type RpcRequest struct {
	ID     int         `json:"id,omitempty"`
	Method string      `json:"method"`
	Params interface{} `json:"params,omitempty"`
}

type RpcResponse struct {
	ID     int             `json:"id"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *RpcError       `json:"error,omitempty"`
}

type RpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type ClientInfo struct {
	Name    string `json:"name"`
	Title   string `json:"title"`
	Version string `json:"version"`
}

type RateLimitInfo struct {
	UsedPercent       int `json:"usedPercent"`
	WindowDurationMins int `json:"windowDurationMins"`
	ResetsAt          int64 `json:"resetsAt"`
}

type RateLimitData struct {
	Primary *RateLimitInfo `json:"primary"`
}

type RateLimitResetCredit struct {
	ID        string `json:"id"`
	ResetType string `json:"resetType"`
	Status    string `json:"status"`
	ExpiresAt int64  `json:"expiresAt"`
}

type RateLimitResetCredits struct {
	AvailableCount int                        `json:"availableCount"`
	Credits        []RateLimitResetCredit `json:"credits"`
}

type RateLimitsResponse struct {
	RateLimits             *RateLimitData          `json:"rateLimits"`
	RateLimitResetCredits  *RateLimitResetCredits `json:"rateLimitResetCredits"`
}

type ConsumeResult struct {
	Outcome string `json:"outcome"`
}

type CodexClient struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Scanner
	nextID int
}

func NewCodexClient() (*CodexClient, error) {
	cmd := exec.Command(getCodexBin(), "app-server", "--stdio")

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}

	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	return &CodexClient{
		cmd:    cmd,
		stdin:  stdin,
		stdout: bufio.NewScanner(stdout),
		nextID: 1,
	}, nil
}

func (c *CodexClient) sendRequest(method string, params interface{}) (json.RawMessage, error) {
	id := c.nextID
	c.nextID++

	req := RpcRequest{
		ID:     id,
		Method: method,
		Params: params,
	}

	data, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	if _, err := fmt.Fprintf(c.stdin, "%s\n", string(data)); err != nil {
		return nil, err
	}

	// Read responses until we get ours (skip notifications)
	for c.stdout.Scan() {
		line := c.stdout.Bytes()

		var resp RpcResponse
		if err := json.Unmarshal(line, &resp); err != nil {
			continue
		}

		if resp.ID == id {
			if resp.Error != nil {
				return nil, fmt.Errorf("RPC error: %s", resp.Error.Message)
			}
			return resp.Result, nil
		}
	}

	return nil, fmt.Errorf("connection closed")
}

func (c *CodexClient) Initialize() error {
	params := map[string]ClientInfo{
		"clientInfo": {
			Name:    "codex_auto_reset",
			Title:   "Codex Auto Reset",
			Version: "1.0",
		},
	}

	_, err := c.sendRequest("initialize", params)
	if err != nil {
		return err
	}

	// Send initialized message
	msg := RpcRequest{Method: "initialized"}
	data, _ := json.Marshal(msg)
	fmt.Fprintf(c.stdin, "%s\n", string(data))

	return nil
}

func (c *CodexClient) CheckUsage() (*RateLimitsResponse, error) {
	result, err := c.sendRequest("account/rateLimits/read", nil)
	if err != nil {
		return nil, err
	}

	var resp RateLimitsResponse
	if err := json.Unmarshal(result, &resp); err != nil {
		return nil, err
	}

	return &resp, nil
}

func (c *CodexClient) TriggerReset(creditID string) (string, error) {
	params := map[string]string{
		"creditId":      creditID,
		"idempotencyKey": creditID,
	}

	result, err := c.sendRequest("account/rateLimitResetCredit/consume", params)
	if err != nil {
		return "", err
	}

	var consumeResult ConsumeResult
	if err := json.Unmarshal(result, &consumeResult); err != nil {
		return "", err
	}

	return consumeResult.Outcome, nil
}

func (c *CodexClient) Close() {
	c.stdin.Close()
	c.cmd.Wait()
}

func main() {
	client, err := NewCodexClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create Codex client: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	if err := client.Initialize(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("[%s] Codex Auto-Reset Monitor started (threshold: %.1f%%, polling every %dms)\n",
		time.Now().Format(time.RFC3339), thresholdPercent, pollIntervalMs)

	resetTriggered := false
	lastLoggedPercent := -1
	lastHeartbeat := time.Now()
	consecutiveErrors := 0
	const maxConsecutiveErrors = 10

	ticker := time.NewTicker(time.Duration(pollIntervalMs) * time.Millisecond)
	defer ticker.Stop()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case <-ticker.C:
			usage, err := client.CheckUsage()
			if err != nil {
				consecutiveErrors++
				fmt.Printf("[%s] ❌ Error: %v (%d/%d)\n", time.Now().Format(time.RFC3339), err, consecutiveErrors, maxConsecutiveErrors)
				if consecutiveErrors >= maxConsecutiveErrors {
					fmt.Printf("[%s] ❌ Too many consecutive errors, shutting down\n", time.Now().Format(time.RFC3339))
					return
				}
				continue
			}

			consecutiveErrors = 0

			if usage.RateLimits == nil || usage.RateLimits.Primary == nil {
				fmt.Printf("[%s] ❌ Error: No rate limit data\n", time.Now().Format(time.RFC3339))
				continue
			}

			usedPercent := usage.RateLimits.Primary.UsedPercent
			resetsAt := time.Unix(usage.RateLimits.Primary.ResetsAt, 0)
			resetsIn := int(time.Until(resetsAt).Minutes())
			creditsAvailable := 0
			if usage.RateLimitResetCredits != nil {
				creditsAvailable = len(usage.RateLimitResetCredits.Credits)
			}

			timestamp := time.Now().Format(time.RFC3339)

			// Log only if usage changed by 1% or more
			if lastLoggedPercent == -1 || abs(usedPercent-lastLoggedPercent) >= 1 {
				fmt.Printf("[%s] Usage: %d%% | Resets in: %dmin | Credits: %d\n",
					timestamp, usedPercent, resetsIn, creditsAvailable)
				lastLoggedPercent = usedPercent
			}

			// Hourly heartbeat
			if time.Since(lastHeartbeat) > time.Hour {
				fmt.Printf("[%s] 💓 Heartbeat: Usage: %d%% | Credits: %d\n",
					timestamp, usedPercent, creditsAvailable)
				lastHeartbeat = time.Now()
			}

			// Check threshold
			if float64(usedPercent) >= thresholdPercent && !resetTriggered {
				fmt.Printf("[%s] 🚨 THRESHOLD REACHED: %d%% usage\n", timestamp, usedPercent)

				if usage.RateLimitResetCredits != nil && len(usage.RateLimitResetCredits.Credits) > 0 {
					creditToUse := usage.RateLimitResetCredits.Credits[0]
					fmt.Printf("[%s] 🔄 Triggering reset...\n", timestamp)

					outcome, err := client.TriggerReset(creditToUse.ID)
					if err != nil {
						fmt.Printf("[%s] ❌ Reset failed: %v\n", timestamp, err)
					} else {
						fmt.Printf("[%s] ✅ Reset successful! Outcome: %s\n", timestamp, outcome)
						resetTriggered = true
						lastLoggedPercent = -1 // Reset logging to show new usage after reset

						// Sleep for 5 minutes after reset
						fmt.Printf("[%s] ⏸️  Pausing for 5 minutes...\n", timestamp)
						time.Sleep(5 * time.Minute)
						resetTriggered = false
					}
				} else {
					fmt.Printf("[%s] ⚠️  Threshold reached but no credits available!\n", timestamp)
				}
			}

		case sig := <-sigChan:
			fmt.Printf("[%s] Shutting down (signal: %v)\n", time.Now().Format(time.RFC3339), sig)
			return
		}
	}
}
