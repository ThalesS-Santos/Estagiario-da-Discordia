extends Node2D
## Mundo da aldeia: mapa, NPCs, objetos, fase de ação (jogador) e fase de simulação (IA).

signal victory
signal defeat
@warning_ignore("unused_signal")
signal quit_to_menu

enum Phase { ACTION, TERMINAL, SIM, ACTIVE_EVENT, PURSUIT, CONFRONTATION, ENDED }

const HudScript := preload("res://scripts/hud.gd")
const GeminiScript := preload("res://scripts/gemini_director.gd")

var gemini_director: GeminiDirector
var ai_fallback_enabled := true ## se a IA falhar, usa o Diretor local para o jogo nunca travar
var ai_waiting := false
var pending_gossip := {}
var location_nodes := {}
var _ending_day := false
var _sim_clock_from := 8.0
var _sim_clock_to := 8.0

var phase: int = Phase.ACTION
var tutorial := false
var intro_active := false ## visor de pulso + portal: jogador e cliques do mundo bloqueados
var show_names := true
var npcs: Dictionary = {}
var objects: Dictionary = {}
var held: WorldObject = null
var held_from := Vector2.ZERO
var drop_pos := Vector2.ZERO
var actions_today: Array = []
var hud
var cam: Camera2D
var mod: CanvasModulate
var npc_root: Node2D
var obj_root: Node2D
var fx_root: Node2D
var time := 0.0
var clock := 8.0
var water_color := Color(0.16, 0.42, 0.69)
var poisoned := false
var fish_dead := false
var wind := 1.0
var shake := 0.0
var torch_on := true
var castle_damage := 0
var flag_drop := 0.0
var gate_open := 0.0
var hovered_obj = null
var hovered_npc = null
var cam_target := Vector2(640, 380)
var follow = null
var _shadowing_npc: NPC = null  # NPC que o jogador está seguindo (ação "follow")
var cam_zoom := 1.0
var cam_limit_bottom := Game.MAP_SIZE.y
var sim_events: Array = []
var sim_time := 0.0
var sim_idx := 0
var sim_end := 0.0
var crisis := false
var day_revision := 0
var sim_running := false
var _instability_added_today := 0.0  # Feature 2: trava diária de instabilidade
var _panic_tick := 0.0               # Feature 3: ticker de pânico visual dos NPCs
var _revolt_active := false          # true assim que a instabilidade chega a 100%
var _revolt_fires: Array = []
var snapshot := {}
var rings: Array = []
var _active_event_current: Dictionary = {}
var _active_event_queue: Array = []
var _last_action_effect := true  # setado por _apply_action_specific, lido por _did_action_succeed
var _tension_t := 0.0
var _phase_before_confrontation: int = Phase.ACTION
var exposure_count := 0       # quantas vezes flagrado com item suspeito (2 = game over)
var _osric_alerted := false   # Osric já alertou Bram neste ciclo (evita spam)
var _alert_mode := false      # Bram em alerta extra após Osric reportar
var _alert_mode_t := 0.0
var village: Village
var villagers: Array = []
var overlay: Overlay
var player: PlayerIntern
var gossip_npc: NPC = null
var mission: MissionPortao = null
const PlayerScene := preload("res://scenes/player_intern.tscn")


class Overlay extends Node2D:
	## Anéis de narrativa e marcador do objeto carregado (feedback de interface).
	var world

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for r in world.rings:
			var a: float = 1.0 - float(r.age) / 1.2
			var shout: bool = r.get("shout", false)
			var col := Color(1.0, 0.85, 0.3, a * 0.8) if not shout else Color(1, 1, 1, a * 0.5)
			draw_arc(r.p, float(r.age) * (160.0 if not shout else 96.0), 0, TAU, 40, col, 3.0)


func _ready() -> void:
	village = Village.new()
	add_child(village)
	npc_root = village.ysort
	obj_root = Node2D.new()
	obj_root.z_index = 3
	fx_root = Node2D.new()
	fx_root.z_index = 6
	add_child(obj_root)
	add_child(fx_root)
	overlay = Overlay.new()
	overlay.world = self
	overlay.z_index = 7
	add_child(overlay)
	for id in Game.NPC_DEFS:
		var n := NPC.new()
		n.setup(id, Game.NPC_DEFS[id], self)
		npc_root.add_child(n)
		npcs[id] = n
	var vdata: Dictionary = village.data.get("villagers", {})
	for vid in vdata:
		var n := NPC.new()
		var p: Array = vdata[vid]
		var vd: Dictionary = Game.VILLAGER_DEFS.get(vid, {"name": "Aldeão", "role": "Aldeão", "fear": 30, "anger": 20, "loyalty": 50, "cred": 50}).duplicate()
		vd["size"] = Vector2(28, 44)
		vd["home_pos"] = Vector2(float(p[0]), float(p[1]))
		# menino não faz wander largo pois passa por cima de telhados
		vd["wide_wander"] = vid != "villager_boy"
		n.setup(vid, vd, self)
		npc_root.add_child(n)
		villagers.append(n)
	for id in Game.OBJECTS:
		var d: Dictionary = Game.OBJECTS[id]
		var o := WorldObject.new()
		o.setup(id, d, Game.loc_pos(d.loc) + d.off)
		o.item_dropped.connect(_on_item_dropped)
		obj_root.add_child(o)
		objects[id] = o
	cam = Camera2D.new()
	add_child(cam)
	cam.position = cam_target
	mod = CanvasModulate.new()
	add_child(mod)
	_build_ai_locations()
	gemini_director = _create_gemini_director()
	gemini_director.name = "GeminiDirector"
	gemini_director.allowed_locations = PackedStringArray(location_nodes.keys())
	add_child(gemini_director)
	gemini_director.butterfly_effect_calculated.connect(_on_caos_gerado)
	gemini_director.ai_error.connect(_on_gemini_error)
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	hud.gossip_submitted.connect(_on_gossip_submitted)
	_build_player()
	_build_mission()
	_restore_checkpoint(Game.world_checkpoint)
	_start_day()
	if tutorial:
		_play_intro()


func _create_gemini_director() -> GeminiDirector:
	return GeminiScript.new()


func _build_ai_locations() -> void:
	var locations := Node2D.new()
	locations.name = "AILocations"
	add_child(locations)
	for id in Game.LOCATIONS:
		var marker := Marker2D.new()
		marker.name = id
		marker.position = Game.loc_pos(id)
		locations.add_child(marker)
		location_nodes[id] = marker


func _ai_actors() -> Dictionary:
	var actors := {}
	for npc: NPC in npcs.values() + villagers:
		if is_instance_valid(npc) and npc.visible:
			actors[npc.id] = npc
	return actors


func get_ai_target(id: String) -> Node2D:
	if location_nodes.has(id):
		return location_nodes[id]
	return _ai_actors().get(id)


func _live_npc_states() -> Dictionary:
	var states := {}
	for npc: NPC in _ai_actors().values():
		var saved: Dictionary = Game.npc_state.get(npc.id, {})
		states[npc.id] = {"name": npc.def.get("name", npc.id), "role": npc.def.get("role", ""),
			"fear": npc.fear, "anger": npc.anger, "loyalty": npc.loyalty,
			"credulity": saved.get("cred", npc.def.get("cred", 50)),
			"current_state": npc.current_state,
			"suspicion": int(npc.suspicion),
			"suspicion_state": NPC.SuspicionState.keys()[npc.suspicion_state],
			"pursuing": npc.pursuing,
			"position": {"x": npc.global_position.x, "y": npc.global_position.y},
			"memories": saved.get("memories", []).duplicate()}
	return states


func _on_gossip_submitted(_context: Dictionary, text: String) -> void:
	terminal_submit(text)


func _request_caos(narrative: String) -> void:
	if ai_waiting or gemini_director._busy or (held == null and gossip_npc == null):
		return
	var action: String
	if held:
		action = "Colocou %s (id: %s; características: %s) em %s (id: %s)." % [
			held.def.name, held.id, ", ".join(held.def.tags),
			Game.loc_name(Game.nearest_location(drop_pos)), Game.nearest_location(drop_pos)]
	else:
		action = "Sussurrou para %s (id: %s) em %s, sem mover um objeto." % [
			gossip_npc.def.name, gossip_npc.id, Game.loc_name(Game.nearest_location(gossip_npc.position))]
	pending_gossip = {"text": narrative, "player_action": action}
	if mission and narrative != "" and mission.has_method("notify_gossip_sent"):
		mission.notify_gossip_sent(narrative)
	# Capture live states before stopping movement or changing the simulation phase.
	var states := _live_npc_states()
	phase = Phase.SIM
	ai_waiting = true
	player.input_enabled = false
	hud.close_terminal()
	hud.set_sim(true)
	hud.set_loading(true) # Must precede evaluate: local validation can fail synchronously.
	var context := {
		"day": Game.day, "max_days": Game.MAX_DAYS,
		"instability": Game.instability, "rumors": Game.rumors,
		"ap_remaining": Game.ap,
		"player_position": {"x": int(player.global_position.x), "y": int(player.global_position.y)},
		"player_stealth": player.get("state") == PlayerIntern.State.STEALTH,
		"held_object": held.def.name if held else "",
		"reputation": Game.reputation.duplicate(),
	}
	var active_evidence := Game.evidence_summary()
	if not active_evidence.is_empty():
		context["evidence"] = active_evidence
	var active_events := Game.events_summary_for_ai()
	if not active_events.is_empty():
		context["chain_events"] = active_events
	var pending_aev := Game.get_pending_active_events()
	if not pending_aev.is_empty():
		var aev_summary: Array = []
		for ev in pending_aev:
			aev_summary.append({"name": ev.name, "objective": ev.objective, "npc_ids": ev.npc_ids})
		context["active_events_in_progress"] = aev_summary
	if mission and not mission.mission_ended:
		context["mission"] = {
			"phase": MissionPortao.MPhase.keys()[mission.phase],
			"clues_found": mission.clues_found,
			"gate_open": mission.gate_is_open,
			"catch_count": mission.catch_count,
		}
	context["constraints"] = {
		"king_deposed_is_code_only": true,
		"instability_100_triggers_victory": true,
		"max_instability_delta": 45,
		"never_set_instability_directly": true,
		"progression_events_are_code_driven": ["gate_passage", "king_deposed"],
	}
	gemini_director.evaluate_butterfly_effect(action, narrative, states, context)


func _on_caos_gerado(data: Dictionary) -> void:
	if not ai_waiting or pending_gossip.is_empty() or not is_inside_tree():
		return
	var narrative: String = pending_gossip.text
	ai_waiting = false
	pending_gossip.clear()
	hud.set_loading(false)
	# Capturar alvo e item antes do commit (commit limpa as referências)
	var _trigger_npc_id := gossip_npc.id if gossip_npc else ""
	var _trigger_item_id := held.id if held else ""
	# Commit inventory and AP only after a valid response; errors leave them intact.
	if gossip_npc:
		_commit_gossip(narrative)
	else:
		_commit_drop(drop_pos, narrative)
	if not actions_today.is_empty():
		actions_today.back()["resolved"] = true
	if narrative != "":
		Game.rumors += 1
	phase = Phase.SIM
	_ending_day = false
	var actors := _ai_actors()
	for npc: NPC in actors.values():
		npc.ambient = false
		npc.moving = false
	for directive: Dictionary in data.npc_updates:
		var npc: NPC = actors.get(directive.npc_id)
		if npc == null:
			continue
		npc.apply_ai_directive(directive)
		var npc_name: String = str(npc.def.get("name", npc.id))
		var dialogue: String = directive.dialogue_bubble
		if dialogue != "":
			Game.add_memory(npc.id, dialogue)
			hud.subtitle(npc_name, dialogue)
			hud.add_event_log("%s: \"%s\"" % [npc_name, dialogue])
	Game.apply_npc_updates(data.npc_updates)
	for directive: Dictionary in data.npc_updates:
		if directive.has("suspicion_delta") and directive.suspicion_delta != 0:
			var npc: NPC = actors.get(directive.npc_id)
			if npc:
				npc.add_suspicion(int(directive.suspicion_delta))
				if int(directive.suspicion_delta) > 0:
					hud.add_event_log("A suspeita de %s aumentou." % str(npc.def.get("name", npc.id)))
	if data.has("evidence_created") and typeof(data.evidence_created) == TYPE_ARRAY:
		for ev: Dictionary in data.evidence_created:
			Game.create_evidence(
				str(ev.get("type", "")),
				str(ev.get("location", "")),
				str(ev.get("description", "")),
				float(ev.get("strength", 20)) * Game.get_difficulty().evidence_weight,
				"", "", "", false)
	# Multiplicador de efetividade: boato/item que bate com o gatilho do NPC = muito mais impacto
	var _raw_delta := float(data.instability_delta)
	var _trigger_mult := _calc_trigger_multiplier(_trigger_npc_id, _trigger_item_id, narrative)
	_raw_delta *= _trigger_mult
	# Softcap diário: dia 1 máx +25, dia 2 máx +40, dia 3 sem limite.
	var _daily_caps := {1: 25.0, 2: 40.0, 3: 999.0}
	var _daily_cap: float = _daily_caps.get(Game.day, 999.0)
	var _remaining_cap := maxf(_daily_cap - _instability_added_today, 0.0)
	var _delta := minf(_raw_delta, _remaining_cap)
	_instability_added_today += maxf(_delta, 0.0)
	if _delta < _raw_delta and _raw_delta > 0.0:
		hud.toast("Os moradores ainda não estão convencidos o suficiente...", 3.0)
	# This signal drives the existing HUD tween. Never add the delta again on end-day.
	Game.add_instability(_delta)
	if _trigger_mult >= 2.0:
		hud.toast("Sussurro certeiro! Instabilidade %+d%%" % int(_delta), 3.5)
	elif _trigger_mult <= 0.3:
		hud.toast("O boato não fez muito efeito... Instabilidade %+d%%" % int(_delta), 3.0)
	else:
		hud.toast("Instabilidade %+d%%" % int(_delta), 2.5)
	_parse_ai_active_events(data)
	_evaluate_chain_events()
	sim_events.clear()
	sim_idx = 0
	sim_time = 0.0
	sim_end = 4.0
	_sim_clock_from = clock
	_sim_clock_to = minf(clock + 3.0, 18.0)
	sim_running = true
	Sfx.play("tension")


func _calc_trigger_multiplier(npc_id: String, item_id: String, narrative: String) -> float:
	if npc_id == "" and item_id == "":
		return 1.0
	var txt := narrative.to_lower()
	# Sussurro para um NPC: verificar palavras-chave
	if npc_id != "":
		var triggers: Dictionary = Game.NPC_TRIGGERS.get(npc_id, {})
		var keys: Array = triggers.get("gossip_keys", [])
		if keys.is_empty():
			return 0.15
		for k: String in keys:
			if k.to_lower() in txt:
				return 2.5
		return 0.15
	# Objeto solto: verificar se o item está na lista efetiva de algum NPC próximo
	if item_id != "":
		var best := 0.3
		for tid in Game.NPC_TRIGGERS:
			var t_data: Dictionary = Game.NPC_TRIGGERS[tid]
			var eff_items: Array = t_data.get("item_keys", [])
			if item_id in eff_items:
				best = 2.0
				break
		return best
	return 1.0


func _local_ai_result() -> Dictionary:
	var action := {"narrative": str(pending_gossip.get("text", "")), "tags": [], "object_id": "", "object_name": "Sussurro"}
	if held:
		action.merge({"tags": held.def.tags, "object_id": held.id, "object_name": held.def.name,
			"location": Game.nearest_location(drop_pos)}, true)
	elif gossip_npc:
		action["location"] = Game.nearest_location(gossip_npc.position)
	var states := _live_npc_states()
	var payload := {"actions": [action], "world_state": {"npcs": states}, "day": Game.day, "rumors": Game.rumors}
	return LocalDirector.ai_result(payload, states, Game.LOCATIONS.keys())


func _on_gemini_error(message: String) -> void:
	if not ai_waiting or not is_inside_tree():
		return
	if ai_fallback_enabled and not pending_gossip.is_empty():
		push_warning("IA indisponível (%s). Usando o Diretor local." % message)
		hud.toast("IA offline: usando o modo local.", 3.0)
		_on_caos_gerado(_local_ai_result())
		return
	var text: String = pending_gossip.get("text", "")
	ai_waiting = false
	pending_gossip.clear()
	hud.set_loading(false)
	hud.set_sim(false)
	phase = Phase.TERMINAL
	if gossip_npc:
		hud.open_terminal("", "", "Sussurrando para %s. Tente novamente." % gossip_npc.def.name)
	elif held:
		hud.open_terminal(held.def.name, Game.loc_name(Game.nearest_location(drop_pos)))
	else:
		phase = Phase.ACTION
		player.input_enabled = true
	hud.term_input.text = text
	hud.term_err.text = message
	hud.term_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.toast(message, 6.0)


# ------------------------------------------------------------------ jogador
func _build_player() -> void:
	player = PlayerScene.instantiate()
	player.external_drop_control = true
	player.grab_gate = func(o: WorldObject) -> bool:
		return phase == Phase.ACTION and held == null and o.attached_to == null and _try_pick(o)
	player.drop_requested.connect(func(_o, pos: Vector2): _open_drop_terminal(pos))
	player.open_gossip_terminal.connect(_on_player_gossip)
	player.gossip_blocked.connect(func(npc): hud.toast("Fique atrás ou ao lado de %s para sussurrar." % str(npc.def.get("name", "ele"))))
	npc_root.add_child(player)
	var cam2: Camera2D = player.camera
	cam2.limit_left = 0
	cam2.limit_top = 0
	cam2.limit_right = int(Game.MAP_SIZE.x)
	cam2.limit_bottom = int(Game.MAP_SIZE.y)
	cam2.make_current()
	player.position = Vector2(640, 500)


# ------------------------------------------------------------------ abertura: visor de pulso + portal
const PORTAL_TEX := preload("res://assets/gen/fx/portal.png")
const PORTAL_SPARK_TEX := preload("res://assets/gen/fx/portal_spark.png")
## Pontas de estrada nas bordas do mapa (livres de árvores); o estagiário sai andando para dentro.
const PORTAL_SPAWNS := [
	{"pos": Vector2(40, 480), "dir": Vector2.RIGHT},
	{"pos": Vector2(1240, 480), "dir": Vector2.LEFT},
	{"pos": Vector2(176, 768), "dir": Vector2.RIGHT},
]


func _play_intro() -> void:
	intro_active = true
	var spawn: Dictionary = PORTAL_SPAWNS[randi() % PORTAL_SPAWNS.size()]
	player.position = spawn.pos + Vector2(0, -2)
	player.visible = false
	player.camera.reset_smoothing()
	hud.ui.visible = false
	var intro := WristIntro.new()
	hud.add_child(intro)
	intro.play()
	await intro.finished
	intro.reveal_world()
	await _portal_arrival(spawn)
	hud.ui.visible = true
	hud.new_day()
	hud.subtitle("Panóptico", "Primeiro passo: descubra como tirar Bram do portão.")
	intro_active = false
	hud.show_tutorial()


func _portal_arrival(spawn: Dictionary) -> void:
	var portal := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var add_anim := func(anim: String, idx: Array, fps: float, loop: bool) -> void:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, loop)
		for i: int in idx:
			var a := AtlasTexture.new()
			a.atlas = PORTAL_TEX
			a.region = Rect2(i * 32, 0, 32, 44)
			frames.add_frame(anim, a)
	add_anim.call("open", [0, 1, 2, 3, 4], 14.0, false)
	add_anim.call("loop", [5, 6, 7, 8, 9, 10], 12.0, true)
	add_anim.call("close", [4, 3, 2, 1, 0], 16.0, false)
	portal.sprite_frames = frames
	portal.centered = false
	portal.offset = Vector2(-16, -42)
	portal.scale = Vector2(2, 2)
	portal.position = spawn.pos
	npc_root.add_child(portal)
	var sparks := CPUParticles2D.new()
	sparks.texture = PORTAL_SPARK_TEX
	sparks.amount = 18
	sparks.lifetime = 0.8
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(10, 18)
	sparks.position = Vector2(0, -22)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 30)
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 45.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	sparks.emitting = false
	portal.add_child(sparks)
	await get_tree().create_timer(0.35).timeout
	Sfx.play("portal_open")
	portal.play("open")
	await portal.animation_finished
	portal.play("loop")
	sparks.emitting = true
	shake = 4.0
	await get_tree().create_timer(0.45).timeout
	# o estagiário atravessa: surge em branco e sai andando
	Sfx.play("whoosh")
	player.visible = true
	player.modulate = Color(3.0, 3.0, 3.0, 1.0)
	create_tween().tween_property(player, "modulate", Color.WHITE, 0.5)
	player.scripted_dir = spawn.dir
	await get_tree().create_timer(0.5).timeout
	player.scripted_dir = Vector2.ZERO
	player.set_emotion("NERVOUS")
	await get_tree().create_timer(0.5).timeout
	sparks.emitting = false
	portal.play("close")
	Sfx.play("plop")
	await portal.animation_finished
	portal.queue_free()
	await get_tree().create_timer(0.6).timeout
	player.set_emotion("NEUTRAL")


func _build_mission() -> void:
	mission = MissionPortao.new()
	mission.name = "MissionPortao"
	add_child(mission)
	mission.setup(self, hud)
	mission.mission_success.connect(_on_mission_success)
	mission.mission_fail.connect(_on_mission_fail)


func _on_mission_success() -> void:
	Game.event_flags["player_crossed_gate"] = true
	if not _active_event_current.is_empty() and _active_event_current.get("location", "") == "castle_gate":
		resolve_current_event(true)
	_evaluate_chain_events()
	# Dar um impulso final de instabilidade para garantir que chega a 100
	Game.instability = maxf(Game.instability + 35.0, 100.0)
	Game.instability_changed.emit(Game.instability)
	phase = Phase.ENDED
	if is_instance_valid(player):
		player.input_enabled = false
	hud.set_pursuit_mode(false)
	# Tocar a sequência de revolta completa antes de emitir vitória
	await _victory_sequence()
	victory.emit()


func _on_mission_fail(reason: String) -> void:
	phase = Phase.ENDED
	if is_instance_valid(player):
		player.input_enabled = false
	hud.toast(reason, 5.5)
	await get_tree().create_timer(2.5).timeout
	defeat.emit()


func _on_player_gossip(npc: Node2D) -> void:
	if phase != Phase.ACTION or held != null or Game.ap < 1:
		hud.toast("Sem PA." if Game.ap < 1 else "Solte o objeto antes de sussurrar.")
		Sfx.play("error")
		player.end_interaction()
		return
	gossip_npc = npc as NPC
	phase = Phase.TERMINAL
	hud.open_terminal("", "", "Sussurrando para %s.  O que essa pessoa saberá?" % str(npc.def.get("name", "?")))


func _commit_gossip(narrative: String) -> void:
	var n := gossip_npc
	gossip_npc = null
	if n == null:
		return
	Game.spend_ap(1)
	var loc := Game.nearest_location(n.position)
	actions_today.append({
		"obj": null, "from": Vector2.ZERO, "cost": 1,
		"payload": {"object_id": "", "object_name": "Sussurro para %s" % n.def.name, "tags": [], "location": loc,
			"narrative": narrative, "target_npc": n.id},
	})
	if narrative.strip_edges() != "":
		Game.create_evidence("testimony", loc,
			"%s ouviu um boato: \"%s\"" % [str(n.def.get("name", n.id)), narrative.left(60)],
			15.0, "", "", n.id)
	Sfx.play("confirm")
	rings.append({"p": n.position, "age": 0.0})
	n.show_emote("?", 2.5)
	if mission:
		mission.notify_npc_whispered(n.id)
	phase = Phase.ACTION
	player.end_interaction()
	player.set_emotion("SMUG")


# ------------------------------------------------------------------ dia
func _start_day() -> void:
	day_revision += 1
	phase = Phase.ACTION
	ai_waiting = false
	_ending_day = false
	pending_gossip.clear()
	clock = 8.0
	sim_running = false
	follow = null
	_shadowing_npc = null
	actions_today.clear()
	exposure_count = 0
	_osric_alerted = false
	_alert_mode = false
	_alert_mode_t = 0.0
	Game.reset_ap()
	for id in npcs:
		var n: NPC = npcs[id]
		n.get_up()
		n.current_state = "IDLE"
		n.fear = int(Game.npc_state[id].fear)
		n.anger = int(Game.npc_state[id].anger)
		n.loyalty = int(Game.npc_state[id].loyalty)
		n.moving = false
		n.ambient = true
		n.position = n.home
		n.target = n.home
		n.bubble_t = 0.0
		n.visible = true
	var m: NPC = npcs["npc_merchant"]
	if Game.day >= 3:
		m.visible = false
		m.ambient = false
		m.moving = false
		m.position = Vector2(-500, -500)
	else:
		m.position = Vector2(640, 960)
		m.walk_to(Game.loc_pos("stall") + Vector2(0, 20))
		m.home = Game.loc_pos("stall") + Vector2(0, 20)
	var diff: Dictionary = Game.get_difficulty()
	var guard: NPC = npcs["npc_guard"]
	guard.position = Game.loc_pos("castle_gate") + Vector2(0, 14)
	# Bram fica sempre fixo no portão; só sai por comando direto da missão ou da revolta.
	guard.ambient = false
	guard.moving = false
	var guard2: NPC = npcs.get("npc_guard2")
	if guard2:
		guard2.position = Game.loc_pos("plaza") + Vector2(randf_range(-20, 20), randf_range(-10, 10))
		guard2.ambient = true
	for npc: NPC in villagers:
		npc.fear = int(Game.npc_state[npc.id].fear)
		npc.anger = int(Game.npc_state[npc.id].anger)
		npc.loyalty = int(Game.npc_state[npc.id].loyalty)
		npc.ambient = true
	var base_susp := 0.0
	if diff.recognition_enabled and Game.event_flags.get("player_caught", false):
		base_susp = 15.0
	for npc: NPC in npcs.values() + villagers:
		npc.suspicion = base_susp
		npc.suspicion_state = NPC.SuspicionState.CALM
		npc._suspicion_decay_paused = false
		npc._update_suspicion_state()
	_instability_added_today = 0.0
	_panic_tick = randf_range(2.5, 5.0)
	_snapshot()
	Music.set_day(Game.day)
	hud.new_day()
	Game.world_checkpoint = _checkpoint()
	Game.save_game()


func _exit_tree() -> void:
	ai_waiting = false
	if is_instance_valid(gemini_director):
		gemini_director.cancel_pending()


func _checkpoint() -> Dictionary:
	var saved_objects := {}
	for id in objects:
		var object: WorldObject = objects[id]
		var pos := object.position.clamp(Vector2.ZERO, Game.MAP_SIZE)
		saved_objects[id] = {"x": pos.x, "y": pos.y, "carrier": object.attached_to.id if is_instance_valid(object.attached_to) else ""}
	return {"objects": saved_objects, "poisoned": poisoned, "fish_dead": fish_dead,
		"water": water_color.to_html(), "castle_damage": castle_damage,
		"gate_open": gate_open, "flag_drop": flag_drop, "torch_on": torch_on}


func _restore_checkpoint(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	poisoned = saved.poisoned
	fish_dead = saved.fish_dead
	water_color = Color.html(saved.water)
	castle_damage = int(saved.castle_damage)
	gate_open = float(saved.gate_open)
	flag_drop = float(saved.flag_drop)
	torch_on = saved.torch_on
	for id in saved.objects:
		var state: Dictionary = saved.objects[id]
		objects[id].position = Vector2(float(state.x), float(state.y))
		objects[id].attached_to = npcs.get(state.carrier)


func _snapshot() -> void:
	snapshot = {"instab": Game.instability, "npc": Game.npc_state.duplicate(true), "poisoned": poisoned, "fish_dead": fish_dead, "water": water_color, "rumors": Game.rumors, "obj": {}, "evidence": Game.evidence_log.duplicate(true), "events": Game.event_states.duplicate(true), "event_flags": Game.event_flags.duplicate(true), "active_events": Game.active_events.duplicate(true)}
	snapshot["world"] = _checkpoint()
	for id in objects:
		snapshot.obj[id] = objects[id].position


func restart_day() -> void:
	if phase == Phase.SIM or phase == Phase.ENDED:
		return
	if held:
		held.held = false
		held = null
	player.forget_held()
	player.end_interaction()
	gossip_npc = null
	for id in objects:
		if objects[id].drop_tween:
			objects[id].drop_tween.kill()
		objects[id].position = snapshot.obj[id]
		objects[id].attached_to = null
	Game.set_instability(snapshot.instab)
	Game.npc_state = snapshot.npc.duplicate(true)
	Game.evidence_log = snapshot.evidence.duplicate(true)
	Game.event_states = snapshot.events.duplicate(true)
	Game.event_flags = snapshot.event_flags.duplicate(true)
	Game.active_events = snapshot.get("active_events", []).duplicate(true)
	poisoned = snapshot.poisoned
	fish_dead = snapshot.fish_dead
	water_color = snapshot.water
	Game.rumors = snapshot.rumors
	_restore_checkpoint(snapshot.world)
	hud.close_terminal()
	_start_day()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if intro_active or phase == Phase.TERMINAL or phase == Phase.CONFRONTATION or phase == Phase.ENDED:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_right_click()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom + 0.07, 0.8, 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom - 0.07, 0.8, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			undo()
		elif event.keycode == KEY_E:
			if mission and mission.gate_is_open and not mission.player_crossed:
				mission.try_open_gate()
		elif event.keycode == KEY_END and OS.is_debug_build():
			_debug_autoplay()
		elif event.keycode == KEY_INSERT and OS.is_debug_build() and not held:
			_try_pick(objects["apple"])
			_open_drop_terminal(Game.loc_pos("plaza"))


func _debug_autoplay() -> void:
	## Auto-play a full turn for debugging purposes
	if phase != Phase.ACTION or held:
		return
	_try_pick(objects["poison_vial"])
	held_from = held.position
	_open_drop_terminal(Game.loc_pos("lake") + Vector2(0, -60))
	terminal_submit("O Rei mandou envenenar a agua do lago")


func _debug_skip_to_conclusion() -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	player.input_enabled = false
	hud.set_ui_visible(false)
	var all_npcs: Array = []
	for id in npcs:
		if id != "npc_king" and id != "npc_guard" and id != "npc_guard2":
			all_npcs.append(npcs[id])
	for v: NPC in villagers:
		all_npcs.append(v)
	await _conclusion_sequence(all_npcs)
	victory.emit()


func _obj_at(p: Vector2) -> WorldObject:
	var best: WorldObject = null
	var bd := 16.0
	for id in objects:
		var o: WorldObject = objects[id]
		if o == held or o.attached_to:
			continue
		var d := o.position.distance_to(p)
		if d < bd:
			bd = d
			best = o
	return best


func _npc_at(p: Vector2) -> NPC:
	var best: NPC = null
	var bd := 34.0
	var all: Array = npcs.values() + villagers
	for n in all:
		if not n.visible:
			continue
		var d: float = (n.position + Vector2(0, -20)).distance_to(p)
		if d < bd:
			bd = d
			best = n
	return best


func _left_click() -> void:
	var mp := get_global_mouse_position()
	if phase == Phase.SIM:
		follow = null
		_shadowing_npc = null
		cam_target = mp
		return
	# Pegar/soltar agora é do PlayerIntern; aqui só resta fixar o card do NPC clicado.
	var n := _npc_at(mp)
	if n and _obj_at(mp) == null:
		hud.show_npc(n, true)


func _right_click() -> void:
	if phase != Phase.ACTION and phase != Phase.ACTIVE_EVENT and phase != Phase.PURSUIT:
		return
	if held:
		if phase == Phase.PURSUIT:
			drop_pos = player.drop_position().clamp(Vector2.ZERO, Game.MAP_SIZE)
			var o := held
			held = null
			player.forget_held()
			o.drop_to(drop_pos)
			distract_pursuers(drop_pos, 100.0)
			hud.toast("Objeto largado como distração!", 2.0)
			return
		if phase != Phase.ACTION:
			return
		drop_pos = player.drop_position().clamp(Vector2.ZERO, Game.MAP_SIZE)
		_request_caos("")
		return
	if phase == Phase.PURSUIT:
		return
	var mp := get_global_mouse_position()
	var npc_target := _npc_at(mp)
	# Interação com NPC exige que o jogador esteja a menos de 200 px
	if npc_target and player.global_position.distance_to(npc_target.global_position) > 200.0:
		hud.toast("Muito longe de %s." % str(npc_target.def.get("name", "NPC")), 2.0)
		return
	_open_action_menu(npc_target, _obj_at(mp))


func _open_action_menu(target_npc: NPC = null, target_obj: WorldObject = null) -> void:
	var actions: Array = []
	var free_ap := phase == Phase.ACTIVE_EVENT
	if target_npc:
		var has_evidence := not Game.get_evidence_about(target_npc.id).is_empty()
		var npc_actions := ["observe", "listen", "gossip", "ask_help"]
		if has_evidence:
			npc_actions.append("confront")
			npc_actions.append("protect")
		for action in Game.get_available_actions(false, true, free_ap):
			if npc_actions.has(action.id) and (phase == Phase.ACTION or action.id != "gossip"):
				actions.append(action)
	elif target_obj:
		var object_actions: Array[String] = []
		if target_obj.get("attached_to") and is_instance_valid(target_obj.attached_to):
			object_actions.append("steal")
		if target_obj.id == "sealed_letter":
			object_actions.append("forge_letter")
		for action in Game.get_available_actions(true, false, free_ap):
			if object_actions.has(action.id):
				actions.append(action)
	elif phase == Phase.ACTIVE_EVENT:
		for action in Game.get_available_actions(false, false, true):
			if action.id in ["hide", "flee"] or (action.id == "destroy_evidence" and not Game.get_evidence_at(Game.nearest_location(player.global_position)).is_empty()):
				actions.append(action)
	if actions.is_empty():
		return
	var label: String = str(target_npc.def.get("name", "NPC")) if target_npc else (str(target_obj.def.get("name", "Local")) if target_obj else "Evento")
	hud.show_action_menu(str(label), actions,
		func(action_id: String): _execute_context_action(action_id, target_npc, target_obj))


func _execute_context_action(action_id: String, target_npc: NPC, target_obj: WorldObject) -> void:
	if action_id == "gossip" and target_npc:
		_on_player_gossip(target_npc)
		return
	if action_id == "confront" and target_npc:
		_open_voluntary_confrontation(target_npc)
		return
	execute_action(action_id, target_npc, target_obj)


func _open_voluntary_confrontation(npc: NPC) -> void:
	_phase_before_confrontation = phase
	phase = Phase.CONFRONTATION
	player.input_enabled = false
	var has_valuable: bool = held != null and held.def.tags.has("real")
	var npc_id: String = npc.id
	hud.show_confrontation(str(npc.def.get("name", "NPC")), npc_id,
		Game.get_available_confrontation_choices(npc_id, has_valuable),
		func(choice_id: String, result: Dictionary): _apply_confrontation(npc_id, choice_id, result))


func _try_pick(o: WorldObject) -> bool:
	if phase != Phase.ACTION or held != null:
		return false
	if Game.ap < 2:
		hud.toast("PA insuficiente — pegar + soltar custam 2 PA.")
		Sfx.play("error")
		return false
	Game.spend_ap(1)
	held = o
	held_from = o.position
	o.held = true
	if mission:
		mission.notify_object_picked(o.id)
	Sfx.play("whoosh")
	return true


func _open_drop_terminal(mp: Vector2) -> void:
	if held:
		held.request_drop(mp.clamp(Vector2.ZERO, Game.MAP_SIZE))


func _on_item_dropped(context: Dictionary) -> void:
	if not held or phase != Phase.ACTION:
		return
	phase = Phase.TERMINAL
	drop_pos = context.position
	held.position = drop_pos
	var loc := Game.nearest_location(drop_pos)
	hud.open_terminal(held.def.name, Game.loc_name(loc))


func terminal_cancel() -> void:
	if phase == Phase.TERMINAL:
		phase = Phase.ACTION
		if gossip_npc:
			gossip_npc = null
			player.end_interaction()


func terminal_submit(text: String) -> void:
	if phase != Phase.TERMINAL:
		return
	_request_caos(text.strip_edges())


func _commit_drop(p: Vector2, narrative: String) -> void:
	if not held:
		return
	p = p.clamp(Vector2.ZERO, Game.MAP_SIZE)
	Game.spend_ap(1)
	var o := held
	held = null
	player.forget_held()
	var loc := Game.nearest_location(p)
	o.drop_to(p)
	actions_today.append({
		"obj": o, "from": held_from, "cost": 2,
		"payload": {"object_id": o.id, "object_name": o.def.name, "tags": o.def.tags, "location": loc, "narrative": narrative},
	})
	var strength := 20.0
	for tag in o.def.tags:
		if tag == "veneno": strength += 25.0
		elif tag == "arma": strength += 15.0
		elif tag == "real": strength += 20.0
	var origin_loc: String = Game.OBJECTS.get(o.id, {}).get("loc", "")
	if origin_loc != "" and origin_loc != loc:
		strength += 10.0
	Game.create_evidence("object_placed", loc,
		"%s encontrado(a) em %s." % [o.def.name, Game.loc_name(loc)],
		strength, o.id)
	Sfx.play("plop")
	var distracted := distract_pursuers(p, 72.0)
	if distracted > 0:
		hud.toast("O objeto distraiu %d perseguidor(es)!" % distracted, 3.0)
	if narrative != "":
		rings.append({"p": p, "age": 0.0})
		Sfx.play("confirm")
	phase = Phase.ACTION
	get_tree().create_timer(0.4).timeout.connect(func(): emit_particle("dust_small", p))


func undo() -> void:
	if phase != Phase.ACTION:
		return
	if held:
		held.held = false
		held.position = held_from
		held = null
		player.forget_held()
		Game.refund_ap(1)
		return
	if actions_today.is_empty():
		return
	if actions_today.back().get("resolved", false):
		hud.toast("Essa ação já gerou consequências. Use Reiniciar Dia para voltar.")
		return
	var a: Dictionary = actions_today.pop_back()
	if a.obj:
		if a.obj.drop_tween:
			a.obj.drop_tween.kill()
		a.obj.position = a.from
	Game.refund_ap(a.cost)
	hud.toast("Ação desfeita.")


func end_day_requested() -> void:
	if phase != Phase.ACTION:
		return
	if held:
		held.held = false
		held.position = held_from
		held = null
		player.forget_held()
		Game.refund_ap(1)
	_start_simulation()


# ------------------------------------------------------------------ simulação
func _start_simulation() -> void:
	# End-day is now only a time transition; each action was already sent to Gemini.
	phase = Phase.SIM
	_ending_day = true
	for npc: NPC in _ai_actors().values():
		npc.ambient = false
		npc.moving = false
	sim_events.clear()
	sim_idx = 0
	sim_time = 0.0
	sim_end = 2.0
	_sim_clock_from = clock
	_sim_clock_to = 22.0
	sim_running = true
	player.input_enabled = false
	hud.set_sim(true)


func _apply_world_changes(wc: Dictionary) -> void:
	if wc.get("water_poisoned", false):
		poisoned = true
	if wc.has("castle_damage"):
		castle_damage = clampi(int(wc.castle_damage), 0, 3)


func _finish_sim() -> void:
	if not sim_running or phase != Phase.SIM:
		return
	sim_running = false
	_evaluate_chain_events()
	# A instabilidade chegar a 100% JÁ é a vitória (GDD): dispara a revolta imediatamente,
	# sem depender da cadeia de eventos "king_deposed" ter sido resolvida por evidências.
	if Game.instability >= 100.0 and not _revolt_active:
		_start_revolt()
	if _revolt_active:
		# O dia normal acaba: não há mais avanço de dia nem derrota por tempo — o jogo
		# agora é sobre chegar ao portão e abri-lo.
		_resume_action_phase()
	elif _ending_day:
		phase = Phase.ENDED
		if Game.day >= Game.MAX_DAYS:
			_set_defeat_reason()
			await _defeat_sequence()
			defeat.emit()
		else:
			Game.day += 1
			_start_day()
	else:
		var pending := Game.get_pending_active_events()
		if not pending.is_empty():
			_start_active_events(pending)
		else:
			_resume_action_phase()
	hud.set_sim(false)


func _resume_action_phase() -> void:
	phase = Phase.ACTION
	hud.set_active_event_mode(false)
	hud.hide_active_event()
	for npc: NPC in _ai_actors().values():
		if npc.id == "npc_guard":
			continue  # Bram fica fixo no portão; nunca volta a vagar sozinho
		npc.ambient = true
	player.input_enabled = true
	if Game.ap == 0:
		hud.toast("Sem PA — encerre o dia para continuar.")


func _start_active_events(pending: Array) -> void:
	_active_event_queue = pending.duplicate()
	_begin_next_active_event()


func _begin_next_active_event() -> void:
	if _active_event_queue.is_empty():
		hud.hide_active_event()
		_resume_action_phase()
		return
	_active_event_current = _active_event_queue.pop_front()
	phase = Phase.ACTIVE_EVENT
	player.input_enabled = true
	for npc: NPC in _ai_actors().values():
		if npc.id == "npc_guard":
			continue  # Bram fica fixo no portão; nunca volta a vagar sozinho
		npc.ambient = true
	hud.set_active_event_mode(true)
	hud.show_active_event(_active_event_current)
	hud.toast("EVENTO: %s" % _active_event_current.name, 3.0)
	Sfx.play("confirm")
	_spawn_event_npcs(_active_event_current)


func _spawn_event_npcs(ev: Dictionary) -> void:
	# skip_spawn: true quando o handler do evento já posicionou os NPCs manualmente,
	# ou quando mover para ev.location quebraria a lógica da oportunidade criada.
	if ev.get("skip_spawn", false):
		return
	for nid in ev.npc_ids:
		var npc: NPC = npcs.get(nid)
		if not npc:
			for v in villagers:
				if v.id == nid:
					npc = v
					break
		if npc and ev.location != "":
			npc.walk_to(_resolve(ev.location))


func _update_active_event(delta: float) -> void:
	if _active_event_current.is_empty():
		return
	_active_event_current.elapsed += delta
	var remaining: float = _active_event_current.duration - _active_event_current.elapsed
	var risk: float = _active_event_current.risk
	risk += delta * 2.0
	_active_event_current.risk = clampf(risk, 0.0, 100.0)
	hud.update_active_event_time(remaining, _active_event_current.risk)
	if remaining <= 0.0:
		_fail_active_event()


func resolve_current_event(success: bool) -> void:
	if _active_event_current.is_empty():
		return
	var ev_id: String = _active_event_current.id
	Game.resolve_active_event(ev_id, success)
	if success:
		hud.toast("EVENTO CONCLUÍDO: %s" % _active_event_current.name, 3.0)
		Sfx.play("confirm")
		_exec_event_result(_active_event_current.success_action)
	else:
		hud.toast("EVENTO FALHOU: %s" % _active_event_current.name, 3.0)
		Sfx.play("error")
		_exec_event_result(_active_event_current.fail_action)
	_active_event_current = {}
	_begin_next_active_event()


func _fail_active_event() -> void:
	resolve_current_event(false)


func _exec_event_result(action_str: String) -> void:
	if action_str == "":
		return
	var parts := action_str.split(":")
	match parts[0]:
		"instability":
			Game.add_instability(float(parts[1]) if parts.size() > 1 else 5.0)
		"bump":
			if parts.size() >= 4:
				Game.bump(parts[1], parts[2], float(parts[3]))
		"unlock_event":
			if parts.size() > 1:
				Game.set_event_state(parts[1], Game.EventState.ACTIVE)
		"flag":
			if parts.size() > 1:
				Game.event_flags[parts[1]] = true
		"evidence":
			if parts.size() >= 3:
				Game.create_evidence(parts[1], _active_event_current.get("location", "plaza"),
					parts[2], 25.0)


func _parse_ai_active_events(data: Dictionary) -> void:
	var events: Array = data.get("active_events", [])
	for ev_data in events:
		if not ev_data is Dictionary:
			continue
		# O modelo descreve a pressão; o jogo escolhe as ações que podem resolvê-la.
		var safe_event: Dictionary = ev_data.duplicate()
		safe_event["success_actions"] = _safe_event_actions(ev_data)
		Game.create_active_event(safe_event)


func _safe_event_actions(ev_data: Dictionary) -> Array:
	if ev_data.get("location", "") == "castle_gate":
		return [] # só a travessia física do portão conclui este tipo de evento
	var text := (str(ev_data.get("objective", "")) + " " + str(ev_data.get("hint", ""))).to_lower()
	if text.contains("pista") or text.contains("prova"):
		return ["destroy_evidence", "incriminate", "ask_help"]
	if text.contains("persegue") or text.contains("fug") or text.contains("denunci"):
		return ["hide", "flee", "ask_help"]
	return ["listen", "confront", "ask_help"]


func trigger_active_event(params: Dictionary) -> Dictionary:
	return Game.create_active_event(params)


func _try_resolve_active_event(action_id: String, target_npc: NPC = null) -> void:
	if _active_event_current.is_empty():
		return
	var accepted: Array = _active_event_current.get("success_actions", [])
	if not accepted.has(action_id):
		return
	if not _did_action_succeed(action_id, target_npc):
		return
	resolve_current_event(true)


func _did_action_succeed(action_id: String, _target_npc: NPC) -> bool:
	match action_id:
		"destroy_evidence", "ask_help", "incriminate":
			# _apply_action_specific seta _last_action_effect antes de _try_resolve rodar
			return _last_action_effect
		_:
			return true


func _dispatch(e: Dictionary) -> void:
	var act: String = e.action
	var npc: NPC = npcs.get(e.npc_id)
	var tgt: String = e.target
	var parts := tgt.split(" ")
	if npc and not npc.visible:
		return
	if e.dialogue != "" and npc and act != "shout":
		npc.say(e.dialogue)
		hud.subtitle(npc.def.name, e.dialogue)
		Game.add_memory(e.npc_id, e.dialogue)
	var where := npc.position if npc else _resolve(parts[0])
	for p in e.particles:
		emit_particle(str(p), where)
	if e.sound != "":
		Sfx.play(e.sound)
	match act:
		"directive":
			if npc:
				npc.apply_ai_directive(e.directive)
				if e.directive.dialogue_bubble != "":
					hud.subtitle(npc.def.name, e.directive.dialogue_bubble)
					Game.add_memory(npc.id, e.directive.dialogue_bubble)
		"walk_to":
			if npc:
				npc.walk_to(_resolve(tgt))
		"run_to":
			if npc:
				npc.walk_to(_resolve(tgt), true)
		"talk_to":
			var other: NPC = npcs.get(tgt)
			if npc and other:
				npc.walk_to(other.position + Vector2(-24 if npc.position.x < other.position.x else 24, 4))
				other.show_emote("?" if randf() < 0.5 else "!")
				Game.add_memory(tgt, e.dialogue)
				Game.bump(tgt, "cred", 0)
		"shout":
			if npc:
				var txt: String = e.dialogue if e.dialogue != "" else tgt
				npc.say(txt, 4.0)
				hud.subtitle(npc.def.name, txt)
				Game.add_memory(e.npc_id, txt)
				rings.append({"p": npc.position, "age": 0.0, "shout": true})
				for id in npcs:
					var o: NPC = npcs[id]
					if o != npc and o.visible and o.position.distance_to(npc.position) < 96.0:
						o.show_emote("!")
						o.hurt_mood(0.0, 0.3)
						Game.add_memory(id, txt)
		"pick_up":
			var obj: WorldObject = objects.get(tgt)
			if npc and obj and not obj.def.tags.has("pesado"):
				npc.walk_to(obj.position + Vector2(0, 8))
				npc.arrived.connect(func():
					if is_instance_valid(obj) and obj.attached_to == null:
						obj.attached_to = npc
						Sfx.play("whoosh"), CONNECT_ONE_SHOT)
		"drop":
			var obj2: WorldObject = objects.get(tgt)
			if obj2 and obj2.attached_to:
				obj2.position = obj2.attached_to.position + Vector2(0, 4)
				obj2.attached_to = null
		"throw":
			var obj3: WorldObject = objects.get(parts[0])
			var tn: NPC = npcs.get(parts[1]) if parts.size() > 1 else null
			if obj3 and tn:
				obj3.attached_to = null
				create_tween().tween_property(obj3, "position", tn.position, 0.5)
				tn.hurt_mood(0.4, 0.0)
		"attack":
			var victim: NPC = npcs.get(tgt)
			if npc and victim:
				npc.hurt_mood(0.8, 0.0)
				npc.walk_to(victim.position + Vector2(-20, 0), true)
				npc.arrived.connect(func():
					emit_particle("sparkle_red", victim.position)
					Sfx.play("thud")
					shake = 6.0
					if randf() < 0.75 or victim.def.loyalty > 90:
						victim.fall()
						emit_particle("stars_dizzy", victim.position)
					else:
						victim.walk_to(victim.position + Vector2(40, 10), true), CONNECT_ONE_SHOT)
		"flee":
			if npc:
				npc.hurt_mood(0.0, 0.8)
				npc.show_emote("!", 2.0)
				var dir := Vector2.DOWN
				match tgt:
					"north": dir = Vector2.UP
					"east": dir = Vector2.RIGHT
					"west": dir = Vector2.LEFT
				npc.walk_to((npc.position + dir * 180.0).clamp(Vector2(20, 20), Game.MAP_SIZE - Vector2(20, 20)), true)
		"fall_down":
			if npc:
				npc.fall()
				emit_particle("stars_dizzy", npc.position)
		"change_state":
			if parts[0] == "castle" and parts.size() > 1:
				castle_damage = clampi(int(parts[1]), 0, 3)
		"emit_particles":
			for p in e.particles:
				emit_particle(str(p), _resolve(parts[0]))
		"play_sound":
			Sfx.play(e.sound if e.sound != "" else tgt)
		"screen_shake":
			shake = 4.0 + float(int(tgt)) * 3.0
			Sfx.play("thud")
		"change_water_color":
			var c := Color.from_string(tgt, Color(0.4, 0.6, 0.3))
			create_tween().tween_property(self, "water_color", c, 6.0)
			if c.g > c.b:
				poisoned = true
				get_tree().create_timer(5.0).timeout.connect(func(): fish_dead = true)
		"change_time":
			pass
		"spawn_crowd_reaction":
			var c2 := _resolve(parts[0])
			var rad := float(parts[1]) * 16.0 if parts.size() > 1 else 96.0
			emit_particle("crowd_murmur", c2)
			for id in npcs:
				var o2: NPC = npcs[id]
				if o2.visible and o2.position.distance_to(c2) < rad:
					o2.show_emote("...", 2.5)
					Game.bump(id, "fear", 4)
					Game.bump(id, "anger", 4)
	if npc:
		npc.last_active = time


func _resolve(loc_name: String) -> Vector2:
	if Game.LOCATIONS.has(loc_name):
		return Game.loc_pos(loc_name) + Vector2(randf_range(-14, 14), randf_range(-8, 8))
	if npcs.has(loc_name):
		return npcs[loc_name].position
	if objects.has(loc_name):
		return objects[loc_name].position
	if loc_name.contains(","):
		var xy := loc_name.split(",")
		return Vector2(float(xy[0]), float(xy[1]))
	return Game.loc_pos("plaza")


# ------------------------------------------------------------------ cutscenes
const FIRE_TEX := preload("res://assets/gen/fx/building_fire.png")
const CASTLE_FIRE_TEX := preload("res://assets/gen/fx/castle_fire.png")
const WEAPONS_TEX := preload("res://assets/gen/props/revolt_weapons.png")
const _REVOLT_SHOUTS := [
	"Abaixo o Rei!", "Justiça!", "Chega de tirania!", "O povo não aguenta mais!",
	"Peguem ele!", "Fogo no castelo!", "Libertem a vila!", "Morte ao tirano!",
]
const _FIRE_POSITIONS := [
	Vector2(304, 420), Vector2(320, 430),   # padaria
	Vector2(968, 420), Vector2(984, 430),   # ferraria
	Vector2(112, 420),                       # residências
]
const _CASTLE_FIRE_POS := [
	Vector2(600, 100), Vector2(660, 90), Vector2(640, 130),
]


func _spawn_fire(pos: Vector2, tex: Texture2D, fw: int, fh: int) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("burn")
	frames.set_animation_speed("burn", 6.0)
	frames.set_animation_loop("burn", true)
	var count := tex.get_width() / fw
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame("burn", a)
	spr.sprite_frames = frames
	spr.position = pos
	spr.scale = Vector2(2, 2)
	spr.z_index = 8
	fx_root.add_child(spr)
	spr.play("burn")
	return spr


func _give_weapon(npc: NPC) -> void:
	var weapon_idx := randi() % 4
	var a := AtlasTexture.new()
	a.atlas = WEAPONS_TEX
	a.region = Rect2(weapon_idx * 8, 0, 8, 16)
	var spr := Sprite2D.new()
	spr.texture = a
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	spr.position = Vector2(12 * npc.facing, -20)
	spr.z_index = 1
	npc.add_child(spr)


func _has_weapon(npc: NPC) -> bool:
	for child in npc.get_children():
		if child is Sprite2D and child.texture is AtlasTexture and child.texture.atlas == WEAPONS_TEX:
			return true
	return false


## Disparado assim que a instabilidade chega a 100%: sequência cinematográfica completa.
## 1) Transição suave de dia para noite
## 2) NPCs vão à ferraria pegar armas
## 3) Saem tacando fogo pela vila
## 4) Guardas vão à praça proteger o Rei; população avança e mata os guardas
## 5) Jogador abre o portão → NPCs invadem e matam o Rei
func _start_revolt() -> void:
	if _revolt_active:
		return
	_revolt_active = true
	player.input_enabled = false
	hud.toast("A INSTABILIDADE CHEGOU AO LIMITE!", 4.0)
	hud.set_revolt_mode()
	Music.trigger_revolt()

	# --- Desabilita cones de visão dos guardas e do ancião ---
	for cone_id in ["npc_guard", "npc_guard2", "npc_king"]:
		var cn: NPC = npcs.get(cone_id)
		if cn and is_instance_valid(cn):
			cn.disable_vision_cone()
	for cv: NPC in villagers:
		if cv.id == "villager_elder":
			cv.disable_vision_cone()

	# === FASE 1: Transição suave de dia → noite (8 segundos) ===
	# Animamos o clock — _ambient() em _process calcula a cor certa automaticamente.
	# crisis fica false durante a transição para _ambient() funcionar.
	var transition_tw := create_tween()
	transition_tw.tween_property(self, "clock", 21.0, 8.0).from(clock)
	for light in village.lights:
		if light is PointLight2D:
			create_tween().tween_property(light, "energy", 1.5, 6.0)

	# === FASE 2: Enquanto escurece, NPCs (não-guardas) vão à ferraria pegar armas ===
	var revolt_civilians: Array[NPC] = []
	var forge_pos := Game.loc_pos("forge")
	for npc_id in npcs:
		if npc_id == "npc_king" or npc_id == "npc_guard" or npc_id == "npc_guard2":
			continue
		var n: NPC = npcs[npc_id]
		n.ambient = false
		n.show_emote("!", 2.5)
		revolt_civilians.append(n)
	for v: NPC in villagers:
		v.ambient = false
		v.show_emote("!", 2.5)
		revolt_civilians.append(v)

	# Todos caminham em direção à ferraria em formação
	for i in revolt_civilians.size():
		var n: NPC = revolt_civilians[i]
		var offset := Vector2(randf_range(-50, 50), randf_range(-30, 40))
		n.walk_to(forge_pos + offset)
	Sfx.play("murmur")
	hud.toast("O povo marcha até a ferraria...", 3.5)

	# Espera chegarem (ou timeout de 5s)
	await get_tree().create_timer(5.0).timeout

	# === FASE 3: Pegam armas na ferraria ===
	Sfx.play("tension")
	shake = 3.0
	for n: NPC in revolt_civilians:
		_give_weapon(n)
		n.say(_REVOLT_SHOUTS[randi() % _REVOLT_SHOUTS.size()], 3.0)
	hud.toast("O povo pega em armas!", 3.0)
	await get_tree().create_timer(2.5).timeout

	# === FASE 4: Saem tacando fogo pela vila ===
	# Primeiro espalham-se pela vila
	var fire_targets := [
		Game.loc_pos("bakery"),
		Game.loc_pos("residence"),
		Game.loc_pos("plaza"),
	]
	for i in revolt_civilians.size():
		var target_pos: Vector2 = fire_targets[i % fire_targets.size()]
		var n: NPC = revolt_civilians[i]
		n.walk_to(target_pos + Vector2(randf_range(-40, 40), randf_range(-20, 20)), true)

	await get_tree().create_timer(2.0).timeout

	# Fogos aparecem progressivamente enquanto eles passam
	for i_fire in _FIRE_POSITIONS.size():
		_revolt_fires.append(_spawn_fire(_FIRE_POSITIONS[i_fire], FIRE_TEX, 16, 24))
		emit_particle("fire_sparks", _FIRE_POSITIONS[i_fire])
		await get_tree().create_timer(0.8).timeout
	shake = 5.0
	Sfx.play("alarm")

	# Luzes ficam vermelhas com o fogo
	for light in village.lights:
		if light is PointLight2D:
			create_tween().tween_property(light, "color", Color(1.0, 0.25, 0.08), 2.0)
	await get_tree().create_timer(1.5).timeout

	# === FASE 5: Guardas vão à praça proteger o Rei ===
	crisis = true
	var plaza := Game.loc_pos("plaza")

	var guard: NPC = npcs.get("npc_guard")
	if guard and is_instance_valid(guard):
		guard.ambient = false
		guard.say("Protejam o Rei! Todos ao centro!", 4.0)
		guard.show_emote("!", 3.0)
		guard.walk_to(plaza + Vector2(-25, 0), true)
	var guard2: NPC = npcs.get("npc_guard2")
	if guard2 and is_instance_valid(guard2):
		guard2.ambient = false
		guard2.say("Fiquem para trás! Em nome do Rei!", 3.5)
		guard2.show_emote("!", 2.5)
		guard2.walk_to(plaza + Vector2(25, 0), true)

	await get_tree().create_timer(2.0).timeout

	# === FASE 6: População avança e cerca os guardas na praça ===
	Sfx.play("murmur")
	for i in revolt_civilians.size():
		var n: NPC = revolt_civilians[i]
		var angle := float(i) / float(revolt_civilians.size()) * TAU
		var circle_pos := plaza + Vector2(cos(angle), sin(angle)) * 55.0
		n.walk_to(circle_pos, true)
		n.say(_REVOLT_SHOUTS[randi() % _REVOLT_SHOUTS.size()], 3.0)

	await get_tree().create_timer(3.0).timeout

	# Guardas são mortos pela multidão
	shake = 8.0
	Sfx.play("thud")
	emit_particle("sparkle_red", plaza + Vector2(-25, 0))
	emit_particle("sparkle_red", plaza + Vector2(25, 0))
	await get_tree().create_timer(0.5).timeout

	if guard and is_instance_valid(guard):
		guard.say("Não... o Rei...", 2.0)
		guard.fall()
		guard.moving = false
		guard.set_physics_process(false)
	if guard2 and is_instance_valid(guard2):
		guard2.fall()
		guard2.moving = false
		guard2.set_physics_process(false)

	Sfx.play("thud")
	await get_tree().create_timer(1.5).timeout

	# === FASE 7: Portão fica aberto, jogador deve ir lá ===
	if mission:
		mission.force_gate_open_from_revolt()
	player.input_enabled = true
	hud.toast("Os guardas caíram! Corra até o portão e pressione E!", 6.0)


func _victory_sequence() -> void:
	crisis = true
	hud.set_ui_visible(false)
	hud.alarm()
	follow = null
	cam_zoom = 1.0
	player.input_enabled = false

	if not _revolt_active:
		_revolt_active = true
		hud.set_revolt_mode()
		Music.trigger_revolt()
		Sfx.play("alarm")
		# Transição suave de dia → noite via clock (o _ambient() calcula a cor)
		var tw0 := create_tween()
		tw0.tween_property(self, "clock", 21.0, 6.0).from(clock)
		for light in village.lights:
			if light is PointLight2D:
				create_tween().tween_property(light, "color", Color(1.0, 0.25, 0.08), 4.0)
		# Desabilita cones de visão
		for cone_id2 in ["npc_guard", "npc_guard2", "npc_king"]:
			var dn: NPC = npcs.get(cone_id2)
			if dn and is_instance_valid(dn):
				dn.disable_vision_cone()
		for dv: NPC in villagers:
			if dv.id == "villager_elder":
				dv.disable_vision_cone()
		await get_tree().create_timer(3.0).timeout
		for pos in _FIRE_POSITIONS:
			_revolt_fires.append(_spawn_fire(pos, FIRE_TEX, 16, 24))
			emit_particle("fire_sparks", pos)
			await get_tree().create_timer(0.3).timeout
		Sfx.play("tension")
		shake = 4.0
		cam_target = Vector2(640, 450)
		await get_tree().create_timer(1.0).timeout

	# === Reúne a multidão armada (já armada se a revolta já aconteceu) ===
	var revolt_npcs: Array = []
	for id in npcs:
		if id == "npc_king" or id == "npc_guard" or id == "npc_guard2":
			continue
		var n: NPC = npcs[id]
		n.ambient = false
		n.get_up()
		n.visible = true
		n.position = n.position if n.position.x > 0 else Vector2(640, 940)
		if not _has_weapon(n):
			_give_weapon(n)
		revolt_npcs.append(n)
		n.show_emote("!", 3.0)
	for v: NPC in villagers:
		v.ambient = false
		v.get_up()
		v.visible = true
		if not _has_weapon(v):
			_give_weapon(v)
		revolt_npcs.append(v)
	Sfx.play("murmur")

	# === NPCs vivos marcham para o portão (guardas já morreram na praça) ===
	cam_target = Vector2(640, 300)
	for i2 in revolt_npcs.size():
		var n: NPC = revolt_npcs[i2]
		var offset := Vector2(-100 + (i2 % 6) * 36, 60 + (i2 / 6) * 28)
		n.walk_to(Game.loc_pos("castle_gate") + offset, true)
	await get_tree().create_timer(2.5).timeout

	# === Portão abre + NPCs invadem o palácio ===
	gate_open = 1.0
	shake = 6.0
	Sfx.play("horn")
	await get_tree().create_timer(0.8).timeout
	for pos in _CASTLE_FIRE_POS:
		_revolt_fires.append(_spawn_fire(pos, CASTLE_FIRE_TEX, 24, 32))
		emit_particle("fire_sparks", pos)
	cam_target = Vector2(640, 150)
	for n: NPC in revolt_npcs:
		n.walk_to(Vector2(640 + randf_range(-60, 60), 160 + randf_range(-20, 20)), true)
	Sfx.play("tension")
	await get_tree().create_timer(3.5).timeout

	# === Rei aparece, chama os guardas (que já estão mortos) ===
	var king: NPC = npcs["npc_king"]
	king.position = Vector2(640, 168)
	king.visible = true
	king.get_up()
	king.disable_vision_cone()
	king.show_emote("!", 4.0)
	king.say("Isso é um absurdo! Guardas!!", 4.0)
	shake = 5.0
	Sfx.play("thud")
	await get_tree().create_timer(2.0).timeout

	# === NPCs arrastam o rei até a praça (onde os guardas já jazem mortos) ===
	var plaza := Game.loc_pos("plaza")
	cam_target = Vector2(640, 400)
	king.walk_to(plaza, true)
	if revolt_npcs.size() >= 2:
		revolt_npcs[0].walk_to(plaza + Vector2(-20, 0), true)
		revolt_npcs[1].walk_to(plaza + Vector2(20, 0), true)
	king.say("Soltem-me! Eu sou o Rei!", 4.0)
	await get_tree().create_timer(4.0).timeout

	# === Multidão cerca o rei na praça (junto aos corpos dos guardas) ===
	for i3 in revolt_npcs.size():
		var n: NPC = revolt_npcs[i3]
		var angle := float(i3) / float(revolt_npcs.size()) * TAU
		var circle_pos := plaza + Vector2(cos(angle), sin(angle)) * 50.0
		n.walk_to(circle_pos)
	emit_particle("crowd_murmur", plaza)
	emit_particle("anger_symbol", plaza + Vector2(0, -30))
	Sfx.play("murmur")
	king.position = plaza
	king.show_emote("* *", 5.0)
	king.say("Não... piedade...", 4.0)
	await get_tree().create_timer(3.0).timeout

	# === "Execução" — escurecimento + sons ===
	shake = 10.0
	Sfx.play("thud")
	emit_particle("sparkle_red", plaza)
	emit_particle("sparkle_red", plaza + Vector2(-20, 10))
	emit_particle("sparkle_red", plaza + Vector2(20, -10))
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(self, "flag_drop", 1.0, 1.5)

	Sfx.play("thud")
	await get_tree().create_timer(1.0).timeout
	king.fall()
	for n: NPC in revolt_npcs:
		n.say("" , 0.1)
	await get_tree().create_timer(2.5).timeout

	# Alguns NPCs caem mortos (colateral da revolta)
	var dead_count := 0
	for n: NPC in revolt_npcs:
		if dead_count >= 3:
			break
		if randf() < 0.35:
			n.fall()
			dead_count += 1

	# Limpa armas — fogos permanecem
	for n: NPC in revolt_npcs:
		for child in n.get_children():
			if child is Sprite2D and child.texture is AtlasTexture and child.texture.atlas == WEAPONS_TEX:
				child.queue_free()
		if not n.fallen:
			n.moving = false
			n.set_physics_process(false)
	king.moving = false
	king.set_physics_process(false)

	# ======================== CONCLUSÃO CINEMATOGRÁFICA ========================
	Music.play("victory", 2.0)
	await _conclusion_sequence(revolt_npcs)


## Conclusão cinematográfica em 3 partes (a 4ª parte acontece em main.gd/show_victory).
func _conclusion_sequence(revolt_npcs: Array) -> void:
	var nm := str(Game.player_name)
	var _concl_nodes: Array[Node] = []
	var _hidden_trees: Array[Node] = []

	# ---- PARTE 1: Visor de pulso (relatório da Agência) ----
	cam_target = player.global_position
	cam_zoom = 1.0
	var wrist := WristIntro.new()
	hud.add_child(wrist)
	wrist._pages = _conclusion_wrist_pages(nm)
	wrist.play()
	await wrist.finished
	wrist.reveal_world()

	# ---- Transição DIRETA: noite + chuva + fogo já aplicados ----
	# Escurecer IMEDIATAMENTE (phase=ENDED impede _process de resetar)
	mod.color = Color(0.12, 0.08, 0.16, 1.0)
	# Luzes avermelhadas
	for light in village.lights:
		if light is PointLight2D:
			create_tween().tween_property(light, "color", Color(1.0, 0.2, 0.05), 0.5)

	# === CHUVA (CanvasLayer para ficar na tela independente da câmera) ===
	var rain_layer := CanvasLayer.new()
	rain_layer.layer = 5
	add_child(rain_layer)
	_concl_nodes.append(rain_layer)
	var rain := CPUParticles2D.new()
	rain.emitting = true
	rain.amount = 400
	rain.lifetime = 0.8
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(700, 5)
	rain.direction = Vector2(0.15, 1)
	rain.spread = 4.0
	rain.gravity = Vector2(20, 1000)
	rain.initial_velocity_min = 500.0
	rain.initial_velocity_max = 700.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 2.0
	rain.color = Color(0.6, 0.7, 0.9, 0.35)
	rain.position = Vector2(640, -30)
	rain_layer.add_child(rain)

	# === FOGO EM TUDO — casas, florestas, castelo ===
	var massive_fire_positions := [
		Vector2(280, 410), Vector2(320, 400), Vector2(340, 430),
		Vector2(940, 410), Vector2(980, 420), Vector2(1000, 400),
		Vector2(100, 410), Vector2(130, 430), Vector2(160, 410),
		Vector2(580, 460), Vector2(660, 450), Vector2(620, 480),
		Vector2(580, 100), Vector2(640, 80), Vector2(700, 100), Vector2(640, 140),
		Vector2(200, 700), Vector2(240, 710),
		Vector2(200, 200), Vector2(400, 180), Vector2(900, 200), Vector2(1100, 180),
		Vector2(900, 600), Vector2(1050, 550), Vector2(100, 600),
		Vector2(640, 550), Vector2(640, 650),
		Vector2(400, 540), Vector2(550, 540), Vector2(700, 540),
	]
	for fp in massive_fire_positions:
		if not _has_fire_near(fp):
			var fire := _spawn_fire(fp, FIRE_TEX, 16, 24)
			_revolt_fires.append(fire)
			_concl_nodes.append(fire)
	for fp in massive_fire_positions:
		if randf() < 0.5:
			emit_particle("fire_sparks", fp)
			emit_particle("smoke_thick", fp + Vector2(0, -20))

	# === TODOS os NPCs na praça comemorando (incluindo rei/guardas mortos no chão) ===
	var plaza := Game.loc_pos("plaza")
	# Rei e guardas caídos na praça
	var king: NPC = npcs.get("npc_king")
	if king and is_instance_valid(king):
		king.position = plaza + Vector2(0, 10)
		king.visible = true
		king.fall()
	var guard: NPC = npcs.get("npc_guard")
	if guard and is_instance_valid(guard):
		guard.position = plaza + Vector2(-35, 20)
		guard.visible = true
		guard.fall()
	var guard2: NPC = npcs.get("npc_guard2")
	if guard2 and is_instance_valid(guard2):
		guard2.position = plaza + Vector2(40, 25)
		guard2.visible = true
		guard2.fall()
	# NPCs vivos na praça gritando e vibrando
	var shouts := ["LIBERDADE!", "O tirano caiu!", "Vitória!", "Abaixo o Rei!", "Somos livres!", "Justiça!", "Fogo neles!", "O povo venceu!"]
	for n: NPC in revolt_npcs:
		if n.fallen:
			continue
		n.ambient = false
		n.moving = false
		n.set_physics_process(true)
		n.visible = true
		n.get_up()
		var celebration_pos := plaza + Vector2(randf_range(-90, 90), randf_range(-60, 60))
		n.position = celebration_pos
		n.say(shouts[randi() % shouts.size()], 30.0)
		n.show_emote("!", 30.0)
		if not _has_weapon(n):
			_give_weapon(n)

	# === Limpar área inferior esquerda (esconder árvores/props perto do templo) ===
	for child in village.ysort.get_children():
		if child is NPC or child == player or not (child is Node2D):
			continue
		var cpos: Vector2 = (child as Node2D).position
		if cpos.x < 380 and cpos.y > 740:
			child.visible = false
			_hidden_trees.append(child)
	# === Expandir chão verde para cobrir bordas do mapa (replicar gramado) ===
	# Fazenda + toda a área abaixo/ao redor do mapa visível
	var grass_col := Color("84c669")
	var grass_dark := Color("65a556")
	# Chão inferior (cobre de y=780 até y=1200, toda a largura + extra)
	var ground_ext := ColorRect.new()
	ground_ext.color = grass_col
	ground_ext.position = Vector2(-160, 680)
	ground_ext.size = Vector2(1600, 560)
	ground_ext.z_index = -19
	village.add_child(ground_ext)
	_concl_nodes.append(ground_ext)
	# Faixas laterais (esquerda e direita)
	for side_data in [Vector2(-160, -160), Vector2(1080, -160)]:
		var side_ground := ColorRect.new()
		side_ground.color = grass_col
		side_ground.position = side_data
		side_ground.size = Vector2(360, 1400)
		side_ground.z_index = -19
		village.add_child(side_ground)
		_concl_nodes.append(side_ground)
	# Zona livre da cinemática (nada deve cair aqui — figura misteriosa)
	var _in_scene_zone := func(pos: Vector2) -> bool:
		return pos.x < 420 and pos.y > 700 and pos.y < 960
	# Só decora a moldura estendida (fora do 0..1280 × 0..960 principal)
	var _in_extension := func(pos: Vector2) -> bool:
		return pos.y >= 680 or pos.x <= 200 or pos.x >= 1080 or pos.y <= 100

	# Manchas de grama (escuras e claras) para quebrar o verde chapado
	var grass_light := Color("8bd87d")
	for _i in range(520):
		var p_patch := Vector2(randf_range(-140, 1420), randf_range(-140, 1220))
		if not _in_extension.call(p_patch) or _in_scene_zone.call(p_patch):
			continue
		var patch := ColorRect.new()
		patch.color = grass_dark if randf() < 0.65 else grass_light
		patch.position = p_patch
		patch.size = Vector2(randf_range(14, 62), randf_range(10, 36))
		patch.z_index = -18
		village.add_child(patch)
		_concl_nodes.append(patch)
	# Pedrinhas (2×2 px) espalhadas — mesma textura das bordas do mapa
	var stone_col := Color("8b9bb4")
	var stone_light := Color("c0cbdc")
	for _i in range(1400):
		var p_stone := Vector2(randf_range(-140, 1420), randf_range(-140, 1220))
		if not _in_extension.call(p_stone) or _in_scene_zone.call(p_stone):
			continue
		var pebble := ColorRect.new()
		pebble.color = stone_light if randf() < 0.5 else stone_col
		pebble.position = p_stone
		pebble.size = Vector2(2, 2)
		pebble.z_index = -17
		village.add_child(pebble)
		_concl_nodes.append(pebble)

	# Ruído de grama: milhares de pontinhos 1×1/2×2 em três tons — quebra o verde chapado
	var _grass_shades := [Color("84c669"), Color("8bd87d"), Color("65a556"), Color("479f4a"), Color("2f7a45")]
	for _i in range(6500):
		var p_dot := Vector2(randf_range(-140, 1420), randf_range(-140, 1220))
		if not _in_extension.call(p_dot) or _in_scene_zone.call(p_dot):
			continue
		var dot := ColorRect.new()
		dot.color = _grass_shades[randi() % _grass_shades.size()]
		dot.position = p_dot
		dot.size = Vector2(2, 2) if randf() < 0.55 else Vector2(1, 1)
		dot.z_index = -18
		village.add_child(dot)
		_concl_nodes.append(dot)

	# === Árvores, arbustos, tufos e flores nas bordas ===
	var _tree_tex: Array[Texture2D] = [
		load("res://assets/gen/env/tree_oak.png"),
		load("res://assets/gen/env/tree_oak_dark.png"),
		load("res://assets/gen/env/tree_pine.png"),
		load("res://assets/gen/env/tree_pine_dark.png"),
		load("res://assets/gen/env/tree_huge.png"),
		load("res://assets/gen/env/tree_huge_dark.png"),
		load("res://assets/gen/env/tree_oak_autumn.png"),
	]
	var _bush_tex: Array[Texture2D] = [
		load("res://assets/gen/env/bush.png"),
		load("res://assets/gen/env/bush_berry.png"),
		load("res://assets/gen/env/bush_flower.png"),
	]
	var _tuft_tex: Texture2D = load("res://assets/gen/env/tuft.png")
	var _flowers_tex: Texture2D = load("res://assets/gen/env/flowers.png")
	var _rock_tex: Texture2D = load("res://assets/gen/env/rock_small.png")
	var _mush_tex: Texture2D = load("res://assets/gen/env/mushroom.png")

	var _placed_trees: Array[Vector2] = []
	# Espaçamento irregular quebra o padrão robótico do grid antigo
	var _can_place := func(pos: Vector2, min_d: float) -> bool:
		for p in _placed_trees:
			if pos.distance_to(p) < min_d:
				return false
		return true

	# Scatter denso — muitas tentativas com jitter total, filtros descartam o que não cabe
	for _i in range(3200):
		var pos := Vector2(randf_range(-140, 1420), randf_range(-140, 1220))
		if _in_scene_zone.call(pos):
			continue
		if not _in_extension.call(pos):
			continue
		# min_dist irregular (34–72) — clusters e clareiras naturais
		var min_d := randf_range(26.0, 78.0)
		if not _can_place.call(pos, min_d):
			continue
		var tex: Texture2D = _tree_tex[randi() % _tree_tex.size()]
		var t_spr := Sprite2D.new()
		t_spr.texture = tex
		t_spr.hframes = 4
		t_spr.frame = randi() % 4
		t_spr.position = pos
		t_spr.scale = Vector2(2, 2)
		t_spr.flip_h = randf() < 0.5
		t_spr.centered = true
		village.add_child(t_spr)
		_concl_nodes.append(t_spr)
		_placed_trees.append(pos)

	# Arbustos preenchendo lacunas
	for _i in range(460):
		var pos := Vector2(randf_range(-140, 1420), randf_range(-40, 1120))
		if _in_scene_zone.call(pos) or not _in_extension.call(pos):
			continue
		if not _can_place.call(pos, 28.0):
			continue
		var b_spr := Sprite2D.new()
		b_spr.texture = _bush_tex[randi() % _bush_tex.size()]
		b_spr.position = pos
		b_spr.scale = Vector2(2, 2)
		b_spr.flip_h = randf() < 0.5
		b_spr.centered = true
		village.add_child(b_spr)
		_concl_nodes.append(b_spr)
		_placed_trees.append(pos)

	# Tufos de grama, flores, pedrinhas e cogumelos (rente ao chão)
	for _i in range(2600):
		var pos := Vector2(randf_range(-140, 1420), randf_range(-70, 1150))
		if _in_scene_zone.call(pos) or not _in_extension.call(pos):
			continue
		var roll := randf()
		var d_spr := Sprite2D.new()
		if roll < 0.45:
			d_spr.texture = _tuft_tex
			d_spr.hframes = 4
			d_spr.frame = randi() % 4
		elif roll < 0.78:
			d_spr.texture = _flowers_tex
			d_spr.hframes = 4
			d_spr.vframes = 5
			d_spr.frame = randi() % 20
		elif roll < 0.93:
			d_spr.texture = _rock_tex
		else:
			d_spr.texture = _mush_tex
		d_spr.position = pos
		d_spr.scale = Vector2(2, 2)
		d_spr.flip_h = randf() < 0.5
		d_spr.centered = true
		d_spr.z_index = -5
		village.add_child(d_spr)
		_concl_nodes.append(d_spr)

	# ---- PARTE 2: A Figura Misteriosa (inferior esquerda, abaixo do templo) ----
	Music.play("cinematic", 2.5)
	cam_limit_bottom = 1100.0
	# Área limpa abaixo do templo: centro em (200, 830)
	var scene_center := Vector2(200, 830)

	# Mover jogador para a área da cena
	player.global_position = scene_center + Vector2(0, 50)
	player.visible = true

	# Câmera enquadra parte inferior (praça em cima, cena secreta embaixo)
	cam_target = Vector2(400, 680)
	cam_zoom = 0.82
	await get_tree().create_timer(1.5).timeout

	Sfx.play("portal_open")
	shake = 3.0
	var portal_pos := scene_center + Vector2(0, -30)

	var portal_spr := _create_animated_portal(portal_pos, "cyan")
	_concl_nodes.append(portal_spr)
	emit_particle("sparkle_gold", portal_pos)
	emit_particle("smoke_thin", portal_pos)
	await get_tree().create_timer(0.8).timeout

	var figure := _create_conclusion_figure("figure_mystery", portal_pos + Vector2(0, 10), true)
	_concl_nodes.append(figure)
	figure.visible = false
	await get_tree().create_timer(0.3).timeout
	figure.visible = true
	figure.modulate = Color(2.5, 2.5, 2.5, 1)
	create_tween().tween_property(figure, "modulate", Color.WHITE, 0.6)
	create_tween().tween_property(portal_spr, "scale", Vector2.ZERO, 0.5).set_delay(0.5)

	await get_tree().create_timer(1.5).timeout
	_conclusion_say(figure, "Droga... Cheguei tarde demais.", 3.5, "Figura Misteriosa")
	await get_tree().create_timer(4.0).timeout

	_conclusion_face_player(figure)
	await get_tree().create_timer(0.6).timeout
	Sfx.play("shout")
	shake = 4.0
	_conclusion_say(figure, "VOCÊ AÍ!", 2.0, "Figura Misteriosa")
	await get_tree().create_timer(2.5).timeout

	_conclusion_say(figure, "Foi você que fez isso, né...", 3.0, "Figura Misteriosa")
	await get_tree().create_timer(3.5).timeout

	_conclusion_say(figure, "Esse Rei ia trazer Paz! A Agência mentiu para você!", 5.0, "Figura Misteriosa")
	await get_tree().create_timer(5.5).timeout

	_conclusion_say(figure, "Eles tiram o livre-arbítrio das pessoas... sussurram boatos... mudam a história.", 6.0, "Figura Misteriosa")
	await get_tree().create_timer(6.5).timeout

	_conclusion_say(figure, "O Diretor não é quem você pensa qu----", 2.5, "Figura Misteriosa")
	await get_tree().create_timer(1.2).timeout

	# ---- PARTE 3: Agentes silenciam a Figura ----
	Sfx.play("portal_open")
	shake = 6.0

	var agent_positions := [
		scene_center + Vector2(-70, 10),
		scene_center + Vector2(70, 10),
		scene_center + Vector2(0, -60),
	]
	var agents: Array[Sprite2D] = []
	for i in agent_positions.size():
		var ap := _create_animated_portal(agent_positions[i], "red")
		_concl_nodes.append(ap)
		emit_particle("smoke_thin", agent_positions[i])
		await get_tree().create_timer(0.2).timeout
		var agent := _create_conclusion_figure("agent_%d" % i, agent_positions[i], false)
		agents.append(agent)
		_concl_nodes.append(agent)
		_conclusion_face_figure(agent, figure)
		create_tween().tween_property(ap, "scale", Vector2.ZERO, 0.4).set_delay(0.3)

	await get_tree().create_timer(0.6).timeout

	for agent in agents:
		var dir_to_fig := agent.position.direction_to(figure.position)
		create_tween().tween_property(agent, "position",
			agent.position + dir_to_fig * 25.0, 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.6).timeout

	# Disparos de energia
	for i2 in agents.size():
		var bolt := Sprite2D.new()
		bolt.texture = load("res://assets/gen/conclusion/energy_bolt.png")
		bolt.hframes = 4
		bolt.frame = i2 % 4
		bolt.scale = Vector2(3, 3)
		bolt.z_index = 35
		bolt.position = agents[i2].position
		add_child(bolt)
		_concl_nodes.append(bolt)
		Sfx.play("thud")
		shake = 4.0
		var tw_bolt := create_tween()
		tw_bolt.tween_property(bolt, "position", figure.position, 0.15)
		tw_bolt.tween_callback(func():
			emit_particle("sparkle_red", figure.position)
			bolt.visible = false
		)
		await get_tree().create_timer(0.3).timeout

	hud.flash_danger()
	shake = 10.0
	emit_particle("sparkle_red", figure.position + Vector2(-8, 4))
	emit_particle("sparkle_red", figure.position + Vector2(8, -4))

	# Figura cai
	var tw_fall := create_tween()
	tw_fall.tween_property(figure, "rotation", PI / 2.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw_fall.parallel().tween_property(figure, "modulate:a", 0.4, 0.4)
	await get_tree().create_timer(1.5).timeout

	# Portal de saída — agentes arrastam o corpo, um de cada lado
	var exit_pos := scene_center + Vector2(-80, -60)
	var exit_portal := _create_animated_portal(exit_pos, "red")
	_concl_nodes.append(exit_portal)
	emit_particle("smoke_thin", exit_pos)
	Sfx.play("whoosh")
	await get_tree().create_timer(0.5).timeout

	# Dois agentes se posicionam um de cada lado do corpo
	if agents.size() >= 2:
		create_tween().tween_property(agents[0], "position", figure.position + Vector2(-22, 0), 0.4).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(agents[1], "position", figure.position + Vector2(22, 0), 0.4).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.5).timeout

	# Arrastam juntos até o portal
	create_tween().tween_property(figure, "position", exit_pos, 1.5).set_trans(Tween.TRANS_SINE)
	if agents.size() >= 2:
		create_tween().tween_property(agents[0], "position", exit_pos + Vector2(-22, 0), 1.5).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(agents[1], "position", exit_pos + Vector2(22, 0), 1.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.2).timeout

	# Último agente fala com o jogador
	var last_agent: Sprite2D = agents.back()
	_conclusion_face_player(last_agent)
	create_tween().tween_property(last_agent, "position",
		player.global_position + Vector2(0, -50), 0.8).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.5).timeout

	_conclusion_say(last_agent, "Desculpa por isso... Você não deveria saber.", 4.0, "Agente Panóptico")
	await get_tree().create_timer(4.5).timeout

	_conclusion_say(last_agent, "Óbvio... você é só um estagiário.", 3.0, "Agente Panóptico")
	await get_tree().create_timer(2.5).timeout

	# Flash de memória
	Sfx.play("whoosh")
	shake = 3.0
	await get_tree().create_timer(0.3).timeout

	for cn in _concl_nodes:
		if is_instance_valid(cn):
			cn.queue_free()
	_concl_nodes.clear()
	# Restaurar árvores escondidas
	for t in _hidden_trees:
		if is_instance_valid(t):
			t.visible = true
	_hidden_trees.clear()

	Sfx.play("confirm")
	var mem_flash := ColorRect.new()
	mem_flash.color = Color(1, 1, 1, 0)
	mem_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	mem_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mem_flash)
	var tw_mem := create_tween()
	tw_mem.tween_property(mem_flash, "color:a", 1.0, 0.3)
	await tw_mem.finished
	await get_tree().create_timer(2.0).timeout

	for f in _revolt_fires:
		if is_instance_valid(f):
			f.queue_free()
	_revolt_fires.clear()
	mem_flash.queue_free()


func _has_fire_near(pos: Vector2) -> bool:
	for f in _revolt_fires:
		if is_instance_valid(f) and f.position.distance_to(pos) < 30.0:
			return true
	return false


func _conclusion_wrist_pages(nm: String) -> Array[Dictionary]:
	var y := "[color=#ffd76a]"
	var r := "[color=#ff7a7a]"
	var c := "[color=#7ff6ff]"
	var e := "[/color]"
	var pages: Array[Dictionary] = [
		{"title": "RELATÓRIO", "text":
			"%s> CANAL SEGURO ABERTO.%s\n\n%sMissão concluída, Operador %s.%s\n\nAnomalia temporal neutralizada.\nO Rei Aldemar I foi deposto pelo povo.\nA linha do tempo foi... %sprotegida%s." % [c, e, y, nm, e, c, e]},
		{"title": "AVALIAÇÃO", "text":
			"Parabéns. Você completou sua %sprimeira missão%s pela Agência Panóptico.\n\nDe muitas missões que virão... em breve você receberá novas ordens.\n\n%sPreparando extração dimensional...%s\n\n%s> AGUARDE INSTRUÇÕES----%s" % [y, e, c, e, r, e]},
	]
	return pages


func _create_animated_portal(pos: Vector2, color: String) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8)
	frames.set_animation_loop("default", true)
	var tex_path := "res://assets/gen/conclusion/portal_%s.png" % color
	var tex: Texture2D = load(tex_path)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("default", atlas)
	spr.sprite_frames = frames
	spr.position = pos
	spr.scale = Vector2.ZERO
	spr.z_index = 30
	add_child(spr)
	spr.play("default")
	create_tween().tween_property(spr, "scale", Vector2(3, 3), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return spr


func _create_conclusion_figure(fig_id: String, pos: Vector2, is_mystery: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	if is_mystery:
		spr.texture = load("res://assets/gen/conclusion/figure_mystery.png")
	else:
		spr.texture = load("res://assets/gen/conclusion/agent.png")
	spr.hframes = 4
	spr.vframes = 3
	spr.centered = false
	spr.offset = Vector2(-8, -23)
	spr.scale = Vector2(2, 2)
	spr.frame = 0
	spr.position = pos
	spr.z_index = 20
	spr.name = fig_id
	add_child(spr)
	return spr


func _conclusion_say(_spr: Sprite2D, text: String, dur: float, speaker := "") -> void:
	# Caixa de diálogo fixa na parte inferior da tela (via HUD = CanvasLayer)
	var panel := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.02, 0.08, 0.95)
	bg_style.set_corner_radius_all(8)
	bg_style.set_content_margin_all(16)
	bg_style.border_color = Color(0.3, 0.8, 1.0, 0.6)
	bg_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", bg_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Nome do personagem que fala
	if speaker != "":
		var name_lbl := Label.new()
		name_lbl.text = speaker
		name_lbl.custom_minimum_size = Vector2(500, 0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

	var lbl := Label.new()
	lbl.text = "\"" + text + "\""
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(500, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	hud.add_child(panel)
	await get_tree().process_frame

	# Centralizar horizontalmente, fixo na parte inferior
	var sz := panel.size
	panel.position = Vector2((1280 - sz.x) * 0.5, 640 - sz.y)

	panel.scale = Vector2.ZERO
	panel.pivot_offset = sz * 0.5
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(dur)
	tw.tween_property(panel, "scale", Vector2.ZERO, 0.12)
	tw.tween_callback(panel.queue_free)


func _conclusion_face_player(spr: Sprite2D) -> void:
	var dir_to_player := spr.position.direction_to(player.global_position)
	if absf(dir_to_player.x) > absf(dir_to_player.y) * 0.9:
		spr.frame = 2 * 4
		spr.flip_h = dir_to_player.x > 0
	elif dir_to_player.y > 0:
		spr.frame = 0
	else:
		spr.frame = 1 * 4


func _conclusion_face_figure(spr: Sprite2D, target: Sprite2D) -> void:
	var dir_to := spr.position.direction_to(target.position)
	if absf(dir_to.x) > absf(dir_to.y) * 0.9:
		spr.frame = 2 * 4
		spr.flip_h = dir_to.x > 0
	elif dir_to.y > 0:
		spr.frame = 0
	else:
		spr.frame = 1 * 4


var _defeat_reason := ""

func _set_defeat_reason() -> void:
	var gate_done := Game.get_event_state("gate_passage") == Game.EventState.RESOLVED
	var king_done := Game.get_event_state("king_deposed") == Game.EventState.RESOLVED
	var guard_left := bool(Game.event_flags.get("gate_unguarded", false))
	var guard_dist := bool(Game.event_flags.get("guard_distracted", false))
	if gate_done or king_done:
		_defeat_reason = ""  # não deve chegar aqui, mas por segurança
	elif not guard_dist and not guard_left:
		_defeat_reason = "Bram não saiu do posto. O portão nunca ficou desprotegido."
	elif guard_left and not bool(Game.event_flags.get("player_crossed_gate", false)):
		_defeat_reason = "O portão abriu, mas você não cruzou a tempo."
	elif Game.get_event_state("witness_appears") == Game.EventState.FAILED:
		_defeat_reason = "Você virou o principal suspeito. A missão foi abortada."
	elif Game.get_event_state("guard_interrogates") != Game.EventState.RESOLVED:
		_defeat_reason = "Bram nunca começou a investigar. Faltou evidência contra alguém."
	else:
		_defeat_reason = "Os 3 dias passaram sem que o rei fosse deposto."


func _defeat_sequence() -> void:
	hud.set_ui_visible(false)
	cam_target = Vector2(640, 200)
	var k: NPC = npcs["npc_king"]
	k.position = Vector2(640, 168)
	var king_msg := "Nenhum boato derruba esta coroa. A ordem está restaurada."
	k.say(king_msg, 5.0)
	var reason := _defeat_reason if _defeat_reason != "" else "Anomalia não contida."
	hud.subtitle("Agência Panóptico", reason)
	for id in npcs:
		if id != "npc_king":
			npcs[id].walk_to(npcs[id].home)
	await get_tree().create_timer(5.5).timeout


# ------------------------------------------------------------------ partículas
func emit_particle(kind: String, pos: Vector2) -> void:
	var cfg := {
		"dust_small": [Color(0.75, 0.65, 0.5, 0.7), 5, 0.5, Vector2(0, -10), 20, 2.0, false],
		"dust_large": [Color(0.7, 0.62, 0.5, 0.7), 16, 1.5, Vector2(0, -8), 40, 4.0, false],
		"sparkle_gold": [Color(1.0, 0.85, 0.3), 14, 1.2, Vector2(0, -30), 40, 2.0, true],
		"sparkle_red": [Color(1.0, 0.35, 0.2), 12, 1.0, Vector2(0, -20), 45, 2.0, true],
		"blood_splash": [Color(0.7, 0.05, 0.05), 6, 0.6, Vector2(0, 60), 40, 2.0, false],
		"leaf_fall": [Color(0.5, 0.75, 0.3), 4, 3.0, Vector2(10, 20), 15, 3.0, false],
		"smoke_thin": [Color(0.7, 0.7, 0.7, 0.5), 8, 2.0, Vector2(0, -25), 10, 4.0, false],
		"smoke_thick": [Color(0.2, 0.2, 0.2, 0.7), 20, 3.0, Vector2(0, -30), 20, 6.0, false],
		"fire_sparks": [Color(1.0, 0.6, 0.15), 10, 0.8, Vector2(0, -40), 30, 2.0, true],
		"water_ripple": [Color(0.8, 0.9, 1.0, 0.6), 8, 1.5, Vector2.ZERO, 30, 2.0, false],
		"water_splash": [Color(0.7, 0.85, 1.0), 14, 0.8, Vector2(0, 80), 50, 2.0, false],
		"poison_bubbles": [Color(0.4, 0.9, 0.3, 0.8), 10, 2.0, Vector2(0, -25), 15, 3.0, false],
		"coins_scatter": [Color(1.0, 0.85, 0.2), 10, 1.0, Vector2(0, 80), 60, 3.0, false],
		"tears": [Color(0.5, 0.75, 1.0), 6, 1.0, Vector2(0, 60), 12, 2.0, false],
		"stars_dizzy": [Color(1.0, 0.95, 0.4), 6, 2.0, Vector2(0, -6), 14, 2.5, true],
		"exclamation": [Color(1.0, 0.9, 0.2), 1, 0.01, Vector2.ZERO, 0, 1.0, true],
		"question": [Color(0.6, 0.85, 1.0), 1, 0.01, Vector2.ZERO, 0, 1.0, true],
		"anger_symbol": [Color(1.0, 0.25, 0.2), 4, 0.8, Vector2(0, -20), 20, 3.0, true],
		"heart_break": [Color(0.9, 0.2, 0.4), 3, 1.0, Vector2(0, -20), 15, 3.0, true],
		"crowd_murmur": [Color(0.9, 0.9, 0.85, 0.7), 8, 2.0, Vector2(0, -12), 30, 2.5, false],
		"instability_pulse": [Color(1.0, 0.2, 0.2, 0.6), 24, 1.2, Vector2.ZERO, 120, 4.0, true],
	}
	if not cfg.has(kind):
		return
	var c: Array = cfg[kind]
	if kind == "exclamation" or kind == "question":
		for id in npcs:
			if npcs[id].position.distance_to(pos) < 40.0:
				npcs[id].show_emote("!" if kind == "exclamation" else "?")
				break
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = int(c[1])
	p.lifetime = float(c[2])
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = c[3]
	p.initial_velocity_min = float(c[4]) * 0.4
	p.initial_velocity_max = float(c[4])
	p.scale_amount_min = float(c[5]) * 0.6
	p.scale_amount_max = float(c[5])
	p.color = c[0]
	fx_root.add_child(p)
	get_tree().create_timer(float(c[2]) + 0.5).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	time += delta
	if phase == Phase.PURSUIT:
		_tension_t -= delta
		if _tension_t <= 0.0:
			Sfx.play("tension")
			_tension_t = 0.85
	else:
		_tension_t = 0.0
	if _alert_mode:
		_alert_mode_t -= delta
		if _alert_mode_t <= 0.0:
			_alert_mode = false
	if mission and (phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT):
		mission.tick(delta)
	if phase == Phase.ACTIVE_EVENT:
		_update_active_event(delta)
	# hover
	var mp := get_global_mouse_position()
	if phase == Phase.ACTION or phase == Phase.SIM or phase == Phase.ACTIVE_EVENT:
		var ho := _obj_at(mp) if not held else null
		if ho != hovered_obj:
			if hovered_obj:
				hovered_obj.hovered = false
			hovered_obj = ho
			if ho:
				ho.hovered = true
		var hn := _npc_at(mp)
		if hn != hovered_npc:
			hovered_npc = hn
		hud.set_hover(hovered_obj, hovered_npc)
	if held == null and player.held_object != null:
		player.forget_held()
	player.input_enabled = not intro_active and (phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT or phase == Phase.PURSUIT)
	if held and (phase == Phase.TERMINAL or ai_waiting):
		held.position = drop_pos
	# simulação
	if sim_running:
		sim_time += delta * float(Game.settings.sim_speed)
		while sim_idx < sim_events.size() and float(sim_events[sim_idx].t) <= sim_time:
			_dispatch(sim_events[sim_idx])
			sim_idx += 1
		clock = lerpf(_sim_clock_from, _sim_clock_to, clampf(sim_time / maxf(sim_end, 1.0), 0.0, 1.0))
		if sim_idx >= sim_events.size() and sim_time >= sim_end:
			var idle := true
			for npc: NPC in _ai_actors().values():
				if npc.moving:
					idle = false
			if idle or sim_time > sim_end + 10.0:
				_finish_sim()
		# câmera segue o NPC mais ativo
		if follow == null and phase == Phase.SIM:
			var best: NPC = null
			var bt := -1000.0
			for id in npcs:
				var n: NPC = npcs[id]
				if n.visible and n.last_active > bt:
					bt = n.last_active
					best = n
			if best and time - bt < 8.0:
				cam_target = best.position
	elif phase == Phase.ACTION or phase == Phase.TERMINAL or phase == Phase.ACTIVE_EVENT:
		cam_target = player.global_position
	_update_cam(delta)
	# luz ambiente (não resetar durante cinemática de conclusão)
	if phase != Phase.ENDED:
		mod.color = Color("1a1a2e") if crisis else _ambient()
	# anéis de narrativa
	for r in rings:
		r.age += delta
	rings = rings.filter(func(r): return r.age < 1.2)
	village.water_color = water_color
	village.fish_dead = fish_dead
	village.gate_open = gate_open
	village.flag_drop = flag_drop
	village.castle_damage = castle_damage
	village.torch_on = torch_on
	village.wind = wind
	var amb := mod.color
	village.night = clampf(1.0 - (amb.r + amb.g + amb.b) / 3.0 * 1.15, 0.0, 1.0)
	shake = maxf(shake - delta * 14.0, 0.0)
	if phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT or phase == Phase.PURSUIT:
		_update_suspicion(delta)
		check_player_escaped_pursuit()
	if phase == Phase.ACTION:
		_panic_tick -= delta
		if _panic_tick <= 0.0:
			_panic_tick = randf_range(2.5, 5.5)
			_update_ambient_panic()


const _SUSPICIOUS_TAGS := ["veneno", "arma", "real"]
const _SUSPICION_SIGHT_RADIUS := 96.0
const _SUSPICION_HOT_RADIUS := 52.0

func _update_suspicion(delta: float) -> void:
	var held_tags: Array = held.def.tags if held else []
	var player_stealth: bool = is_instance_valid(player) and player.get("state") == PlayerIntern.State.STEALTH
	var exposure := 0.3 if player_stealth else 1.0
	var diff: Dictionary = Game.get_difficulty()
	var susp_rate: float = diff.suspicion_rate

	for npc: NPC in npcs.values() + villagers:
		if not npc.visible or not is_instance_valid(npc):
			continue
		var dist := npc.position.distance_to(player.global_position)
		var sight_r := _SUSPICION_SIGHT_RADIUS * (1.4 if _alert_mode and npc.id == "npc_guard" else 1.0)
		if dist > sight_r:
			npc._suspicion_decay_paused = false
			continue

		# bloqueia decay enquanto o jogador está em campo de visão
		npc._suspicion_decay_paused = true

		var base_rate := 0.0
		for tag in held_tags:
			if _SUSPICIOUS_TAGS.has(tag):
				match tag:
					"veneno": base_rate += 8.0
					"arma":   base_rate += 5.0
					"real":   base_rate += 6.0
		# evidências no local onde o NPC está aumentam alerta passivo
		var npc_loc := Game.nearest_location(npc.position)
		var ev_str := Game.evidence_strength_at(npc_loc)
		if ev_str > 0.0:
			base_rate += ev_str * 0.04
		if dist < _SUSPICION_HOT_RADIUS:
			base_rate *= 1.5

		if base_rate > 0.0:
			var rep_mod: Dictionary = Game.reputation_modifier(npc.id)
			var instab_mult := 1.0 + clampf((Game.instability - 20.0) / 80.0, 0.0, 1.0)
			var alert_mult := 1.5 if (_alert_mode and npc.id == "npc_guard") else 1.0
			npc.add_suspicion(base_rate * exposure * susp_rate * float(rep_mod.suspicion_mult) * delta * instab_mult * alert_mult)

		# confronto: NPC aborda o jogador (evita repetição no mesmo ciclo)
		if npc.suspicion_state == NPC.SuspicionState.CONFRONTING and not npc.moving and not npc.pursuing:
			_on_npc_confronts(npc)
	_sync_runtime_suspicion()


func _sync_runtime_suspicion() -> void:
	for npc: NPC in _ai_actors().values():
		if Game.npc_state.has(npc.id):
			Game.npc_state[npc.id]["suspicion"] = npc.suspicion


func _on_npc_confronts(npc: NPC) -> void:
	Game.bump(npc.id, "anger", 15.0)
	Game.bump(npc.id, "loyalty", 5.0)
	var loc := Game.nearest_location(npc.position)
	var obj_desc: String = str(held.def.name) if held else "algo suspeito"
	Game.create_evidence("witness", loc,
		"%s viu o Estagiário com %s perto de %s." % [
			str(npc.def.get("name", npc.id)), obj_desc, Game.loc_name(loc)],
		30.0, held.id if held else "", Game.player_name, npc.id)
	hud.show_spotted_flash()
	hud.toast("%s está te perseguindo!" % str(npc.def.get("name", "NPC")), 4.0)
	Sfx.play("tension")
	emit_particle("exclamation", npc.position)
	var diff: Dictionary = Game.get_difficulty()
	var dur_range: Dictionary = diff.pursuit_duration
	var dur_min: float = dur_range.keys()[0]
	var dur_max: float = dur_range.values()[0]
	npc.pursue_speed_mult = diff.pursuit_speed
	npc.start_pursuit(player, randf_range(dur_min, dur_max))
	hud.add_event_log("%s iniciou uma perseguição!" % str(npc.def.get("name", "NPC")))
	if phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT:
		phase = Phase.PURSUIT
		player.input_enabled = true
		hud.set_pursuit_mode(true)


## Módulo 2: guarda/rei viu o jogador carregando item suspeito no cone de visão.
func _on_vision_cone_caught(npc: NPC, _target: Node2D) -> void:
	if phase != Phase.ACTION and phase != Phase.ACTIVE_EVENT:
		return
	if held != null and _is_item_freely_takeable(held):
		return
	exposure_count += 1
	hud.flash_danger()
	Sfx.play("shout")
	if exposure_count >= 2:
		_trigger_caught_game_over(npc)
		return
	npc.start_pursuit(player, 15.0)
	phase = Phase.PURSUIT
	hud.set_pursuit_mode(true)
	Game.spend_ap(1)
	hud.toast("⚠ FLAGRADO! Você foi visto! (%d/2 — na próxima a linha temporal é apagada)" % exposure_count, 5.0)
	hud.add_event_log("Flagrante %d/2: %s viu o Estagiário com item suspeito." % [exposure_count, str(npc.def.get("name", ""))])
	Game.event_flags["player_caught"] = true
	Game.add_instability(-10.0)
	if held != null:
		var obj := held
		var return_pos := held_from if held_from != Vector2.ZERO else \
			player.global_position + Vector2(randf_range(-20, 20), 10)
		held = null
		obj.held = false
		obj.global_position = return_pos
		player.forget_held()


func _trigger_caught_game_over(npc: NPC) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	Game.event_flags["player_caught"] = true
	npc.say("Você de novo! A linha temporal está comprometida!", 5.0)
	npc.show_emote("!", 3.0)
	shake = 8.0
	player.input_enabled = false
	player.set_emotion("PANIC")
	Sfx.play("thud")
	hud.flash_danger()
	if held != null:
		held.held = false
		held = null
		player.forget_held()
	await get_tree().create_timer(1.8).timeout
	hud.toast("LINHA TEMPORAL APAGADA — mudanças demais na história!", 0.0)
	await get_tree().create_timer(3.0).timeout
	defeat.emit()


## NPC protegido (Bram/Ancião) retalia: o jogador perde 1 PA e recebe um aviso.
func _on_protected_npc_retaliation(npc: NPC, _action_id: String) -> void:
	Game.warnings += 1
	Game.spend_ap(1)
	shake = 5.0
	Sfx.play("shout")
	player.set_emotion("PANIC")
	npc.show_emote("!", 3.0)
	hud.flash_danger()
	if npc.id == "npc_guard" or npc.id == "npc_guard2":
		npc.say("Você está me desafiando?! Guarda!", 4.0)
	else:
		npc.say("Insolente! Não ouse tentar isso comigo!", 4.0)
	hud.add_event_log("%s retaliou! Aviso %d/%d." % [str(npc.def.get("name", "")), Game.warnings, Game.MAX_WARNINGS])
	if Game.warnings >= Game.MAX_WARNINGS:
		hud.toast("EXPULSO DA LINHA TEMPORAL — provocou demais!", 0.0)
		phase = Phase.ENDED
		player.input_enabled = false
		get_tree().create_timer(2.5).timeout.connect(func(): defeat.emit())
	else:
		hud.toast("⚠ %s não tolera isso! Aviso %d/%d — na próxima será expulso!" % [
			str(npc.def.get("name", "")), Game.warnings, Game.MAX_WARNINGS], 5.0)
		npc.add_suspicion(40.0)


## Osric avistou o jogador com item suspeito e vai alertar Bram.
func _on_osric_reports_to_guard(osric: NPC, _target: Node2D) -> void:
	if phase != Phase.ACTION and phase != Phase.ACTIVE_EVENT:
		return
	if held != null and _is_item_freely_takeable(held):
		return
	if _osric_alerted:
		return
	_osric_alerted = true
	get_tree().create_timer(30.0).timeout.connect(func(): _osric_alerted = false)
	var bram: NPC = npcs.get("npc_guard")
	if bram and not bram.pursuing:
		osric.walk_to(bram.global_position)
		bram.add_suspicion(35.0)
		_alert_mode = true
		_alert_mode_t = 30.0
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(bram):
			bram.say("O ancião está me sinalizando algo...", 3.0)
			bram.show_emote("?", 2.0)
	hud.flash_danger()
	hud.toast("Osric notou algo suspeito e foi alertar Bram! (cone de Bram ampliado por 30s)", 5.0)
	hud.add_event_log("Osric alertou Bram — o guarda está em modo de alerta.")


## Retorna true quando o item pode ser pego livremente (sem ativar detecção).
func _is_item_freely_takeable(obj: WorldObject) -> bool:
	var tags: Array = obj.def.get("tags", [])
	# Ferreiro aliado libera martelo e espada
	if "arma" in tags and obj.id in ["hammer", "rusty_sword"]:
		if Game.event_flags.get("smith_allied", false):
			return true
		if Game.instability >= 60.0:
			return true
	# Alta instabilidade ou guarda distraído libera a chave dourada
	if obj.id == "gold_key":
		if Game.instability >= 70.0 or Game.event_flags.get("guard_distracted", false):
			return true
	# Alta instabilidade libera relíquias sagradas
	if "sagrado" in tags:
		if Game.instability >= 65.0:
			return true
	return false


func _on_npc_catches_player(npc: NPC) -> void:
	_sync_runtime_suspicion()
	_phase_before_confrontation = phase
	hud.set_pursuit_mode(false)
	phase = Phase.CONFRONTATION
	Game.event_flags["player_caught"] = true
	npc.stop_pursuit("caught")
	npc.say("Te peguei!", 3.0)
	npc.show_emote("!", 2.5)
	Sfx.play("thud")
	shake = 5.0
	player.input_enabled = false
	player.set_emotion("PANIC")
	for other_npc: NPC in npcs.values() + villagers:
		if other_npc.pursuing and other_npc != npc:
			other_npc.stop_pursuit("caught")
	var has_valuable := false
	if held:
		for tag in held.def.tags:
			if tag in ["valioso", "real", "ouro"]:
				has_valuable = true
	var choices := Game.get_available_confrontation_choices(npc.id, has_valuable)
	var npc_name: String = str(npc.def.get("name", "NPC"))
	var npc_id: String = npc.id
	hud.show_confrontation(npc_name, npc_id, choices,
		func(choice_id: String, result: Dictionary): _apply_confrontation(npc_id, choice_id, result))


func _apply_confrontation(npc_id: String, choice_id: String, result: Dictionary) -> void:
	var npc: NPC = npcs.get(npc_id)
	if not npc:
		for v in villagers:
			if v.id == npc_id:
				npc = v
				break
	var effects: Dictionary = result.get("npc_effects", {})
	for stat in effects:
		Game.bump(npc_id, stat, float(effects[stat]))
	if result.suspicion_delta != 0.0 and npc:
		if result.suspicion_delta > 0:
			npc.add_suspicion(result.suspicion_delta)
		else:
			npc.reduce_suspicion(-result.suspicion_delta)
	if result.instability_delta != 0.0:
		Game.add_instability(result.instability_delta)
	if result.get("reputation_delta", 0.0) != 0.0:
		Game.change_reputation_for_npc(npc_id, float(result.reputation_delta))
	var loc := Game.nearest_location(player.global_position)
	if not result.success:
		Game.create_evidence("witness", loc,
			"%s confrontou o Estagiário." % str(Game.NPC_DEFS.get(npc_id, Game.VILLAGER_DEFS.get(npc_id, {})).get("name", npc_id)),
			30.0, "", Game.player_name, npc_id)
	if result.get("flee", false):
		player.set_emotion("PANIC")
		if npc:
			npc.start_pursuit(player, 8.0)
	else:
		if npc:
			npc.suspicion = clampf(npc.suspicion, 0.0, 60.0)
			npc._update_suspicion_state()
	if choice_id == "bribe" and result.success and held:
		held.held = false
		held.position = npc.position + Vector2(0, 4) if npc else player.global_position
		held = null
		player.forget_held()
		hud.toast("Você entregou o item como suborno.", 3.0)
	phase = _phase_before_confrontation if _phase_before_confrontation != Phase.CONFRONTATION else Phase.ACTION
	player.input_enabled = phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT or phase == Phase.PURSUIT
	hud.hide_confrontation()


func _on_npc_calls_backup(caller: NPC) -> void:
	var backup_range := 120.0
	var all_npcs: Array = npcs.values() + villagers
	for npc: NPC in all_npcs:
		if npc == caller or npc.pursuing or npc.fallen or not npc.visible:
			continue
		if npc.global_position.distance_to(caller.global_position) < backup_range:
			if npc.suspicion >= NPC.SUSPICION_ALERT or int(npc.def.get("loyalty", 100)) > 60:
				npc.start_pursuit(player, randf_range(8.0, 12.0))
				rings.append({"p": caller.position, "age": 0.0, "shout": true})
				break


func check_player_escaped_pursuit() -> void:
	var stealth: bool = is_instance_valid(player) and player.get("state") == PlayerIntern.State.STEALTH
	for npc: NPC in npcs.values() + villagers:
		if not npc.pursuing:
			continue
		var dist := npc.global_position.distance_to(player.global_position)
		if stealth and dist > 80.0:
			npc.pursue_lost_timer += 0.5
		if _is_player_hidden():
			npc.pursue_lost_timer += 1.0
	_check_pursuit_ended()


func _check_pursuit_ended() -> void:
	if phase != Phase.PURSUIT:
		return
	for npc: NPC in npcs.values() + villagers:
		if npc.pursuing:
			return
	phase = Phase.ACTION
	hud.set_pursuit_mode(false)
	hud.toast("Você escapou!", 2.0)
	Sfx.play("relief")


func _is_player_hidden() -> bool:
	if not is_instance_valid(player):
		return false
	var p := player.global_position
	if p.y < 200.0 and p.x > 560.0 and p.x < 720.0:
		return false
	for loc_id in Game.LOCATIONS:
		var loc_data: Dictionary = Game.LOCATIONS[loc_id]
		if loc_id in ["bakery", "forge", "temple", "residence"]:
			var loc_pos: Vector2 = loc_data.pos
			if p.distance_to(loc_pos) < 32.0:
				return true
	return false


func distract_pursuers(distraction_pos: Vector2, radius := 80.0) -> int:
	var count := 0
	for npc: NPC in npcs.values() + villagers:
		if not npc.pursuing:
			continue
		if npc.global_position.distance_to(distraction_pos) < radius:
			npc.stop_pursuit("distracted")
			npc.walk_to(distraction_pos, true)
			npc.show_emote("?", 2.0)
			count += 1
	_check_pursuit_ended()
	return count


func execute_action(action_id: String, target_npc: NPC = null, target_obj: WorldObject = null) -> bool:
	var has_npc := target_npc != null
	var has_item := held != null or target_obj != null
	# Durante eventos ativos o PA não é consumido: o evento é uma crise, não uma jogada.
	# A validação de PA também é pulada para não bloquear as ações de resolução.
	var in_active_event := phase == Phase.ACTIVE_EVENT
	var check := Game.can_do_action(action_id, has_item, has_npc, in_active_event)
	if not check.ok:
		hud.toast(check.reason)
		Sfx.play("error")
		return false
	var def: Dictionary = Game.ACTION_DEFS[action_id]
	# Proteção: Bram e Ancião não podem ser confrontados/subornados/incriminados
	if target_npc and action_id in ["confront", "ask_help", "incriminate"]:
		var t_triggers: Dictionary = Game.NPC_TRIGGERS.get(target_npc.id, {})
		if t_triggers.get("protected", false):
			_on_protected_npc_retaliation(target_npc, action_id)
			return false
	var cost: int = def.cost
	if cost > 0 and not in_active_event:
		Game.spend_ap(cost)
	var noise: float = def.noise
	var susp: float = def.suspicion
	var player_stealth: bool = is_instance_valid(player) and player.get("state") == PlayerIntern.State.STEALTH
	if player_stealth:
		noise *= 0.3
		susp *= 0.3
	if noise > 0.0:
		_apply_noise(player.global_position, noise)
	if susp != 0.0:
		_apply_suspicion_burst(player.global_position, susp)
	_last_action_effect = true  # reset antes de _apply_action_specific sobrescrever
	_apply_action_specific(action_id, target_npc, target_obj)
	_try_resolve_active_event(action_id, target_npc)
	_evaluate_chain_events()
	if phase == Phase.ACTION:
		var pending_events := Game.get_pending_active_events()
		if not pending_events.is_empty():
			_start_active_events(pending_events)
	actions_today.append({
		"action_id": action_id,
		"obj": target_obj, "from": target_obj.position if target_obj else Vector2.ZERO,
		"cost": cost,
		"payload": {"action": action_id, "target_npc": target_npc.id if target_npc else "",
			"object_id": target_obj.id if target_obj else (held.id if held else ""),
			"location": Game.nearest_location(player.global_position)},
	})
	hud.toast(def.name, 2.0)
	return true


func _apply_noise(origin: Vector2, noise_level: float) -> void:
	var radius := noise_level * 6.0
	for npc: NPC in npcs.values() + villagers:
		if not npc.visible or not is_instance_valid(npc):
			continue
		var dist := npc.position.distance_to(origin)
		if dist < radius:
			var intensity := (1.0 - dist / radius) * noise_level * 0.5
			npc.add_suspicion(intensity)
			if noise_level > 20.0 and dist < radius * 0.5:
				npc.show_emote("?", 1.5)
	if noise_level > 15.0:
		rings.append({"p": origin, "age": 0.0, "shout": noise_level > 25.0})


func _apply_suspicion_burst(origin: Vector2, amount: float) -> void:
	for npc: NPC in npcs.values() + villagers:
		if not npc.visible or not is_instance_valid(npc):
			continue
		var dist := npc.position.distance_to(origin)
		if dist < _SUSPICION_SIGHT_RADIUS:
			if amount > 0.0:
				npc.add_suspicion(amount * (1.0 - dist / _SUSPICION_SIGHT_RADIUS))
			elif amount < 0.0:
				npc.reduce_suspicion(-amount)


func _apply_action_specific(action_id: String, target_npc: NPC, target_obj: WorldObject) -> void:
	var loc := Game.nearest_location(player.global_position)
	match action_id:
		"observe":
			if target_npc:
				hud.show_npc(target_npc, true)
				player.set_emotion("SUSPICIOUS")
				if mission and mission.has_method("notify_npc_observed"):
					mission.notify_npc_observed(target_npc.id)
				var hint := _observe_hint(target_npc.id)
				hud.toast("👁 %s" % hint, 6.0)
				hud.add_event_log("Observou %s: %s" % [str(target_npc.def.get("name", "")), hint])
		"listen":
			if target_npc:
				player.set_emotion("SUSPICIOUS")
				if mission and mission.has_method("notify_npc_listened"):
					mission.notify_npc_listened(target_npc.id)
				if target_npc.id == "villager_elder":
					_osric_oracle(target_npc)
				var hint := _listen_hint(target_npc.id)
				hud.toast("👂 %s" % hint, 6.0)
				hud.add_event_log("Escutou %s: %s" % [str(target_npc.def.get("name", "")), hint])
				var saved: Dictionary = Game.npc_state.get(target_npc.id, {})
				var memories: Array = saved.get("memories", [])
				if not memories.is_empty():
					var last: String = memories.back()
					Game.create_evidence("overheard", loc,
						"Ouviu %s dizer: \"%s\"" % [str(target_npc.def.get("name", "")), last.left(50)],
						10.0, "", "", target_npc.id)
		"gossip":
			pass # já tratado pelo sistema existente de sussurro
		"plant_object":
			pass # já tratado pelo sistema existente de soltar objeto
		"steal":
			if target_obj and is_instance_valid(target_obj):
				if target_obj.get("attached_to") and is_instance_valid(target_obj.attached_to):
					var owner_npc: NPC = target_obj.attached_to
					target_obj.attached_to = null
					target_obj.position = player.global_position + Vector2(0, 4)
					Game.create_evidence("break_in", loc,
						"%s desapareceu de %s." % [target_obj.def.name, str(owner_npc.def.get("name", ""))],
						25.0, target_obj.id, "", owner_npc.id)
					owner_npc.show_emote("!", 2.0)
					Sfx.play("whoosh")
		"forge_letter":
			if not target_obj or target_obj.id != "sealed_letter":
				hud.toast("Você precisa selecionar uma carta selada.", 2.5)
				Game.refund_ap(1)
				return
			Game.create_evidence("forged_letter", loc,
				"Uma carta falsificada foi preparada com conteúdo incriminador.",
				30.0, "sealed_letter")
			hud.toast("Carta falsificada com sucesso.", 3.0)
			Sfx.play("confirm")
		"follow":
			if target_npc:
				_shadowing_npc = target_npc
				player.set_emotion("SUSPICIOUS")
				hud.toast("Seguindo %s... (clique direito para parar)" % str(target_npc.def.get("name", "")), 3.0)
				# Seguir revela a rotina: cria evidência de overheard depois de 4 s
				get_tree().create_timer(4.0).timeout.connect(func():
					if _shadowing_npc == target_npc and is_instance_valid(target_npc):
						var dist2 := player.global_position.distance_to(target_npc.global_position)
						if dist2 < 120.0:
							var saved: Dictionary = Game.npc_state.get(target_npc.id, {})
							var dest: String = str(saved.get("destination", ""))
							var info := "Observou %s se dirigindo a %s." % [str(target_npc.def.get("name", "")), dest if dest != "" else "lugar desconhecido"]
							Game.create_evidence("overheard", Game.nearest_location(player.global_position), info, 8.0, "", "", target_npc.id)
							hud.toast("Descobriu rotina de %s." % str(target_npc.def.get("name", "")), 3.0)
						_shadowing_npc = null
				)
		"confront":
			if target_npc:
				player.set_emotion("NERVOUS")
				var evidence_list := Game.get_evidence_about(target_npc.id)
				if evidence_list.is_empty():
					hud.toast("Você não tem provas contra %s." % str(target_npc.def.get("name", "")), 3.0)
					Game.refund_ap(1)
				else:
					target_npc.show_emote("!", 3.0)
					target_npc.say("Do que está me acusando?!", 4.0)
					Game.bump(target_npc.id, "anger", 20.0)
					Game.bump(target_npc.id, "loyalty", -10.0)
					target_npc.hurt_mood(0.5, 0.3)
		"incriminate":
			if target_npc and (held or target_obj):
				var obj := target_obj if target_obj else held
				Game.create_evidence("object_placed", loc,
					"%s encontrado(a) nas posses de %s." % [obj.def.name, str(target_npc.def.get("name", ""))],
					35.0, obj.id, target_npc.id)
				Game.bump(target_npc.id, "loyalty", -15.0)
				hud.toast("Evidência plantada contra %s." % str(target_npc.def.get("name", "")), 3.0)
				Sfx.play("confirm")
				_last_action_effect = true
			else:
				_last_action_effect = false
		"protect":
			if target_npc:
				Game.bump(target_npc.id, "loyalty", 20.0)
				var against := Game.get_evidence_about(target_npc.id)
				for ev in against:
					ev.strength = maxf(ev.strength - 10.0, 0.0)
				target_npc.say("Obrigado, amigo.", 3.0)
				target_npc.show_emote("<3", 2.0)
				hud.toast("Você protegeu %s." % str(target_npc.def.get("name", "")), 3.0)
		"hide":
			# Esconder exige estar perto de um objeto (cobertura) ou longe de todos os NPCs
			var nearest_npc_dist := 9999.0
			for n: NPC in npcs.values() + villagers:
				if n.visible and is_instance_valid(n):
					nearest_npc_dist = minf(nearest_npc_dist, n.global_position.distance_to(player.global_position))
			var has_cover := false
			for id in objects:
				var o: WorldObject = objects[id]
				if o != held and o.global_position.distance_to(player.global_position) < 48.0:
					has_cover = true
					break
			if nearest_npc_dist > 180.0 or has_cover:
				player.set_emotion("NERVOUS")
				hud.toast("Escondido... suspeita reduzida.", 2.5)
			else:
				hud.toast("Sem cobertura perto — NPCs ainda podem te ver.", 2.5)
				Game.refund_ap(0)  # custo 0, mas o efeito não se aplica; cancela a ação
				return
		"ask_help":
			if target_npc:
				var result := _evaluate_ask_help(target_npc)
				if result.accepts:
					target_npc.say(result.accept_line, 3.0)
					target_npc.show_emote("<3", 2.0)
					Game.bump(target_npc.id, "loyalty", -10.0)
					Game.bump(target_npc.id, "fear", -5.0)
					hud.toast("%s aceita ajudar!" % str(target_npc.def.get("name", "")), 3.5)
					hud.add_event_log("%s aceita ajudar o Estagiário." % str(target_npc.def.get("name", "")))
					if target_npc.id == "npc_smith":
						Game.event_flags["smith_allied"] = true
						hud.add_event_log("Ferreiro aliado — martelo e espada podem ser pegos livremente.")
					_last_action_effect = true
				else:
					target_npc.say(result.refuse_line, 3.0)
					target_npc.show_emote("!", 2.0)
					target_npc.add_suspicion(result.suspicion_penalty)
					Game.bump(target_npc.id, "anger", result.anger_penalty)
					hud.toast("%s recusou. %s" % [str(target_npc.def.get("name", "")), result.toast], 4.0)
					_last_action_effect = false
		"destroy_evidence":
			var loc_ev := Game.get_evidence_at(loc)
			if loc_ev.is_empty():
				hud.toast("Não há pistas para destruir aqui.", 2.5)
				Game.refund_ap(1)
				_last_action_effect = false
			else:
				var ev: Dictionary = loc_ev[0]
				Game.destroy_evidence(ev.id)
				hud.toast("Pista destruída: %s" % ev.description.left(40), 3.0)
				Sfx.play("confirm")
				emit_particle("smoke_thin", player.global_position)
				_last_action_effect = true
		"flee":
			player.set_emotion("PANIC")
			Sfx.play("whoosh")
			for npc: NPC in npcs.values() + villagers:
				if npc.pursuing:
					npc.pursue_lost_timer += 1.5


## Osric revela o segredo do NPC com maior lealdade ao Rei no momento.
func _osric_oracle(osric: NPC) -> void:
	var best_loyal_id := ""
	var best_loyalty := 0.0
	for nid in Game.NPC_DEFS:
		if nid in ["npc_king", "npc_guard", "npc_guard2"]:
			continue
		var st: Dictionary = Game.npc_state.get(nid, {})
		var loy := float(st.get("loyalty", 0))
		if loy > best_loyalty:
			best_loyalty = loy
			best_loyal_id = nid
	var npc_name := str(Game.NPC_DEFS.get(best_loyal_id, Game.VILLAGER_DEFS.get(best_loyal_id, {})).get("name", "alguém"))
	var secret := _osric_secret_for(best_loyal_id)
	osric.say("...%s" % secret.short, 4.5)
	osric.show_emote("...", 3.0)
	hud.toast("🔮 Osric murmura: %s" % secret.long, 7.0)
	hud.add_event_log("Oráculo de Osric sobre %s: %s" % [npc_name, secret.long])
	Game.create_evidence("overheard",
		Game.nearest_location(osric.global_position),
		"Osric revelou: %s" % secret.long, 18.0, "", best_loyal_id, "villager_elder")
	Game.add_memory("villager_elder", "Revelou segredo sobre %s ao Estagiário." % npc_name)


func _osric_secret_for(npc_id: String) -> Dictionary:
	match npc_id:
		"npc_baker":
			return {"short": "O pão tem história...", "long": "João esconde dívidas com o Rei. Pressione-o com boatos sobre impostos."}
		"npc_smith":
			return {"short": "Aquele martelo viu coisas...", "long": "Marten foi humilhado pelo Rei diante de todos. A raiva dele está borbulhando."}
		"npc_priestess":
			return {"short": "O templo chora por dentro...", "long": "Mira sabe de um segredo sombrio do Rei. Uma relíquia desaparecida a moveria."}
		"npc_merchant":
			return {"short": "O mercador calcula mais do que vende...", "long": "Valdo guarda documentos comprometedores sobre o Rei. Ele vende a quem pagar mais."}
		"npc_orphan":
			return {"short": "A menina viu tudo...", "long": "Lila presenciou algo que o Rei quer esconder. Ela conta para quem a tratar bem."}
		"villager_farmer":
			return {"short": "A terra não mente...", "long": "Tobias sabe de um decreto secreto que arruinará os camponeses. Um boato basta para revoltá-lo."}
		"villager_woman":
			return {"short": "Helga ouviu o que não devia...", "long": "Helga ouviu o Rei planejando aumentar tributos. Ela guardou isso para si — até agora."}
		"villager_lady":
			return {"short": "A nobreza tem seus preços...", "long": "Isolde sabe que o Rei planeja confiscar terras nobres. Ela esperava uma chance de agir."}
		"villager_boy":
			return {"short": "O menino brinca perto demais do castelo...", "long": "Pip achou algo perto do portão que não devia estar ali. Pergunte a ele diretamente."}
		_:
			return {"short": "Todos têm segredos aqui...", "long": "Observe os que mais sorriem — são os que mais temem."}


func _observe_hint(npc_id: String) -> String:
	var d := clampi(Game.day - 1, 0, 2)
	var hints := {
		"npc_king": [
			"O Rei examina nervosamente um selo real. Objetos com brasão real plantados em lugares errados o deixariam paranóico.",
			"O Rei esconde documentos debaixo do trono. Uma carta lacrada falsificada poderia incriminá-lo.",
			"O Rei afasta qualquer um que se aproxima. A adaga real fora do lugar seria prova de conspiração.",
		],
		"npc_baker": [
			"João guarda uma moeda real escondida debaixo do balcão. Uma moeda falsa no caixa dele causaria confusão.",
			"O padeiro conta moedas com nervosismo. Plantar uma moeda com brasão real na padaria levantaria suspeitas.",
			"João olha para o castelo com raiva. Qualquer item real plantado perto dele o faria explodir.",
		],
		"npc_smith": [
			"Marten olha para o martelo com ressentimento. Ele se revoltaria se visse uma arma real perto da forja.",
			"O ferreiro aperta os punhos ao ver guardas. Uma espada enferrujada plantada na praça como 'prova' o tiraria do sério.",
			"Marten range os dentes trabalhando. A adaga do Rei perto da forja seria o estopim.",
		],
		"npc_guard": [
			"Bram fica parado no portão sem se mover. Só um tumulto grande o faria sair de lá.",
			"O guarda-chefe confere a tranca do portão obsessivamente. Nenhum objeto ou suborno vai tirá-lo dali — só o caos.",
			"Bram parece cansado, mas não sai do posto. Só uma revolta popular o forçaria a abandonar o portão.",
		],
		"npc_guard2": [
			"Renato olha para as moedas de outros com inveja. Uma moeda real ou falsa chamaria a atenção dele.",
			"O patrulheiro admira as armas do ferreiro de longe. Uma espada ou martelo plantado na rota dele o distrairia.",
			"Renato parece desatento e conta moedas no bolso. Qualquer objeto de valor o desviaria da patrulha.",
		],
		"npc_priestess": [
			"Mira toca a relíquia com reverência. Se a relíquia sumisse do templo, ela ficaria desesperada.",
			"A sacerdotisa relê o livro de ritos com preocupação. Mover o livro de ritos para outro lugar a perturbaria profundamente.",
			"Mira olha para o céu buscando sinais. A relíquia fora do templo seria um 'sinal divino' para ela agir.",
		],
		"npc_merchant": [
			"Valdo examina moedas com uma lupa. Uma moeda falsa misturada às dele o faria desconfiar do sistema.",
			"O mercador confere sua mercadoria paranóico. Plantar uma moeda real perto dele levantaria questões sobre de onde veio.",
			"Valdo embala tudo para ir embora. Qualquer evidência de corrupção real perto dele o motivaria a falar.",
		],
		"npc_orphan": [
			"Lila olha para a maçã com fome. Dar comida a ela ganha sua confiança — ela sabe coisas.",
			"A órfã brinca perto do lago sozinha. Um item pequeno como presente a faria se abrir sobre o que viu.",
			"Lila desenha no chão com um graveto. Ela confia em quem é gentil — comida mostra cuidado.",
		],
		"villager_farmer": [
			"Tobias examina a terra com frustração. Uma carta lacrada sobre novos impostos o revoltaria.",
			"O fazendeiro olha para o poste de decretos com medo. Plantar uma carta ou documento real ali o motivaria a agir.",
			"Tobias guarda sementes com desespero. Qualquer documento real provando novos impostos seria o limite dele.",
		],
		"villager_woman": [
			"Helga espia a casa dos vizinhos. Qualquer objeto real fora do lugar ela vai notar e espalhar para todos.",
			"A camponesa fofoca na fonte. Plantar uma moeda real ou anel na praça e ela conta para a vila inteira.",
			"Helga observa tudo com olhos de águia. Qualquer item do Rei fora do castelo ela transforma em escândalo.",
		],
		"villager_elder": [
			"Osric vigia o portão de longe com olhos atentos. Não tente enganá-lo — ele reporta tudo ao Bram.",
			"O ancião faz anotações mentais de tudo. Nenhum truque funciona nele — ele é incorruptível.",
			"Osric observa cada movimento na vila. Tentá-lo é perda de tempo — ele sempre avisa o Bram.",
		],
		"villager_boy": [
			"Pip corre atrás de borboletas perto do lago. Ele é uma criança — não entende de conspirações.",
			"O menino faz barulho correndo pela vila. Ele não liga para política — só quer brincar.",
			"Pip empilha pedrinhas perto da fonte. Inocente demais para se envolver — mas repete tudo que ouve.",
		],
		"villager_lady": [
			"Isolde examina suas jóias com vaidade. O anel com brasão real perto dela a faria questionar a nobreza do Rei.",
			"A Dama ajusta seu vestido e confere o reflexo. Uma moeda real ou objeto de corte a faria pensar que o Rei distribui favores.",
			"Isolde compara suas jóias com as da corte. O anel real fora do castelo a convenceria de que o poder está mudando.",
		],
	}
	var h: Array = hints.get(npc_id, ["Nada de especial a notar por enquanto."])
	return h[mini(d, h.size() - 1)]


func _listen_hint(npc_id: String) -> String:
	var d := clampi(Game.day - 1, 0, 2)
	var hints := {
		"npc_king": [
			"'Esses camponeses não sabem seu lugar...' — O Rei teme rebeliões. Sussurrar sobre uma revolta iminente o desestabilizaria.",
			"'Preciso de mais guardas...' — O Rei está paranoico. Boatos sobre traição na corte o deixariam em pânico.",
			"'Ninguém pode saber disso...' — O Rei esconde algo grave. Sussurrar que seus segredos foram revelados o quebraria.",
		],
		"npc_baker": [
			"'Esses impostos vão me falir!' — João odeia os impostos reais. Sussurrar sobre aumento de taxas o revoltaria.",
			"'O Rei não merece meu pão.' — O padeiro está no limite. Boatos sobre confisco da padaria o fariam agir.",
			"'Se alguém tivesse coragem...' — João está quase pronto. Sussurrar que outros já estão se revoltando o empurraria.",
		],
		"npc_smith": [
			"'A guarda real me humilhou!' — Marten odeia a guarda. Sussurrar sobre abuso dos guardas o faria explodir.",
			"'O Rei taxa meu ferro e não protege ninguém.' — Marten está furioso. Boatos sobre a guarda maltratando o povo o motivariam.",
			"'Se eu pudesse...' — O ferreiro quer agir. Sussurrar que a guarda está fraca ou que outros se revoltaram o traria para o lado certo.",
		],
		"npc_guard": [
			"'Enquanto eu estiver aqui, ninguém passa.' — Bram é absolutamente leal. Só um motim o tiraria do portão.",
			"'Meu dever é com o Rei e ponto final.' — Bram não cede a boatos. Apenas caos generalizado o forçaria a agir.",
			"'Mesmo cansado, não saio daqui.' — A única forma de mover Bram é criar uma revolta que ele não possa ignorar.",
		],
		"npc_guard2": [
			"'O soldo nem paga minhas contas...' — Renato reclama do salário. Sussurrar sobre pagamento melhor o tentaria.",
			"'Por que Bram ganha mais que eu?' — Renato tem inveja. Boatos sobre dinheiro ou privilégios dos guardas o irritariam.",
			"'Estou cansado de servir quem não me paga.' — Renato está quase desertando. Sussurrar sobre riquezas o convenceria a mudar de lado.",
		],
		"npc_priestess": [
			"'Os céus estão em silêncio...' — Mira está perturbada. Sussurrar sobre um sinal divino contra o Rei a moveria.",
			"'Algo profano aconteceu no templo.' — Mira pressente algo. Boatos sobre profanação sagrada a fariam questionar o Rei.",
			"'Se os deuses querem mudança...' — Mira está pronta para ouvir. Sussurrar sobre visões ou profanações a convenceria a agir.",
		],
		"npc_merchant": [
			"'As tarifas do Rei estão me arruinando.' — Valdo odeia as tarifas. Sussurrar sobre novas taxas comerciais o revoltaria.",
			"'Preciso de um novo rei para os negócios.' — Valdo quer mudança. Boatos sobre liberação do comércio o motivariam.",
			"'Vou embora se isso continuar.' — Valdo está de saída. Sussurrar sobre oportunidades com um novo regime o traria como aliado.",
		],
		"npc_orphan": [
			"'Queria que alguém cuidasse de mim...' — Lila é carente. Ela repete o que ouve — seja gentil e ela espalhará seus boatos.",
			"'Vi uma coisa estranha ontem...' — Lila observa tudo. Ela conta segredos para quem é amigável.",
			"'Ninguém liga pra mim aqui.' — Lila quer atenção. Qualquer conversa gentil a fará sua aliada.",
		],
		"villager_farmer": [
			"'A colheita foi toda para os impostos.' — Tobias está revoltado. Sussurrar sobre novos decretos de cobrança o enfureceria.",
			"'Meus filhos passam fome por causa do Rei.' — Tobias está desesperado. Boatos sobre confisco de terras o empurrariam para a revolta.",
			"'Se os outros também se revoltassem...' — Tobias quer companhia. Sussurrar que a vila inteira está insatisfeita o traria para o movimento.",
		],
		"villager_woman": [
			"'Você ouviu o que aconteceu na praça?' — Helga adora fofoca. Qualquer boato escandaloso ela espalha — quanto mais dramático, melhor.",
			"'O Rei fez outra coisa absurda!' — Helga está empolgada para fofocar. Boatos sobre escândalos da corte ela multiplica por dez.",
			"'Todo mundo está falando...' — Helga é o megafone da vila. Sussurrar qualquer coisa sobre o Rei e ela garante que todos saibam.",
		],
		"villager_elder": [
			"'Reis justos não fazem isso.' — Osric é sábio e incorruptível. Não tente manipulá-lo — ele reporta tudo ao Bram.",
			"'Já vi reinos caírem antes.' — Osric observa e julga. Ele não pode ser enganado — cuidado.",
			"'A verdade sempre aparece.' — Osric é um obstáculo. Evite-o com itens suspeitos — ele é os olhos de Bram.",
		],
		"villager_boy": [
			"'Queria brincar mais, mas mamãe me põe pra trabalhar...' — Pip é só uma criança. Não tem noção de política.",
			"'Vi o guarda pegar uma coisa brilhante!' — Pip vê coisas mas não entende. Ele repete sem filtro.",
			"'Quero ser cavaleiro quando crescer!' — Pip vive no mundo da fantasia. Inocente — mas é uma boa distração.",
		],
		"villager_lady": [
			"'A corte já não é o que era.' — Isolde está insatisfeita. Sussurrar sobre confisco de terras nobres a revoltaria.",
			"'O Rei distribui favores a quem não merece.' — Isolde quer mudança. Boatos sobre a nobreza perdendo prestígio a motivariam.",
			"'Talvez seja hora de mudar de lado.' — Isolde está pronta. Sussurrar sobre um novo poder emergindo a convenceria a agir.",
		],
	}
	var h: Array = hints.get(npc_id, ["Nada de concreto — tente novamente mais tarde."])
	return h[mini(d, h.size() - 1)]


func _evaluate_ask_help(npc: NPC) -> Dictionary:
	var nid := npc.id
	var st: Dictionary = Game.npc_state.get(nid, {})
	var loyalty := float(st.get("loyalty", 100))
	var fear := float(st.get("fear", 50))
	var instab := Game.instability

	var accepts := false
	var accept_line := "Vou te ajudar."
	var refuse_line := "Não tenho nada a ver com isso."
	var toast := "Ficou desconfiado."
	var suspicion_penalty := 15.0
	var anger_penalty := 10.0

	match nid:
		"villager_boy":  # Pip — ajuda sempre, sem senso
			accepts = true
			accept_line = "Boa! Que missão secreta é essa?!"
			toast = ""
		"npc_orphan":  # Lila — ajuda se não estiver com muito medo
			accepts = fear < 65.0
			accept_line = "Tudo bem, posso fazer isso."
			refuse_line = "Tenho medo de me meter em problema..."
			toast = "Ela está com medo demais."
			suspicion_penalty = 5.0
			anger_penalty = 0.0
		"npc_merchant":  # Valdo — ajuda se lealdade baixa OU instabilidade alta
			accepts = loyalty < 30.0 or instab > 40.0
			accept_line = "Hmm... tem algo para mim nisso?"
			refuse_line = "Não gosto de me comprometer."
			toast = "Quer mais instabilidade antes."
			suspicion_penalty = 10.0
			anger_penalty = 5.0
		"npc_baker":  # João — ajuda se instabilidade > 50
			accepts = instab > 50.0
			accept_line = "Tá bom, já estou farto desta situação!"
			refuse_line = "Ainda é muito arriscado para mim."
			toast = "Precisa de mais pressão na cidade (instabilidade > 50)."
			suspicion_penalty = 10.0
			anger_penalty = 5.0
		"npc_smith":  # Marten — ajuda se instabilidade > 50
			accepts = instab > 50.0
			accept_line = "Se vai mudar alguma coisa, estou dentro!"
			refuse_line = "Ainda não chegou a hora."
			toast = "Precisa de mais pressão na cidade (instabilidade > 50)."
			suspicion_penalty = 10.0
			anger_penalty = 8.0
		"villager_woman":  # Helga — ajuda se instabilidade > 30
			accepts = instab > 30.0
			accept_line = "Ah, que delícia de confusão! Tô dentro!"
			refuse_line = "Não, não, eu não me meto em intrigas."
			toast = "Precisa de mais tensão na cidade (instabilidade > 30)."
			suspicion_penalty = 8.0
			anger_penalty = 0.0
		"villager_farmer":  # Tobias — ajuda se instabilidade > 40
			accepts = instab > 40.0
			accept_line = "Já estou cansado de tudo isso. Tudo bem."
			refuse_line = "Preciso proteger minha família."
			toast = "Ainda tem medo de represálias (instabilidade > 40)."
			suspicion_penalty = 10.0
			anger_penalty = 5.0
		"npc_priestess":  # Mira — ajuda só se lealdade muito baixa
			accepts = loyalty < 35.0
			accept_line = "Se os céus permitem... vou confiar em você."
			refuse_line = "Devo manter-me fiel à ordem estabelecida."
			toast = "Lealdade alta demais — ela respeita a ordem."
			suspicion_penalty = 12.0
			anger_penalty = 5.0
		"villager_elder":  # Ancião Osric — ajuda só se lealdade baixa E instabilidade > 60
			accepts = loyalty < 30.0 and instab > 60.0
			accept_line = "Vi reis caírem antes. Farei o que posso."
			refuse_line = "A prudência me impede. Não sou impulsivo."
			toast = "Precisa de instabilidade alta e lealdade baixa (> 60 / < 30)."
			suspicion_penalty = 8.0
			anger_penalty = 0.0
		"villager_lady":  # Dama Isolde — oportunista, ajuda se instab > 60
			accepts = instab > 60.0
			accept_line = "Talvez seja hora de apostar em outra carta..."
			refuse_line = "Não me envolvo em conspirações, por favor."
			toast = "Ainda quer ver quem vence antes de agir (instabilidade > 60)."
			suspicion_penalty = 10.0
			anger_penalty = 8.0
		"npc_king", "npc_guard", "npc_guard2":  # Nunca ajudam
			accepts = false
			refuse_line = "Guarda! GUARDA!"
			toast = "Denunciou você!"
			suspicion_penalty = 30.0
			anger_penalty = 25.0
		_:
			accepts = loyalty < 40.0

	return {
		"accepts": accepts,
		"accept_line": accept_line,
		"refuse_line": refuse_line,
		"toast": toast,
		"suspicion_penalty": suspicion_penalty,
		"anger_penalty": anger_penalty,
	}


func _evaluate_chain_events() -> void:
	_sync_runtime_suspicion()
	var changes := Game.evaluate_events()
	for ch in changes:
		match ch.state:
			"AVAILABLE":
				hud.toast("Evento disponível: %s" % ch.title, 3.0)
			"ACTIVE":
				hud.toast("Evento em andamento: %s" % ch.title, 3.5)
				Sfx.play("confirm")
			"RESOLVED":
				hud.toast("Evento concluído: %s" % ch.title, 4.0)
				Sfx.play("coins")
				_apply_event_effects(ch.id)
			"FAILED":
				hud.toast("Evento fracassou: %s" % ch.title, 4.0)
				Sfx.play("error")
	_refresh_chain_panel()
	if Game.get_event_state("king_deposed") == Game.EventState.RESOLVED:
		if Game.instability < 100.0:
			Game.set_instability(100.0)


func _refresh_chain_panel() -> void:
	var chain: Array = []
	for eid in Game.EVENT_DEFS:
		var def: Dictionary = Game.EVENT_DEFS[eid]
		var st: int = Game.get_event_state(eid)
		chain.append({
			"label": def.title,
			"done": st == Game.EventState.RESOLVED,
			"active": st == Game.EventState.ACTIVE or st == Game.EventState.AVAILABLE,
		})
	hud.update_chain_panel(chain)


func _apply_event_effects(event_id: String) -> void:
	match event_id:
		"guard_interrogates":
			var guard: NPC = npcs.get("npc_guard")
			if guard:
				guard.walk_to(Game.loc_pos("plaza"), true)
				guard.say("Alguém aqui tem explicações a dar!", 4.0)
			trigger_active_event({
				"name": "Investigação na Praça",
				"objective": "Impeça o guarda de encontrar provas contra você",
				"duration": 20.0, "risk": 55.0,
				"npc_ids": ["npc_guard", "npc_baker"],
			"hint": "Destrua evidências ou distraia o guarda",
			"consequences": "Se falhar, sua identidade pode ser revelada",
			"location": "plaza",
			"success_actions": ["destroy_evidence", "incriminate", "ask_help"],
			"success_action": "bump:npc_guard:anger:10",
				"fail_action": "instability:-10",
			})
		"guard_leaves_post":
			var guard2: NPC = npcs.get("npc_guard")
			if guard2:
				guard2.walk_to(Game.loc_pos("forge"), true)
				guard2.say("Preciso ver o que está acontecendo!", 3.5)
			if mission:
				mission.phase = MissionPortao.MPhase.TENSE
			trigger_active_event({
				"name": "Portão Desguarnecido",
				"objective": "Aproveite a ausência do guarda para cruzar o portão",
				"duration": 22.0, "risk": 40.0,
				"npc_ids": ["npc_guard", "villager_elder"],
				"hint": "Cuidado com o Ancião Osric observando",
				"consequences": "O guarda vai voltar em breve",
				"location": "castle_gate",
				"skip_spawn": true,
				"success_actions": [],
				"success_action": "",
				"fail_action": "bump:npc_guard:anger:15",
			})
		"witness_appears":
			var elder: NPC = null
			for v in villagers:
				if v.id == "villager_elder":
					elder = v
					break
			if elder:
				elder.walk_to(Game.loc_pos("plaza"))
				elder.say("Eu vi algo estranho acontecendo...", 4.0)
			trigger_active_event({
				"name": "Testemunha Inconveniente",
				"objective": "Impeça o ancião de denunciá-lo",
				"duration": 18.0, "risk": 62.0,
				"npc_ids": ["villager_elder"],
			"hint": "Convença-o com um boato ou distraia-o com um objeto",
			"consequences": "Se o ancião falar, a suspeita sobre você aumenta muito",
			"location": "plaza",
			"success_actions": ["ask_help", "incriminate", "hide"],
			"success_action": "bump:villager_elder:loyalty:-20",
				"fail_action": "instability:-15",
			})
		"king_deposed":
			Game.set_instability(100.0)


const _CONVERSA_NEUTRA := [
	"Você ouviu sobre o decreto?", "A praça está diferente hoje...",
	"Não sei se confio mais no guarda.", "Será que é verdade aquilo?",
	"O padeiro me disse algo preocupante.", "Tenho um mau pressentimento.",
]
const _CONVERSA_TENSA := [
	"Eu ouvi que o Rei está escondendo algo!", "Isso não pode continuar assim!",
	"O ferreiro está furioso, sabia?", "Alguém precisa fazer alguma coisa!",
	"Até quando vamos aguentar?!", "O povo está cansado!",
]
const _DISCUSSAO := [
	"Você está maluco?!", "Cala a boca!", "Não fale assim do Rei!",
	"Você é cego?! Não vê o que acontece?!", "Traidor!", "Covarde!",
	"Quem você pensa que é?!", "Sai da minha frente!",
]
const _BRIGA := [
	"Vou te ensinar!", "Toma!", "Para trás!", "Sai daqui!",
]


func _update_ambient_panic() -> void:
	var instab := Game.instability
	if instab < 30.0:
		return
	var all_npcs: Array = npcs.values() + villagers
	var panic_chance := clampf((instab - 30.0) / 70.0, 0.0, 1.0) * 0.6
	var frases_leve := ["Algo está errado...", "Que estranho...", "Estou com mau pressentimento."]
	var frases_alto := ["O que está acontecendo?!", "Isso é preocupante!", "Devemos nos reunir!"]
	var frases_critico := ["O povo está em fúria!", "Isso vai acabar mal!", "Agentes do mal entre nós!"]

	# === Dia 2+ com 50%+ de instabilidade: NPCs interagem entre si ===
	if Game.day >= 2 and instab >= 50.0:
		_npc_social_interactions(all_npcs, instab)

	for npc: NPC in all_npcs:
		if not npc.visible or not is_instance_valid(npc) or npc.pursuing or npc.fallen:
			continue
		if randf() > panic_chance:
			continue
		if instab >= 75.0:
			npc.show_emote(["!", "!"][randi() % 2], 2.5)
			if randf() < 0.5:
				npc.say(frases_critico[randi() % frases_critico.size()], 3.5)
				npc.hurt_mood(0.3, 0.3)
			if randf() < 0.4 and not npc.moving:
				var others := all_npcs.filter(func(o): return o != npc and is_instance_valid(o) and o.visible and not o.pursuing)
				if not others.is_empty():
					var target_npc: NPC = others[randi() % others.size()]
					var gather_pos := target_npc.global_position + Vector2(randf_range(-24, 24), randf_range(-12, 12))
					npc.walk_to(gather_pos, true)
		elif instab >= 50.0:
			npc.show_emote(["!", "?"][randi() % 2], 2.0)
			if randf() < 0.35:
				npc.say(frases_alto[randi() % frases_alto.size()], 3.0)
			npc.hurt_mood(0.1, 0.1)
		else:
			if randf() < 0.25:
				npc.show_emote("...", 1.8)
				if randf() < 0.2:
					npc.say(frases_leve[randi() % frases_leve.size()], 2.5)
	if instab >= 60.0:
		var guard: NPC = npcs.get("npc_guard")
		if guard and is_instance_valid(guard) and not guard.pursuing and not guard.fallen:
			if not guard.moving and guard.ambient:
				guard.show_emote("!", 1.5)
				guard.say("Preciso ficar de olho...", 2.5)


func _npc_social_interactions(all_npcs: Array, instab: float) -> void:
	var valid := all_npcs.filter(func(n: NPC): return is_instance_valid(n) and n.visible and not n.fallen and not n.pursuing)
	if valid.size() < 2:
		return
	# Encontrar pares próximos (< 80px)
	var pairs: Array = []
	for i in valid.size():
		for j in range(i + 1, valid.size()):
			var dist: float = valid[i].global_position.distance_to(valid[j].global_position)
			if dist < 80.0:
				pairs.append([valid[i], valid[j]])
	if pairs.is_empty():
		# Se não há pares próximos, fazer alguém ir até outro para conversar
		if randf() < 0.3:
			var a: NPC = valid[randi() % valid.size()]
			var b: NPC = valid[randi() % valid.size()]
			if a != b and not a.moving:
				a.walk_to(b.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)))
		return

	# Escolher um par aleatório para interagir
	var pair: Array = pairs[randi() % pairs.size()]
	var npc_a: NPC = pair[0]
	var npc_b: NPC = pair[1]

	# Tipo de interação baseado na instabilidade
	var roll := randf()
	if instab >= 75.0:
		# Alta instabilidade: briga física (empurrão + gritos)
		if roll < 0.35:
			_npc_fight(npc_a, npc_b)
		elif roll < 0.65:
			_npc_argument(npc_a, npc_b)
		else:
			_npc_conversation(npc_a, npc_b, true)
	elif instab >= 60.0:
		# Média-alta: discussões acaloradas e empurrões ocasionais
		if roll < 0.15:
			_npc_fight(npc_a, npc_b)
		elif roll < 0.50:
			_npc_argument(npc_a, npc_b)
		else:
			_npc_conversation(npc_a, npc_b, true)
	else:
		# 50-60%: conversas tensas, discussão rara
		if roll < 0.10:
			_npc_argument(npc_a, npc_b)
		elif roll < 0.50:
			_npc_conversation(npc_a, npc_b, true)
		else:
			_npc_conversation(npc_a, npc_b, false)


func _npc_conversation(a: NPC, b: NPC, tense: bool) -> void:
	var frases := _CONVERSA_TENSA if tense else _CONVERSA_NEUTRA
	a.say(frases[randi() % frases.size()], 3.5)
	a.show_emote("?" if not tense else "!", 2.5)
	# O outro responde depois de um breve intervalo
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(b) and not b.fallen:
			b.say(frases[randi() % frases.size()], 3.0)
			b.show_emote("..." if not tense else "?", 2.0)
	)


func _npc_argument(a: NPC, b: NPC) -> void:
	a.say(_DISCUSSAO[randi() % _DISCUSSAO.size()], 3.5)
	a.show_emote("!", 3.0)
	a.hurt_mood(0.2, 0.2)
	emit_particle("exclamation", (a.global_position + b.global_position) / 2.0)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(b) and not b.fallen:
			b.say(_DISCUSSAO[randi() % _DISCUSSAO.size()], 3.5)
			b.show_emote("!", 2.5)
			b.hurt_mood(0.2, 0.2)
	)
	# Se estiverem longe, aproximar para discutir cara a cara
	if a.global_position.distance_to(b.global_position) > 30.0 and not a.moving:
		a.walk_to(b.global_position + Vector2(randf_range(-15, 15), randf_range(-8, 8)), true)


func _npc_fight(a: NPC, b: NPC) -> void:
	a.say(_BRIGA[randi() % _BRIGA.size()], 3.0)
	a.show_emote("!", 2.5)
	b.show_emote("!", 2.5)
	# Empurrão: A empurra B
	a.current_state = "ANGRY"
	a.hurt_mood(0.4, 0.3)
	b.hurt_mood(0.3, 0.4)
	a.walk_to(b.global_position, true)
	emit_particle("smoke_thin", (a.global_position + b.global_position) / 2.0)
	emit_particle("stars_dizzy", (a.global_position + b.global_position) / 2.0 + Vector2(0, -8))
	shake = 2.0
	Sfx.play("thud")
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(b) and not b.fallen:
			b.say(_BRIGA[randi() % _BRIGA.size()], 2.5)
			# B tropeça para trás
			var push_dir := a.global_position.direction_to(b.global_position)
			b.walk_to(b.global_position + push_dir * 30.0)
			b.hurt_mood(0.3, 0.3)
	)
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(a) and not a.fallen:
			a.current_state = "IDLE"
	)


func _update_cam(_delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var half := vp / (2.0 * cam_zoom)
	cam_target.x = clampf(cam_target.x, minf(half.x, 640.0), maxf(Game.MAP_SIZE.x - half.x, 640.0))
	cam_target.y = clampf(cam_target.y, minf(half.y, 480.0), maxf(cam_limit_bottom - half.y, 480.0))
	cam.position = cam.position.lerp(cam_target, 0.08 if phase != Phase.ACTION else 0.15)
	cam.zoom = cam.zoom.lerp(Vector2(cam_zoom, cam_zoom), 0.1)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.1 else Vector2.ZERO
	# Ação/terminal: câmera do jogador; simulação/cinemáticas: câmera do mundo (segue NPCs).
	player.camera.zoom = cam.zoom
	player.camera.offset = cam.offset
	if phase == Phase.ACTION or phase == Phase.TERMINAL or phase == Phase.ACTIVE_EVENT or phase == Phase.PURSUIT:
		if not player.camera.is_current():
			player.camera.make_current()
		cam.position = player.camera.get_screen_center_position()
	elif not cam.is_current():
		cam.make_current()


func _ambient() -> Color:
	var c := Color.WHITE
	if clock < 9.0:
		c = Color(1.0, 0.86, 0.72).lerp(Color.WHITE, clampf((clock - 8.0), 0.0, 1.0))
	elif clock < 16.0:
		c = Color.WHITE
	elif clock < 19.0:
		c = Color.WHITE.lerp(Color(1.0, 0.8, 0.55), clampf((clock - 16.0) / 3.0, 0.0, 1.0))
	else:
		c = Color(1.0, 0.8, 0.55).lerp(Color(0.38, 0.42, 0.7), clampf((clock - 19.0) / 2.5, 0.0, 1.0))
	var dark := clampf((Game.instability - 55.0) / 45.0, 0.0, 0.4)
	return c.lerp(Color(0.35, 0.3, 0.4), dark)
