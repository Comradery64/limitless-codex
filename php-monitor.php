<?php
/**
 * limitless-codex shared hosting monitor
 *
 * Call this from cron or EasyCron every 30 seconds:
 * https://your-vps-ip:8080/check-and-reset
 *
 * Stores logs locally, never exposes credentials
 */

// Configuration
$CODEX_MONITOR_URL = getenv('CODEX_MONITOR_URL') ?: 'https://your-vps-ip:8080/check-and-reset';
$LOG_DIR = dirname(__FILE__) . '/logs';
$LOG_FILE = $LOG_DIR . '/limitless-codex.log';

// Create logs directory if needed
if (!is_dir($LOG_DIR)) {
    mkdir($LOG_DIR, 0700, true);
}

// Suppress SSL verification (for self-signed certs)
$context = stream_context_create([
    'ssl' => [
        'verify_peer' => false,
        'verify_peer_name' => false,
    ]
]);

$timestamp = date('Y-m-d\TH:i:s\Z');

try {
    // Call the monitor
    $response = @file_get_contents($CODEX_MONITOR_URL, false, $context);

    if ($response === false) {
        $error = error_get_last();
        $log = "[$timestamp] ERROR: Failed to reach monitor at $CODEX_MONITOR_URL\n";
        if ($error) {
            $log .= "[" . $timestamp . "] Error: " . $error['message'] . "\n";
        }
        file_put_contents($LOG_FILE, $log, FILE_APPEND | LOCK_EX);
        http_response_code(503);
        echo json_encode(['status' => 'error', 'message' => 'monitor unreachable']);
        exit;
    }

    $data = json_decode($response, true);

    // Log the response
    $log = "[$timestamp] Status: " . ($data['status'] ?? 'unknown');
    $log .= " | Usage: " . ($data['usedPercent'] ?? 'N/A') . "%";
    $log .= " | Resets in: " . ($data['resetsInMin'] ?? 'N/A') . "min";

    if ($data['resetTriggered'] ?? false) {
        $log .= " | 🚀 RESET TRIGGERED";
    }
    if (!empty($data['error'])) {
        $log .= " | Error: " . $data['error'];
    }
    $log .= "\n";

    file_put_contents($LOG_FILE, $log, FILE_APPEND | LOCK_EX);

    // Return response
    header('Content-Type: application/json');
    echo json_encode($data);

} catch (Exception $e) {
    $log = "[$timestamp] Exception: " . $e->getMessage() . "\n";
    file_put_contents($LOG_FILE, $log, FILE_APPEND | LOCK_EX);
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>
