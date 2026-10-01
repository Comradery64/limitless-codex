# Running limitless-codex on a server

> **On a Mac, you don't need this guide.** Install the app with Homebrew and run `limitless-codex setup` (see the [README](README.md#install-macos)).

## Linux server (systemd)

The monitor needs an always-on machine with the `codex` CLI signed in to ChatGPT. Reset credits come with ChatGPT plans, so an API-key sign-in won't work.

**1. Create a user for it**

```bash
sudo useradd --create-home --shell /usr/sbin/nologin codex-monitor
```

**2. Install Codex and sign in as that user**

```bash
sudo npm install -g @openai/codex
sudo -u codex-monitor -H codex login --device-auth   # shows a code to enter on any device
```

**3. Install limitless-codex**

```bash
ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
sudo curl -fL -o /usr/local/bin/limitless-codex \
  https://github.com/Comradery64/limitless-codex/releases/latest/download/limitless-codex-linux-$ARCH
sudo chmod +x /usr/local/bin/limitless-codex
```

Or build it from source with Go: `make build && sudo cp bin/limitless-codex /usr/local/bin/`.

**4. Run it as a service**

```bash
sudo tee /etc/systemd/system/limitless-codex.service >/dev/null <<EOF
[Unit]
Description=limitless-codex (auto-reset Codex rate limit)
After=network-online.target
Wants=network-online.target

[Service]
User=codex-monitor
Environment=CODEX_BIN=$(command -v codex)
Environment=THRESHOLD=99
ExecStart=/usr/local/bin/limitless-codex --mode=daemon
Restart=always
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now limitless-codex
```

**5. Check on it**

```bash
journalctl -u limitless-codex -f
```

Linux has no desktop notifications for this. Resets, failures, and "no credits left" all appear in the log.

## HTTP mode (local integrations only)

```bash
limitless-codex --mode=http --listen=127.0.0.1:8080
```

- `GET /health`: health check
- `GET` or `POST /check-and-reset`: reads usage and resets if it's at the threshold

```json
{ "status": "ok", "usedPercent": 63, "resetsInMin": 8109, "availableCredits": 2, "timestamp": "2026-09-28T03:51:50Z" }
```

HTTP mode has **no authentication and no TLS**. Keep it on `127.0.0.1`. To reach it from another machine, use an SSH tunnel or a private network such as Tailscale. Never put it on a public port.

## Shared hosting (cPanel): planned

This isn't possible yet. Only the `codex` CLI can read usage and spend reset credits, and it can't run on typical shared hosting. A cPanel-only version would have PHP call ChatGPT's usage endpoints directly with your Codex sign-in token, scheduled by cPanel's built-in Cron Jobs. That approach is still being evaluated, because those endpoints aren't documented and the token would be stored on shared hosting.

`php-monitor.php` is the starting point for that work. Today it only forwards to a machine running HTTP mode.

## Security

- **Credentials:** your Codex sign-in stays in `~/.codex`, managed by the `codex` CLI. limitless-codex never reads or logs it.
- **Logs:** they contain usage percent, credit counts, and reset outcomes. No tokens, no account details.
- **Scope:** the only two actions are reading your rate limits and spending a reset credit.
- **Least privilege:** run it as a dedicated unprivileged user, as above, never as root.

## Troubleshooting

- **"No rate limit data" or RPC errors every poll:** the Codex sign-in expired. Run `sudo -u codex-monitor -H codex login --device-auth`.
- **"Failed to create Codex client":** `CODEX_BIN` doesn't point at `codex`. Check it with `command -v codex`.
- **A single `Error:` line:** usually a brief network blip. The monitor retries every 30 seconds and exits after 10 failures in a row, and systemd then restarts it.
