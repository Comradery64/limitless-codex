# limitless-codex

Prevents Codex agent downtime by automatically resetting your rate limit before you hit the threshold.

## Problem

When you hit your Codex weekly rate limit, **all agents pause immediately**. If you're running 100+ agents, this is unacceptable.

**limitless-codex** monitors your usage and triggers a reset at 99.8% usage — before the hard limit stops everything.

## Features

- ✅ **Single binary** — compiled Go, ~3 MB
- ✅ **Minimal overhead** — 2.4 MB memory, 0% CPU
- ✅ **Long-lived connection** — one codex process, not 2,880/day
- ✅ **Smart logging** — only logs on changes (not every 30s poll)
- ✅ **Background service** — launchd on macOS, systemd on Linux
- ✅ **Zero downtime resets** — triggers before agents stop

## Installation

### Homebrew (macOS)

```bash
brew tap limitless-codex/tap
brew install limitless-codex
limitless-codex --start
```

### From source

```bash
git clone https://github.com/limitless-codex/limitless-codex
cd limitless-codex
make build
make install
```

### Docker

```bash
docker run -d \
  --name limitless-codex \
  --restart unless-stopped \
  -v ~/.codex:/root/.codex \
  ghcr.io/limitless-codex/limitless-codex
```

## Usage

### Start monitoring

```bash
limitless-codex --daemon
```

### View logs

```bash
tail -f ~/.local/var/log/limitless-codex.log
```

### Stop monitoring

```bash
limitless-codex --stop
```

### Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CODEX_BIN` | `~/.local/bin/codex` | Path to codex CLI |
| `THRESHOLD` | `99.8` | Reset threshold (%) |
| `POLL_INTERVAL_MS` | `30000` | Check interval (ms) |

## How it works

1. Connects to Codex CLI's app-server
2. Polls rate limit status every 30 seconds
3. When usage hits 99.8%, triggers a reset automatically
4. Logs only meaningful events (not every poll)
5. Sleeps 5 minutes after reset to avoid spam

## System impact

| Metric | Value |
|--------|-------|
| Memory | 2.4 MB |
| CPU | 0.0% |
| Processes | 1 (long-lived) |
| Log volume | 10-50 lines/day |

## Requirements

- Codex CLI authenticated (`codex login`)
- Go 1.23+ (for building from source)

## License

MIT

## Contributing

Issues and PRs welcome at https://github.com/limitless-codex/limitless-codex
