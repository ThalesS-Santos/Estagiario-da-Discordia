import test from "node:test";
import assert from "node:assert/strict";
import { handleRequest } from "../src/index.js";
import { sanitizeEffect, sanitizeRequest, parseModelJson } from "../src/validate.js";

const env = { GEMINI_API_KEY: "test-key-not-real", GEMINI_MODEL: "m1", GEMINI_FALLBACK_MODELS: "m2", RATE_LIMIT_PER_MINUTE: "1000" };
const body = {
  player_action: "Colocou frasco no poço", gossip: "O rei envenenou a água",
  npcs_state: { npc_baker: { fear: 30, anger: 20, loyalty: 40, credulity: 75 }, npc_guard: { fear: 10 }, hacker: { fear: 1 } },
  context: { day: 2, instability: 30, rumors: 1 },
};
const post = (b, extra = {}) => new Request("https://x/simulate", { method: "POST", body: JSON.stringify(b), headers: { "CF-Connecting-IP": "1.1.1.1", ...extra } });
const geminiReply = (obj) => new Response(JSON.stringify({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify(obj) }] } }] }));
const oneUpdate = { instability_delta: 5, npc_updates: [{ npc_id: "npc_guard", dialogue_bubble: "Hm.", new_state: "TALK", target_node_to_move: "", fear_level: 1, anger_level: 1, loyalty_level: 90 }] };

test("sanitizeRequest descarta NPCs desconhecidos", () => {
  const r = sanitizeRequest(body);
  assert.ok(r.ok);
  assert.deepEqual(Object.keys(r.value.npcs).sort(), ["npc_baker", "npc_guard"]);
});

test("sanitizeEffect é tolerante: ajusta valores e remove só o item ruim", () => {
  const eff = sanitizeEffect({ instability_delta: 99.4, npc_updates: [
    { npc_id: "npc_baker", dialogue_bubble: "Oi", new_state: "XXX", target_node_to_move: "well", fear_level: 150.6, anger_level: 3, loyalty_level: 5 },
    { npc_id: "npc_baker", dialogue_bubble: "duplicado" },
    { npc_id: "fantasma", dialogue_bubble: "?" },
    { npc_id: "npc_guard", dialogue_bubble: "x", new_state: "RUN", target_node_to_move: "../../etc", fear_level: 1, anger_level: 2, loyalty_level: 3 },
  ] }, new Set(["npc_baker", "npc_guard"]));
  assert.equal(eff.instability_delta, 45);
  assert.equal(eff.npc_updates.length, 2);
  assert.equal(eff.npc_updates[0].new_state, "TALK");
  assert.equal(eff.npc_updates[0].fear_level, 100);
  assert.equal(eff.npc_updates[1].target_node_to_move, "");
});

test("parseModelJson aceita cerca de markdown", () => {
  assert.deepEqual(parseModelJson("```json\n{\"a\":1}\n```"), { a: 1 });
});

test("fluxo feliz: chave vai no header, nunca na URL", async () => {
  let seen;
  const f = async (url, init) => { seen = { url, init }; return geminiReply(oneUpdate); };
  const res = await handleRequest(post(body), env, f);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.schema_version, 1);
  assert.equal(data.instability_delta, 5);
  assert.ok(!seen.url.includes("key"));
  assert.equal(seen.init.headers["x-goog-api-key"], "test-key-not-real");
  const sent = JSON.parse(JSON.parse(seen.init.body).contents[0].parts[0].text);
  assert.equal(sent.context.instability, 30);
});

test("cai para o modelo reserva quando o primeiro falha", async () => {
  const models = [];
  const f = async (url) => {
    models.push(url.match(/models\/([^:]+):/)[1]);
    return models.length <= 1 ? new Response("{}", { status: 404 }) : geminiReply(oneUpdate);
  };
  const res = await handleRequest(post(body), env, f);
  assert.equal(res.status, 200);
  assert.deepEqual(models, ["m1", "m2"]);
});

test("502 quando todos os modelos falham (o cliente usa o modo local)", async () => {
  const res = await handleRequest(post(body), env, async () => new Response("{}", { status: 500 }));
  assert.equal(res.status, 502);
});

test("rejeita entrada inválida, rota errada e servidor sem chave", async () => {
  assert.equal((await handleRequest(post({ x: 1 }), env, async () => geminiReply({}))).status, 400);
  assert.equal((await handleRequest(new Request("https://x/outra"), env)).status, 404);
  assert.equal((await handleRequest(post(body), {}, async () => geminiReply({}))).status, 503);
});

test("rate limit por IP", async () => {
  const small = { ...env, RATE_LIMIT_PER_MINUTE: "2" };
  const f = async () => geminiReply(oneUpdate);
  const req = () => post(body, { "CF-Connecting-IP": "9.9.9.9" });
  await handleRequest(req(), small, f);
  await handleRequest(req(), small, f);
  assert.equal((await handleRequest(req(), small, f)).status, 429);
});

test("recusa chave do Vertex (AQ.) com erro claro em vez de chamar o Google", async () => {
  let called = false;
  const res = await handleRequest(post(body), { ...env, GEMINI_API_KEY: "AQ.exemplo" }, async () => { called = true; return geminiReply({}); });
  assert.equal(res.status, 503);
  assert.equal((await res.json()).error, "wrong_key_type");
  assert.equal(called, false);
});
