extends Node2D
## Mundo da aldeia: mapa, NPCs, objetos, fase de ação (jogador) e fase de simulação (IA).

signal victory
signal defeat
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
var sim_events: Array = []
var sim_time := 0.0
var sim_idx := 0
var sim_end := 0.0
var crisis := false
var day_revision := 0
var sim_running := false
var snapshot := {}
var rings: Array = []
var _active_event_current: Dictionary = {}
var _active_event_queue: Array = []
var _last_action_effect := true  # setado por _apply_action_specific, lido por _did_action_succeed
var _tension_t := 0.0
var _phase_before_confrontation: int = Phase.ACTION
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
		hud.show_tutorial()


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
			hud.add_event_log("%s: \"%s\"" % [npc_name, dialogue.substr(0, 60)])
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
	# This signal drives the existing HUD tween. Never add the delta again on end-day.
	Game.add_instability(float(data.instability_delta))
	hud.toast("Instabilidade %+d%%" % int(data.instability_delta), 2.5)
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
	# Spawn via portal pixelado numa borda aleatória do mapa
	player.input_enabled = false
	_spawn_player_portal()


func _spawn_player_portal() -> void:
	# Borda aleatória: 0=sul, 1=oeste, 2=leste
	var edge := randi() % 3
	var spawn_pos: Vector2
	match edge:
		0: spawn_pos = Vector2(randf_range(300, 900), 900)   # sul
		1: spawn_pos = Vector2(80,  randf_range(500, 750))   # oeste
		_: spawn_pos = Vector2(1200, randf_range(500, 750))  # leste
	player.position = spawn_pos
	# Portal: ColorRect pulsante sobre o jogador
	var portal := ColorRect.new()
	portal.color = Color(0.55, 0.1, 0.9, 0.0)
	portal.size = Vector2(36, 48)
	portal.position = spawn_pos - Vector2(18, 24)
	portal.z_index = 20
	add_child(portal)
	# Animação de abertura do portal
	Sfx.play("portal_open")
	var tw := create_tween()
	tw.tween_property(portal, "color:a", 0.85, 0.25)
	tw.tween_interval(0.3)
	# Pisca 3x
	for _i in 3:
		tw.tween_property(portal, "color:a", 0.3, 0.07)
		tw.tween_property(portal, "color:a", 0.85, 0.07)
	tw.tween_interval(0.1)
	# Jogador materializa (flash branco) e portal some
	tw.tween_callback(func():
		player.modulate = Color(2.0, 2.0, 2.0, 1.0)
		Sfx.play("whoosh")
	)
	tw.tween_property(player, "modulate", Color(1, 1, 1, 1), 0.4)
	tw.tween_property(portal, "color:a", 0.0, 0.35)
	tw.tween_callback(func():
		portal.queue_free()
		player.input_enabled = phase == Phase.ACTION
	)


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
	if diff.patrol_enabled:
		guard.def["wide_wander"] = true
		guard.ambient = true
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
	_snapshot()
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
	if phase == Phase.TERMINAL or phase == Phase.CONFRONTATION or phase == Phase.ENDED:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_left_click()
			MOUSE_BUTTON_RIGHT:
				_right_click()
			MOUSE_BUTTON_WHEEL_UP:
				cam_zoom = clampf(cam_zoom + 0.07, 0.8, 1.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_zoom = clampf(cam_zoom - 0.07, 0.8, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			undo()
		elif event.keycode == KEY_END and OS.is_debug_build():
			_debug_autoplay()
		elif event.keycode == KEY_INSERT and OS.is_debug_build() and not held:
			_try_pick(objects["apple"])
			_open_drop_terminal(Game.loc_pos("plaza"))


func _debug_autoplay() -> void:
	## Só desenvolvimento: joga uma ação completa sem depender do mouse.
	if phase != Phase.ACTION or held:
		return
	_try_pick(objects["poison_vial"])
	held_from = held.position
	_open_drop_terminal(Game.loc_pos("lake") + Vector2(0, -60))
	terminal_submit("O Rei mandou envenenar a agua do lago")


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
		var npc_actions := ["observe", "listen", "gossip", "follow", "confront", "protect", "ask_help"]
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
	# Vitória por revolta: instabilidade só conta se o rei foi deposto pela cadeia de eventos.
	# Instabilidade alta sem king_deposed é pressão acumulada, não vitória.
	var king_deposed := Game.get_event_state("king_deposed") == Game.EventState.RESOLVED
	if Game.instability >= 100.0 and king_deposed:
		phase = Phase.ENDED
		await _victory_sequence()
		victory.emit()
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


func _did_action_succeed(action_id: String, target_npc: NPC) -> bool:
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
func _victory_sequence() -> void:
	crisis = true
	for light in village.lights:
		if light is PointLight2D:
			light.color = Color(1.0, 0.25, 0.08)
	hud.set_ui_visible(false)
	hud.alarm()
	Sfx.play("alarm")
	follow = null
	cam_zoom = 1.0
	cam_target = Vector2(640, 300)
	await get_tree().create_timer(1.2).timeout
	var i := 0
	for id in npcs:
		var n: NPC = npcs[id]
		n.ambient = false
		n.get_up()
		n.visible = true
		if id == "npc_king":
			continue
		n.position = n.position if n.position.x > 0 else Vector2(640, 940)
		n.walk_to(Game.loc_pos("castle_gate") + Vector2(-80 + i * 32, 70 + (i % 2) * 26), true)
		n.say("Abaixo o Rei!" if i % 2 == 0 else "Justiça!", 4.0)
		emit_particle("crowd_murmur", n.position)
		i += 1
	npcs["npc_smith"].walk_to(Game.loc_pos("castle_gate") + Vector2(0, 40), true)
	Sfx.play("murmur")
	await get_tree().create_timer(6.0).timeout
	gate_open = 1.0
	Sfx.play("horn")
	npcs["npc_king"].position = Vector2(640, 168)
	npcs["npc_king"].show_emote("!", 4.0)
	npcs["npc_king"].say("Isso é um absurdo!", 3.0)
	await get_tree().create_timer(3.0).timeout
	emit_particle("sparkle_gold", Vector2(640, 150))
	emit_particle("sparkle_gold", Vector2(640, 170))
	Sfx.play("coins")
	shake = 8.0
	create_tween().tween_property(self, "flag_drop", 1.0, 2.0)
	npcs["npc_king"].fall()
	await get_tree().create_timer(3.0).timeout
	hud.flash()
	for n in npcs.values() + villagers:
		n.moving = false
		n.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout


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
	player.input_enabled = phase == Phase.ACTION or phase == Phase.ACTIVE_EVENT or phase == Phase.PURSUIT
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
	# luz ambiente
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
		if dist > _SUSPICION_SIGHT_RADIUS:
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
			npc.add_suspicion(base_rate * exposure * susp_rate * float(rep_mod.suspicion_mult) * delta)

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
				var _watch_t := 3.0
				if mission:
					if target_npc.id == "npc_guard":
						mission.notify_object_picked("observe_guard")
		"listen":
			if target_npc:
				player.set_emotion("SUSPICIOUS")
				var saved: Dictionary = Game.npc_state.get(target_npc.id, {})
				var memories: Array = saved.get("memories", [])
				if not memories.is_empty():
					var last: String = memories.back()
					Game.create_evidence("overheard", loc,
						"Ouviu %s dizer: \"%s\"" % [str(target_npc.def.get("name", "")), last.left(50)],
						10.0, "", "", target_npc.id)
					hud.toast("Você ouviu algo útil de %s." % str(target_npc.def.get("name", "")), 3.0)
				else:
					hud.toast("%s não disse nada interessante." % str(target_npc.def.get("name", "")), 2.5)
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
				var loyalty: float = float(Game.npc_state.get(target_npc.id, {}).get("loyalty", 100))
				if loyalty < 40:
					target_npc.say("Vou te ajudar.", 3.0)
					target_npc.show_emote("<3", 2.0)
					Game.bump(target_npc.id, "loyalty", -10.0)
					hud.toast("%s está do seu lado." % str(target_npc.def.get("name", "")), 3.0)
					_last_action_effect = true
				else:
					# Recusa: o NPC fica com mais suspeita e pode denunciar
					target_npc.say("Não tenho o que falar com você.", 3.0)
					target_npc.show_emote("!", 2.0)
					target_npc.add_suspicion(15.0)
					Game.bump(target_npc.id, "anger", 10.0)
					hud.toast("%s recusou e ficou desconfiado." % str(target_npc.def.get("name", "")), 3.5)
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


func _update_cam(_delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var half := vp / (2.0 * cam_zoom)
	cam_target.x = clampf(cam_target.x, minf(half.x, 640.0), maxf(Game.MAP_SIZE.x - half.x, 640.0))
	cam_target.y = clampf(cam_target.y, minf(half.y, 480.0), maxf(Game.MAP_SIZE.y - half.y, 480.0))
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
