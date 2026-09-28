# Remaining Work for limitless-codex

## High Priority (v1.2.0)

- [ ] **Build Cloudflare Workers option**
  - Create `workers/limitless-codex.js`
  - Setup `wrangler.toml` configuration
  - Test with `wrangler dev`
  - Publish to Cloudflare (free account)
  - Document setup steps

- [ ] **Update README.md**
  - Add CF Workers to quick start (equal to PHP option)
  - Update deployment options table
  - Emphasize: ALL options are FREE

- [ ] **Update DEPLOYMENT.md**
  - Reorder: CF Workers first, then PHP, then local
  - Add CF Workers detailed section
  - Add security notes for each option

- [ ] **Create EXAMPLES.md**
  - Comparison table (CF vs PHP vs Local)
  - Pros/cons for each
  - When to choose which
  - Full step-by-step for all three

## Medium Priority

- [ ] **Create example configs**
  - `examples/workers/wrangler.toml`
  - `examples/workers/wrangler.example.toml` (with docs)
  - `examples/php-monitor.example.php` (annotated)
  - `examples/systemd/limitless-codex.service`

- [ ] **Add CF Workers to release pipeline**
  - Maybe publish to GitHub + npm registry
  - Document installation options

- [ ] **Expand security docs**
  - Credential rotation strategy
  - Audit log analysis guide
  - Incident response playbook

## Low Priority (future)

- [ ] Kubernetes Helm chart (overkill but nice to have)
- [ ] Docker image (might add, low demand)
- [ ] AWS Lambda option (if demand)
- [ ] GitHub Actions workflow integration
- [ ] Slack/Discord alerts on resets
- [ ] Web dashboard for monitoring

## Testing Checklist

- [ ] Test CF Workers locally with `wrangler dev`
- [ ] Test PHP script on actual shared hosting (InfinityFree or similar)
- [ ] Test EasyCron integration end-to-end
- [ ] Test local daemon on macOS + Linux
- [ ] Verify logs don't contain credentials (grep for secrets)
- [ ] Verify reset actually works in each environment

---

## Definition of Done for v1.2.0

✅ All three deployment options fully documented
✅ Each option has a complete example
✅ README clearly states all options are FREE
✅ DEPLOYMENT.md includes all three methods equally
✅ At least one option tested end-to-end (CF Workers)
✅ No VPS/paid options mentioned
✅ SOC 2 compliance maintained
