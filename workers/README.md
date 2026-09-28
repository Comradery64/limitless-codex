# Cloudflare Worker (experimental)

Checks Codex usage every minute and spends a reset credit at `THRESHOLD` (default 99.8%). No machine needs to stay on.

**Status:** unverified. `wrangler dev` got HTTP 403 from chatgpt.com (a Cloudflare HTML block page); plain Node from the same machine got 200. The consume endpoint path/body are inferred from the Codex binary and have not been exercised.

## Setup

1. `codex login` on any machine (use a **separate** login for the Worker — refresh tokens rotate, sharing one breaks the CLI session).
2. `cd workers && npx wrangler login`
3. `npx wrangler kv namespace create TOKENS` → put the `id` in `wrangler.toml`
4. Pipe each secret from `~/.codex/auth.json` without printing it, e.g.
   `jq -j .tokens.access_token ~/.codex/auth.json | npx wrangler secret put CODEX_ACCESS_TOKEN`
   (same for `refresh_token` → `CODEX_REFRESH_TOKEN`, `account_id` → `CODEX_ACCOUNT_ID`)
5. `npx wrangler deploy`, then watch `npx wrangler tail`

## Local test

Create `.dev.vars` (gitignored, `chmod 600`) with the same keys plus `CHECK_TOKEN=localtest` and `THRESHOLD=101` (never resets), then:

```bash
npx wrangler dev --test-scheduled
curl -H "Authorization: Bearer localtest" localhost:8787/
```

Expected: JSON with `usedPercent`. A `/usage: HTTP 403` means chatgpt.com is blocking the Workers runtime.
