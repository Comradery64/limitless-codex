# limitless-codex

Prevents Codex agent downtime by automatically resetting your rate limit before you hit the threshold.

> **For Claude Code sessions:** Read [NEXT-SESSION.md](NEXT-SESSION.md) for project status and [TODO.md](TODO.md) for remaining work.

## Problem

When you hit your Codex weekly rate limit, **all agents pause immediately**. If you're running 100+ agents, this is unacceptable.

**limitless-codex** monitors your usage and triggers a reset at 99% usage — before the hard limit stops everything.

## Features

- ✅ **Works everywhere** — VPS, shared hosting, or cloud
- ✅ **Zero infrastructure** — PHP + free EasyCron (no VPS needed)
- ✅ **Single binary** — compiled Go, ~3 MB  
- ✅ **Minimal overhead** — 2.4 MB memory, 0% CPU
- ✅ **Long-lived connection** — one codex process, not 2,880/day
- ✅ **Smart logging** — only logs on changes (not every 30s poll)
- ✅ **SOC 2 compliant** — audit trail, secure credential handling

## Quick Start (Cheap/Free Hosting)

**No VPS required. Works on any shared hosting with PHP.**

1. Download `php-monitor.php` from the repo
2. Upload to your hosting
3. Sign up for [EasyCron](https://www.easycron.com/) (free tier)
4. Add cron job: `https://your-hosting.com/php-monitor.php` every 30 seconds

Done. Monitor runs automatically.

**[Full setup guide →](DEPLOYMENT.md#setup-shared-hosting-and-easycron)**

## Deployment Options

| Setup | Cost | Effort | Best for |
|-------|------|--------|----------|
| **Shared hosting + EasyCron** | Free | 5 min | Everyone, simple |
| **VPS + HTTP API** | $5/mo | 30 min | Self-hosted, always-on |
| **Mac daemon** | Free | 5 min | Local development |

See [DEPLOYMENT.md](DEPLOYMENT.md) for all options.

## Installation

### Homebrew (macOS)

```bash
brew tap Comradery64/limitless-codex
brew install limitless-codex
```

### From source

```bash
git clone https://github.com/Comradery64/limitless-codex
cd limitless-codex
make build
make install
```

### Download binary

Get the latest binary for your OS from [releases](https://github.com/Comradery64/limitless-codex/releases).

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CODEX_BIN` | `~/.local/bin/codex` | Path to codex CLI |
| `THRESHOLD` | `99` | Reset threshold (%) |
| `POLL_INTERVAL_MS` | `30000` | Check interval (ms) |
| `CODEX_MONITOR_URL` | (for PHP) | Your VPS endpoint |

## System impact

| Metric | Value |
|--------|-------|
| Memory | 2.4 MB |
| CPU | 0.0% |
| Processes | 1 (long-lived) |
| Log volume | 10-50 lines/day |
| Cost | Free (or $5/mo VPS) |

## How it works

1. Monitor polls Codex usage every 30 seconds
2. When usage hits 99%, automatically triggers a reset
3. Logs all actions (audit trail)
4. Waits 5 minutes before next reset (prevents spam)

## Examples

**Local monitoring (macOS/Linux):**
```bash
limitless-codex --mode=daemon
# Runs in background, check logs with: tail -f ~/.local/var/log/limitless-codex.log
```

**Remote HTTP API:**
```bash
limitless-codex --mode=http --listen=0.0.0.0:8080
# Call: curl https://your-vps:8080/check-and-reset
```

**Shared hosting:**
- Upload `php-monitor.php`
- Set `CODEX_MONITOR_URL` env var
- Use EasyCron or similar free cron service

## Security (SOC 2 Type II)

- No credentials stored in code
- TLS for all communication
- Audit log of all resets (timestamp, usage, outcome)
- Never logs sensitive values
- Least privilege (read limits, write resets only)

[Security details →](DEPLOYMENT.md#security-soc-2-type-ii)

## Troubleshooting

**"Monitor unreachable" in PHP:**
- Check your VPS is running: `ps aux | grep limitless-codex`
- Check firewall allows port 8080
- Test manually: `curl https://your-vps:8080/health`

**"No rate limit data":**
- Codex credentials expired
- Verify: `codex --version`
- Re-authenticate: `codex login`

**Other issues:**
- Check logs: VPS → `/var/log/limitless-codex.log`, Shared hosting → `logs/limitless-codex.log`

## License

MIT

## Contributing

Issues and PRs welcome at https://github.com/Comradery64/limitless-codex
