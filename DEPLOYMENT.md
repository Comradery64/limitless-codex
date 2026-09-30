# limitless-codex Deployment Guide

## Modes

### Daemon Mode (VPS - Always Running)

```bash
limitless-codex --mode=daemon
```

Runs as a long-lived process, polls Codex every 30 seconds, auto-resets at threshold.

**Recommended for:** Production, dedicated servers, always-on environments.

### HTTP Mode (VPS - API Server)

```bash
limitless-codex --mode=http --listen=127.0.0.1:8080
```

Exposes HTTP API endpoints:
- `GET /health` — Health check
- `POST /check-and-reset` — Check usage and reset if needed

Returns JSON:
```json
{
  "status": "ok|reset_triggered|error",
  "usedPercent": 63,
  "resetsInMin": 8109,
  "availableCredits": 2,
  "timestamp": "2026-09-28T03:51:50Z",
  "error": null
}
```

**Recommended for:** Shared hosting integration, remote monitoring.

---

## Setup: VPS with HTTP API + EasyCron

### 1. Deploy on VPS

```bash
# Build release binary
make build

# Copy to VPS
scp bin/limitless-codex user@your-vps:/usr/local/bin/

# Run HTTP server
ssh user@your-vps
nohup /usr/local/bin/limitless-codex --mode=http --listen=0.0.0.0:8080 > /var/log/limitless-codex.log 2>&1 &
```

### 2. Set up firewall (VPS)

```bash
# Allow only HTTPS on port 8080 from EasyCron
ufw allow from 35.190.0.0/16 to any port 8080
ufw allow from 34.117.0.0/16 to any port 8080
```

EasyCron IP ranges: Check https://www.easycron.com/status

### 3. Configure shared hosting

Upload `php-monitor.php` to your shared hosting:

```bash
sftp user@shared-hosting.com
put php-monitor.php /public_html/codex-monitor.php
```

Edit the file to set your VPS URL:
```php
$CODEX_MONITOR_URL = 'https://your-vps-ip:8080/check-and-reset';
```

### 4. Set up EasyCron (free)

1. Go to https://www.easycron.com/
2. Click "Add Cron Job"
3. Set URL to: `https://your-shared-hosting.com/codex-monitor.php`
4. Set interval: Every 30 seconds
5. Save

EasyCron will call your PHP script every 30 seconds → PHP calls your VPS → Resets trigger automatically.

### 5. View logs

**On VPS:**
```bash
tail -f /var/log/limitless-codex.log
```

**On shared hosting:**
```bash
# Via SFTP, download:
logs/limitless-codex.log
```

---

## Setup: Local VPS (Daemon Mode)

### 1. Build and install

```bash
make build
make install
```

### 2. Create systemd service

```bash
sudo tee /etc/systemd/system/limitless-codex.service <<EOF
[Unit]
Description=Codex Auto-Reset Monitor
After=network.target

[Service]
Type=simple
User=codex-monitor
ExecStart=/usr/local/bin/limitless-codex --mode=daemon
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable limitless-codex
sudo systemctl start limitless-codex
sudo journalctl -u limitless-codex -f
```

---

## Security (SOC 2 Type II)

### Credentials

- **VPS HTTP mode:** Token read at startup from `CODEX_BIN` environment
- **Shared hosting:** No tokens stored locally, all calls proxied through VPS
- **Never log credentials:** Check `/var/log/limitless-codex.log` — credentials never appear

### Audit Logging

All actions logged with timestamp:
```
[2026-09-28T03:51:50Z] Usage: 63% | Resets in: 8109min | Credits: 2
[2026-09-28T04:21:50Z] Usage: 64% | Resets in: 8108min | Credits: 2
[2026-09-28T05:51:50Z] 🚨 THRESHOLD REACHED: 99% usage
[2026-09-28T05:51:51Z] ✅ Reset successful! Outcome: reset
```

### TLS

- Use HTTPS for all remote calls
- Accept self-signed certs in PHP: (already configured in `php-monitor.php`)
- Rotate credentials regularly in Vault (if using)

### Least Privilege

- Monitor only reads rate limits and writes resets
- No access to billing, identity, or other APIs
- Run as unprivileged user (not root)

---

## Troubleshooting

### "Monitor unreachable"

Check VPS firewall and that server is running:
```bash
ssh user@your-vps
ps aux | grep limitless-codex
curl http://127.0.0.1:8080/health
```

### "No rate limit data"

Codex credentials expired. Verify:
```bash
codex --version  # Should work
~/.codex/  # Credentials exist
```

### PHP logs show errors

Check `logs/limitless-codex.log` on shared hosting for the actual error response from VPS.
