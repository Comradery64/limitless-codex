// limitless-codex Cloudflare Worker: checks Codex usage on a cron and spends a
// reset credit at the threshold. Tokens live in KV (seeded from secrets) because
// OpenAI rotates the refresh token on every refresh.
const API = "https://chatgpt.com/backend-api/wham";
const CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"; // Codex CLI OAuth client

const jwtExp = (jwt) => JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))).exp * 1000 - 300_000;

async function tokens(env, force = false) {
  let t = JSON.parse((await env.TOKENS.get("tokens")) || "null") ||
    { access: env.CODEX_ACCESS_TOKEN, refresh: env.CODEX_REFRESH_TOKEN, exp: jwtExp(env.CODEX_ACCESS_TOKEN) };
  if (force || Date.now() > t.exp) {
    const r = await fetch("https://auth.openai.com/oauth/token", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ client_id: CLIENT_ID, grant_type: "refresh_token", refresh_token: t.refresh }),
    });
    if (!r.ok) throw new Error(`token refresh failed: HTTP ${r.status}`);
    const j = await r.json();
    t = { access: j.access_token, refresh: j.refresh_token || t.refresh, exp: jwtExp(j.access_token) };
    await env.TOKENS.put("tokens", JSON.stringify(t));
  }
  return t;
}

async function api(env, path, init = {}, retry = true) {
  const t = await tokens(env);
  const r = await fetch(API + path, { ...init, headers: { Authorization: `Bearer ${t.access}`,
    "ChatGPT-Account-Id": env.CODEX_ACCOUNT_ID, "Content-Type": "application/json", originator: "codex_cli_rs", "User-Agent": "codex_cli_rs/0.155.1" } });
  if (r.status === 401 && retry) { await tokens(env, true); return api(env, path, init, false); }
  if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
  return r.json();
}

async function check(env) {
  const u = await api(env, "/usage");
  const w = u.rate_limit?.primary_window ?? {};
  const out = { status: "ok", usedPercent: w.used_percent, resetsInMin: Math.round((w.reset_after_seconds ?? 0) / 60),
    creditsAvailable: u.rate_limit_reset_credits?.available_count ?? 0 };
  if (w.used_percent >= Number(env.THRESHOLD || 99.8) && out.creditsAvailable > 0) {
    const c = (await api(env, "/rate-limit-reset-credits")).credits.find((x) => x.status === "available" && x.is_supported_by_plan);
    if (c) {
      const r = await api(env, "/rate-limit-reset-credits/consume", { method: "POST",
        body: JSON.stringify({ credit_id: c.id, idempotency_key: c.id }) });
      Object.assign(out, { status: "reset_triggered", resetTriggered: true, outcome: r.outcome });
    }
  }
  console.log(JSON.stringify({ ts: new Date().toISOString(), ...out })); // audit trail -> Workers Logs
  return out;
}

export default {
  async scheduled(_e, env, ctx) { ctx.waitUntil(check(env)); },
  async fetch(req, env) { // manual check; requires the CHECK_TOKEN secret
    if (req.headers.get("Authorization") !== `Bearer ${env.CHECK_TOKEN}` || !env.CHECK_TOKEN) return new Response("unauthorized", { status: 401 });
    try { return Response.json(await check(env)); } catch (e) { return Response.json({ status: "error", error: e.message }, { status: 500 }); }
  },
};
