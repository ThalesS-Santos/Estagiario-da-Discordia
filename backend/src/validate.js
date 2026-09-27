import { LOCATION_IDS, NPC_IDS, STATES } from "./world.js";

const clampInt = (v, lo, hi, fallback) => {
  const n = Number(v);
  if (v === null || v === undefined || v === "" || !Number.isFinite(n)) return fallback;
  return Math.min(hi, Math.max(lo, Math.round(n)));
};

/** Valida o pedido do jogo. Retorna {ok, value} ou {ok:false, error}. */
export function sanitizeRequest(body, maxNpcs = 64) {
  if (!body || typeof body !== "object") return { ok: false, error: "corpo inválido" };
  const action = typeof body.player_action === "string" ? body.player_action.slice(0, 2000) : "";
  const gossip = typeof body.gossip === "string" ? body.gossip.slice(0, 240) : "";
  const raw = body.npcs_state;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { ok: false, error: "npcs_state inválido" };
  const npcs = {};
  for (const [id, st] of Object.entries(raw)) {
    if (!NPC_IDS.has(id) || typeof st !== "object" || st === null) continue;
    if (Object.keys(npcs).length >= maxNpcs) break;
    npcs[id] = {
      name: String(st.name ?? "").slice(0, 40), role: String(st.role ?? "").slice(0, 40),
      fear: clampInt(st.fear, 0, 100, 0), anger: clampInt(st.anger, 0, 100, 0), loyalty: clampInt(st.loyalty, 0, 100, 50),
      credulity: clampInt(st.credulity, 0, 100, 50), current_state: STATES.includes(st.current_state) ? st.current_state : "IDLE",
      position: { x: clampInt(st.position?.x, 0, 1280, 0), y: clampInt(st.position?.y, 0, 960, 0) },
      memories: Array.isArray(st.memories) ? st.memories.slice(-4).map((m) => String(m).slice(0, 160)) : [],
    };
  }
  if (Object.keys(npcs).length === 0) return { ok: false, error: "nenhum NPC conhecido" };
  if (!action && !gossip) return { ok: false, error: "ação vazia" };
  const c = body.context && typeof body.context === "object" ? body.context : {};
  const context = {
    day: clampInt(c.day, 1, 3, 1), max_days: 3,
    instability: clampInt(c.instability, 0, 100, 0), rumors: clampInt(c.rumors, 0, 10000, 0),
    ap_remaining: clampInt(c.ap_remaining, 0, 10, 0),
  };
  if (Array.isArray(c.evidence)) context.evidence = c.evidence.slice(0, 20);
  if (Array.isArray(c.chain_events)) context.chain_events = c.chain_events.slice(0, 10);
  if (Array.isArray(c.active_events_in_progress)) context.active_events_in_progress = c.active_events_in_progress.slice(0, 5);
  if (c.mission && typeof c.mission === "object") context.mission = c.mission;
  if (c.player_position && typeof c.player_position === "object") {
    context.player_position = { x: clampInt(c.player_position.x, 0, 1280, 640), y: clampInt(c.player_position.y, 0, 960, 480) };
  }
  if (c.player_stealth === true) context.player_stealth = true;
  if (typeof c.held_object === "string" && c.held_object) context.held_object = c.held_object.slice(0, 60);
  if (c.constraints && typeof c.constraints === "object") context.constraints = c.constraints;
  return { ok: true, value: { action, gossip, npcs, context } };
}

/** Sanitiza a resposta do modelo de forma tolerante: ajusta o que dá, descarta só o item ruim. */
export function sanitizeEffect(data, allowedNpcs) {
  if (!data || typeof data !== "object") return null;
  const delta = clampInt(data.instability_delta, -20, 45, null);
  if (delta === null || !Array.isArray(data.npc_updates)) return null;
  const seen = new Set();
  const updates = [];
  for (const u of data.npc_updates) {
    if (updates.length >= 12) break;
    if (!u || typeof u !== "object") continue;
    const id = u.npc_id;
    if (!NPC_IDS.has(id) || !allowedNpcs.has(id) || seen.has(id)) continue;
    seen.add(id);
    const target = typeof u.target_node_to_move === "string" ? u.target_node_to_move : "";
    const targetOk = target === "" || LOCATION_IDS.has(target) || (NPC_IDS.has(target) && allowedNpcs.has(target) && target !== id);
    const upd = {
      npc_id: id,
      dialogue_bubble: String(u.dialogue_bubble ?? "").trim().slice(0, 240),
      new_state: STATES.includes(u.new_state) ? u.new_state : "TALK",
      target_node_to_move: targetOk ? target : "",
      fear_level: clampInt(u.fear_level, 0, 100, 0),
      anger_level: clampInt(u.anger_level, 0, 100, 0),
      loyalty_level: clampInt(u.loyalty_level, 0, 100, 50),
    };
    const sd = clampInt(u.suspicion_delta, -30, 30, null);
    if (sd !== null) upd.suspicion_delta = sd;
    updates.push(upd);
  }
  if (updates.length === 0) return null;
  const result = { schema_version: 1, instability_delta: delta, npc_updates: updates };
  if (Array.isArray(data.active_events)) {
    result.active_events = data.active_events
      .filter(e => e && typeof e === "object" && e.name)
      .slice(0, 3)
      .map(e => ({
        name: String(e.name ?? "").slice(0, 80),
        objective: String(e.objective ?? "").slice(0, 120),
        duration: Math.max(5, Math.min(60, Number(e.duration) || 20)),
        risk: Math.max(0, Math.min(100, Number(e.risk) || 50)),
        npc_ids: Array.isArray(e.npc_ids)
          ? [...new Set(e.npc_ids.filter(id => typeof id === "string" && allowedNpcs.has(id)))].slice(0, 5)
          : [],
        hint: String(e.hint ?? "").slice(0, 120),
        consequences: String(e.consequences ?? "").slice(0, 120),
        location: LOCATION_IDS.has(String(e.location ?? "")) ? String(e.location) : "",
      }));
  }
  const EVIDENCE_TYPES = ["weapon_found", "object_placed", "testimony", "overheard", "break_in", "forged_letter", "witness"];
  if (Array.isArray(data.evidence_created)) {
    result.evidence_created = data.evidence_created
      .filter(e => e && typeof e === "object" && typeof e.type === "string" && EVIDENCE_TYPES.includes(e.type))
      .slice(0, 3)
      .map(e => ({
        type: e.type,
        strength: clampInt(e.strength, 1, 50, 10),
        description: String(e.description ?? "").slice(0, 160),
        location: LOCATION_IDS.has(String(e.location ?? "")) ? String(e.location) : "",
      }));
    if (result.evidence_created.length === 0) delete result.evidence_created;
  }
  return result;
}

/** Extrai JSON do texto do modelo (tolera cercas de markdown). */
export function parseModelJson(text) {
  if (typeof text !== "string") return null;
  let t = text.trim();
  t = t.replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  try { return JSON.parse(t); } catch { /* tenta recortar */ }
  const a = t.indexOf("{"), b = t.lastIndexOf("}");
  if (a >= 0 && b > a) { try { return JSON.parse(t.slice(a, b + 1)); } catch { return null; } }
  return null;
}
