import { SYSTEM_PROMPT } from "./prompt.js";
import { LOCATIONS } from "./world.js";
import { parseModelJson, sanitizeEffect, sanitizeRequest } from "./validate.js";

const MAX_BODY_BYTES = 65536;
const GEMINI_ROOT = "https://generativelanguage.googleapis.com/v1beta/models/";
const PER_MODEL_TIMEOUT_MS = 12000;
const TOTAL_BUDGET_MS = 20000; // menor que o timeout do cliente (25 s)
const hits = new Map(); // ip -> timestamps; limite best effort por instância

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Idempotency-Key",
  "Access-Control-Max-Age": "86400",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...CORS },
  });

function rateLimited(ip, limit, now = Date.now()) {
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < 60000);
  recent.push(now);
  hits.set(ip, recent);
  if (hits.size > 5000) {
    for (const k of hits.keys()) {
      hits.delete(k);
      if (hits.size < 2500) break;
    }
  }
  return recent.length > limit;
}

function modelList(env) {
  const list = [env.GEMINI_MODEL || "gemini-2.5-flash", ...String(env.GEMINI_FALLBACK_MODELS || "").split(",")];
  return [...new Set(list.map((m) => m.trim()).filter((m) => /^[a-z0-9.\-]+$/i.test(m)))];
}

export function buildGeminiBody(model, req) {
  const cfg = { responseMimeType: "application/json", temperature: 0.9, maxOutputTokens: 2048 };
  if (model.startsWith("gemini-2.5")) cfg.thinkingConfig = { thinkingBudget: 0 }; // menos latência
  return {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{
      role: "user",
      parts: [{ text: JSON.stringify({
        context: req.context, player_action: req.action, gossip: req.gossip,
        npcs_state: req.npcs, allowed_locations: Object.keys(LOCATIONS),
      }) }],
    }],
    generationConfig: cfg,
  };
}

async function callModel(model, body, env, fetchFn, timeoutMs = PER_MODEL_TIMEOUT_MS) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    // Sempre a API do AI Studio (Generative Language). Chave no header, nunca na URL.
    const res = await fetchFn(`${GEMINI_ROOT}${encodeURIComponent(model)}:generateContent`, {
      method: "POST",
      signal: ctl.signal,
      headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      let reason = "";
      try { reason = String((await res.json())?.error?.status ?? ""); } catch { /* corpo não-JSON */ }
      return { error: `http_${res.status}${reason ? "_" + reason : ""}` };
    }
    const payload = await res.json();
    const cand = payload?.candidates?.[0];
    if (!cand || (cand.finishReason && cand.finishReason !== "STOP")) return { error: "blocked_or_truncated" };
    const text = (cand.content?.parts ?? []).filter((p) => !p.thought && typeof p.text === "string").map((p) => p.text).join("");
    return { text };
  } catch (e) {
    return { error: e?.name === "AbortError" ? "timeout" : "network" };
  } finally {
    clearTimeout(timer);
  }
}

export async function handleRequest(request, env, fetchFn = fetch) {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (url.pathname === "/health") {
    const k = String(env.GEMINI_API_KEY || "");
    const key_kind = !k ? "none" : k.startsWith("AIza") ? "aistudio" : k.startsWith("AQ.") ? "vertex" : "unknown"; // só a classe, nunca a chave
    return json({ ok: true, models: modelList(env), key_configured: Boolean(k), key_kind });
  }
  if (url.pathname !== "/simulate") return json({ error: "not_found" }, 404);
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!env.GEMINI_API_KEY) return json({ error: "server_not_configured" }, 503);
  if (String(env.GEMINI_API_KEY).startsWith("AQ.")) return json({ error: "wrong_key_type", detail: "use uma chave do AI Studio (começa com AIza)" }, 503);

  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  if (rateLimited(ip, Number(env.RATE_LIMIT_PER_MINUTE || 6))) return json({ error: "rate_limited" }, 429);

  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) return json({ error: "payload_too_large" }, 413);
  let parsed;
  try { parsed = JSON.parse(raw); } catch { return json({ error: "invalid_json" }, 400); }
  const req = sanitizeRequest(parsed);
  if (!req.ok) return json({ error: "bad_request", detail: req.error }, 400);

  const allowed = new Set(Object.keys(req.value.npcs));
  const tried = []; // diagnóstico sem segredos: modelo + motivo da recusa
  const started = Date.now();
  for (const model of modelList(env)) {
    for (let attempt = 0; attempt < 2; attempt++) { // 1 nova tentativa se a saída vier inválida
      const remaining = TOTAL_BUDGET_MS - (Date.now() - started);
      if (remaining < 2000) return json({ error: "ai_unavailable", tried }, 502);
      const out = await callModel(model, buildGeminiBody(model, req.value), env, fetchFn, Math.min(PER_MODEL_TIMEOUT_MS, remaining));
      if (out.error) { tried.push(`${model}:${out.error}`); break; } // rede/quota/modelo: próximo modelo
      const effect = sanitizeEffect(parseModelJson(out.text), allowed);
      if (effect) return json(effect);
      tried.push(`${model}:invalid_output`);
    }
  }
  return json({ error: "ai_unavailable", tried }, 502);
}

export default { fetch: (request, env) => handleRequest(request, env) };
