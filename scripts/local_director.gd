class_name LocalDirector
extends RefCounted
## Diretor de Cena offline: gera roteiros no mesmo formato JSON que a IA do backend,
## usando tags dos objetos, atributos dos NPCs e palavras-chave da narrativa.

const NPC_WORDS := {
	"npc_king": ["rei", "aldemar", "coroa", "castelo", "trono", "real"],
	"npc_baker": ["padeiro", "joao", "padaria", "pao", "farinha"],
	"npc_smith": ["ferreiro", "gordo", "marten", "ferraria", "forja", "martelo"],
	"npc_guard": ["guarda", "bram", "capitao", "soldado"],
	"npc_priestess": ["sacerdotisa", "mira", "templo", "sagrad", "reliquia", "deus"],
	"npc_merchant": ["mercador", "valdo", "banca"],
	"npc_orphan": ["lila", "orfa", "crianca"],
}
const LOC_NPC := {
	"bakery": "npc_baker", "forge": "npc_smith", "temple": "npc_priestess",
	"castle_gate": "npc_guard", "castle_yard": "npc_guard", "throne": "npc_king",
	"plaza": "npc_merchant", "fountain": "npc_baker", "well": "npc_baker", "notice_board": "npc_guard",
	"stall": "npc_merchant", "lake": "npc_orphan", "residence": "npc_baker", "forest": "npc_orphan",
	"road_south": "npc_merchant", "open_field": "npc_baker",
}
const LOC_WORDS := {
	"bakery": ["padaria", "forno"], "forge": ["ferraria", "forja", "bigorna"], "temple": ["templo", "altar"],
	"lake": ["lago", "agua", "peixe"], "well": ["poco", "agua"], "fountain": ["fonte", "agua"],
	"castle_gate": ["portao", "castelo"], "castle_yard": ["patio", "castelo"], "throne": ["trono", "castelo"],
	"notice_board": ["decreto", "poste"], "plaza": ["praca"],
}
const VERBS := ["envenen", "roub", "traic", "mat", "minti", "conspir", "escond", "furt", "planej", "culp", "acus", "sabot", "trocou", "mandou", "viu", "visto", "prova", "segredo"]
const GOSSIPS := ["npc_baker", "npc_merchant"]


static func norm(s: String) -> String:
	var r := s.to_lower()
	for pair in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		r = r.replace(pair[0], pair[1])
	return r


static func _ev(t: float, npc: String, action: String, target := "", dialogue := "", particles: Array = [], sound := "") -> Dictionary:
	return {"t": t, "npc_id": npc, "action": action, "target": target, "dialogue": dialogue, "particles": particles, "sound": sound}


static func _short(s: String, n := 46) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"


static func generate(p: Dictionary) -> Dictionary:
	var actions: Array = p.get("actions", [])
	var rumors := int(p.get("rumors", 0))
	var day := int(p.get("day", 1))
	var events: Array = []
	var delta := 0.0
	var wc := {}
	var budget := 12
	var n := actions.size()
	var ambient_slots := 3 if (rumors > 0 or n == 0) else 0
	for i in n:
		var r := _action(actions[i], day, i * 20.0, p.get("world_state", {}).get("npcs", {}))
		var cap: int = maxi(4, int(float(budget - ambient_slots) / float(n)))
		var ordered: Array = r.events
		ordered.sort_custom(func(a, b): return a.t < b.t)
		events.append_array(ordered.slice(0, cap))
		delta += r.delta
		wc.merge(r.wc, true)
	if rumors > 0 or n == 0:
		var t0 := n * 20.0
		var merchant_here := day < 3
		var g := "npc_merchant" if merchant_here else "npc_baker"
		events.append(_ev(t0, "npc_baker", "walk_to", "plaza"))
		events.append(_ev(t0 + 4, g, "talk_to", "npc_baker", "Ainda falam daquele boato do Rei...", ["crowd_murmur"], "murmur"))
		events.append(_ev(t0 + 7, "npc_baker", "spawn_crowd_reaction", "plaza 6", "", ["crowd_murmur"], "murmur"))
		delta += minf(rumors * 4.0, 12.0) if rumors > 0 else 2.0
	events.sort_custom(func(a, b): return a.t < b.t)
	return {"events": events.slice(0, 12), "instability_delta": snappedf(delta, 0.1), "world_changes": wc}


## Converte o roteiro local para o mesmo contrato do Gemini ({instability_delta, npc_updates}).
## Usado como reserva quando o servidor de IA está indisponível, para o jogo nunca travar.
static func ai_result(p: Dictionary, states: Dictionary, location_ids: Array) -> Dictionary:
	var sim := generate(p)
	var updates: Dictionary = {}
	for e in sim.events:
		var id: String = str(e.npc_id)
		if not states.has(id):
			continue
		var st: Dictionary = states[id]
		var u: Dictionary = updates.get(id, {"npc_id": id, "dialogue_bubble": "", "new_state": "IDLE", "target_node_to_move": "",
			"fear_level": int(st.get("fear", 0)), "anger_level": int(st.get("anger", 0)), "loyalty_level": int(st.get("loyalty", 50))})
		if u.dialogue_bubble == "" and str(e.dialogue) != "":
			u.dialogue_bubble = str(e.dialogue).left(120)
		match str(e.action):
			"run_to", "flee":
				u.new_state = "RUN"
				u.fear_level = mini(int(u.fear_level) + 20, 100)
			"shout", "attack":
				u.new_state = "ANGRY"
				u.anger_level = mini(int(u.anger_level) + 15, 100)
			"talk_to":
				if u.new_state != "ANGRY" and u.new_state != "RUN":
					u.new_state = "TALK"
			"fall_down":
				u.new_state = "FALLEN"
			"walk_to":
				if u.new_state == "IDLE":
					u.new_state = "WALK"
		var target := str(e.target)
		if u.target_node_to_move == "" and (location_ids.has(target) or (states.has(target) and target != id)):
			u.target_node_to_move = target
		updates[id] = u
	if updates.is_empty() and not states.is_empty():
		var first: String = states.keys()[0]
		updates[first] = {"npc_id": first, "dialogue_bubble": "Que coisa estranha...", "new_state": "TALK", "target_node_to_move": "",
			"fear_level": int(states[first].get("fear", 0)), "anger_level": int(states[first].get("anger", 0)),
			"loyalty_level": int(states[first].get("loyalty", 50))}
	return {"schema_version": 1, "instability_delta": clampi(int(round(float(sim.instability_delta))), -20, 45),
		"npc_updates": updates.values().slice(0, 12)}


static func _action(a: Dictionary, day: int, t0: float, states: Dictionary = {}) -> Dictionary:
	var narrative: String = str(a.get("narrative", "")).strip_edges()
	var text := norm(narrative)
	var tags: Array = a.get("tags", [])
	var loc: String = str(a.get("location", "open_field"))
	var obj: String = str(a.get("object_id", ""))
	var ev: Array = []
	var wc := {}

	# NPC mencionado (não-rei) ou dono do local
	var mentioned: Array = []
	for id in NPC_WORDS:
		for w in NPC_WORDS[id]:
			if text.contains(w):
				mentioned.append(id)
				break
	var target := ""
	for id in mentioned:
		if id != "npc_king":
			target = id
			break
	if target == "":
		target = LOC_NPC.get(loc, "npc_baker")
	if target == "npc_merchant" and day >= 3:
		target = "npc_baker"
	var gossip := "npc_baker" if (target != "npc_baker") else ("npc_merchant" if day < 3 else "npc_smith")
	var hits_king := mentioned.has("npc_king") or text.contains("rei")

	# conexão da narrativa com o objeto / local / ações
	var connected := false
	if narrative.length() >= 8:
		if not mentioned.is_empty() or LOC_WORDS.has(loc) and _any(text, LOC_WORDS[loc]):
			connected = true
		for w in norm(str(a.get("object_name", ""))).split(" "):
			if w.length() >= 4 and text.contains(w):
				connected = true
		if _any(text, VERBS):
			connected = true
	var hook := _short(narrative if narrative != "" else str(a.get("object_name", "")))

	if narrative == "":
		# soltou sem boato: só reação ao objeto
		var d0 := 3.0 if (tags.has("veneno") or tags.has("real") or tags.has("sagrado")) else 1.0
		ev.append(_ev(t0, target, "walk_to", loc))
		ev.append(_ev(t0 + 3, target, "pick_up", obj, "", ["question"], "gasp"))
		ev.append(_ev(t0 + 5, target, "shout", "", "Quem deixou isso aqui?", ["question"], "shout"))
		return {"events": ev, "delta": d0, "wc": wc}
	if not connected:
		ev.append(_ev(t0, target, "walk_to", loc))
		ev.append(_ev(t0 + 3, target, "talk_to", gossip, "Ouvi algo estranho... mas ninguém acredita.", ["question"], "murmur"))
		ev.append(_ev(t0 + 5, gossip, "talk_to", target, "Hã? Não faz sentido.", ["question"], ""))
		return {"events": ev, "delta": 2.0, "wc": wc}

	# cálculo do delta
	var base := 4.0
	var weights := {"veneno": 14.0, "sagrado": 14.0, "real": 12.0, "arma": 12.0, "escrito": 10.0, "comida": 6.0}
	for t in tags:
		base = maxf(base, float(weights.get(t, 4.0)))
	if tags.size() >= 2:
		base += 3.0
	if hits_king:
		base += 6.0
	if _any(text, ["envenen", "traic", "roub", "conspir", "mat", "sabot"]):
		base += 5.0
	var state: Dictionary = states.get(target, Game.npc_state.get(target, Game.NPC_DEFS[target]))
	var cred := float(state.get("credulity", state.get("cred", 50))) / 100.0
	var delta := base * (0.6 + cred)
	delta *= 1.0 + (float(state.get("anger", 0)) + float(state.get("fear", 0)) - float(state.get("loyalty", 50))) / 500.0
	if (tags.has("sagrado") and target == "npc_priestess") or (tags.has("arma") and target == "npc_smith") or (tags.has("comida") and target == "npc_baker"):
		delta *= 1.5
	if loc == "castle_yard" or loc == "throne":
		delta += 8.0  # risco alto no castelo
	delta = clampf(round(delta), 3.0, 40.0)

	# roteiro
	ev.append(_ev(t0, target, "walk_to", loc))
	ev.append(_ev(t0 + 3, target, "pick_up", obj, "", ["question"], "gasp"))
	ev.append(_ev(t0 + 5, target, "shout", "", "Vejam! " + hook, ["exclamation"], "shout"))
	ev.append(_ev(t0 + 6, target, "spawn_crowd_reaction", loc + " 6", "", ["crowd_murmur"], "murmur"))
	ev.append(_ev(t0 + 8, gossip, "talk_to", target, "Ouviu? " + hook, ["crowd_murmur"], "murmur"))
	ev.append(_ev(t0 + 11, gossip, "run_to", "plaza", "", ["dust_small"]))
	ev.append(_ev(t0 + 13, gossip, "shout", "", "O povo precisa saber! O Rei anda escondendo algo!", ["exclamation"], "shout"))
	if delta >= 14:
		ev.append(_ev(t0 + 14, "npc_guard", "run_to", loc, "", ["dust_small"]))
		ev.append(_ev(t0 + 15, "npc_orphan", "flee", "south", "", ["exclamation", "tears"], "gasp"))
	if tags.has("veneno") and ["lake", "well", "fountain"].has(loc):
		ev.append(_ev(t0 + 9, target, "change_water_color", "#6fa050", "", ["poison_bubbles"], "bubble"))
		ev.append(_ev(t0 + 10, gossip, "fall_down", "", "", ["stars_dizzy"], "thud"))
		wc["water_poisoned"] = true
	if delta >= 24 and (target == "npc_smith" or tags.has("arma")):
		ev.append(_ev(t0 + 16, "npc_smith", "attack", "npc_guard", "Traidor!", ["anger_symbol", "sparkle_red"], "thud"))
		ev.append(_ev(t0 + 18, "npc_smith", "screen_shake", "2", "", [], "thud"))
	if delta >= 30:
		ev.append(_ev(t0 + 19, "npc_guard", "screen_shake", "2", "", ["instability_pulse"], "tension"))
	return {"events": ev, "delta": delta, "wc": wc}


static func _any(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false
