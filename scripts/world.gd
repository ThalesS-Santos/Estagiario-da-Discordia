extends Node2D
## Mundo da aldeia: mapa, NPCs, objetos, fase de ação (jogador) e fase de simulação (IA).

signal victory
signal defeat
signal quit_to_menu

enum Phase { ACTION, TERMINAL, SIM, ENDED }

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
var village: Village
var villagers: Array = []
var overlay: Overlay
var player: PlayerIntern
var gossip_npc: NPC = null
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
		vd["wide_wander"] = true
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
			"position": {"x": npc.global_position.x, "y": npc.global_position.y},
			"memories": saved.get("memories", []).duplicate()}
	return states


func _on_gossip_submitted(_context: Dictionary, text: String) -> void:
	terminal_submit(text)


func _request_caos(narrative: String) -> void:
	if ai_waiting or gemini_director.is_processing or (held == null and gossip_npc == null):
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
	# Capture live states before stopping movement or changing the simulation phase.
	var states := _live_npc_states()
	phase = Phase.SIM
	ai_waiting = true
	player.input_enabled = false
	hud.close_terminal()
	hud.set_sim(true)
	hud.set_loading(true) # Must precede evaluate: local validation can fail synchronously.
	gemini_director.evaluate_butterfly_effect(action, narrative, states,
		{"day": Game.day, "instability": Game.instability, "rumors": Game.rumors})


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
		var dialogue: String = directive.dialogue_bubble
		if dialogue != "":
			Game.add_memory(npc.id, dialogue)
			hud.subtitle(str(npc.def.get("name", npc.id)), dialogue)
	Game.apply_npc_updates(data.npc_updates)
	# This signal drives the existing HUD tween. Never add the delta again on end-day.
	Game.add_instability(float(data.instability_delta))
	hud.toast("Instabilidade %+d%%" % int(data.instability_delta), 2.5)
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
	player.position = Vector2(640, 500)
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
	actions_today.append({
		"obj": null, "from": Vector2.ZERO, "cost": 1,
		"payload": {"object_id": "", "object_name": "Sussurro para %s" % n.def.name, "tags": [], "location": Game.nearest_location(n.position),
			"narrative": narrative, "target_npc": n.id},
	})
	Sfx.play("confirm")
	rings.append({"p": n.position, "age": 0.0})
	n.show_emote("?", 2.5)
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
	npcs["npc_guard"].position = Game.loc_pos("castle_gate") + Vector2(0, 14)
	for npc: NPC in villagers:
		npc.fear = int(Game.npc_state[npc.id].fear)
		npc.anger = int(Game.npc_state[npc.id].anger)
		npc.loyalty = int(Game.npc_state[npc.id].loyalty)
		npc.ambient = true
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
	snapshot = {"instab": Game.instability, "npc": Game.npc_state.duplicate(true), "poisoned": poisoned, "fish_dead": fish_dead, "water": water_color, "rumors": Game.rumors, "obj": {}}
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
	poisoned = snapshot.poisoned
	fish_dead = snapshot.fish_dead
	water_color = snapshot.water
	Game.rumors = snapshot.rumors
	_restore_checkpoint(snapshot.world)
	hud.close_terminal()
	_start_day()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.TERMINAL or phase == Phase.ENDED:
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
		cam_target = mp
		return
	# Pegar/soltar agora é do PlayerIntern; aqui só resta fixar o card do NPC clicado.
	var n := _npc_at(mp)
	if n and _obj_at(mp) == null:
		hud.show_npc(n, true)


func _right_click() -> void:
	if phase != Phase.ACTION or not held:
		return
	drop_pos = player.drop_position().clamp(Vector2.ZERO, Game.MAP_SIZE)
	_request_caos("")


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
	Sfx.play("plop")
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
	# Instability and NPC stats were committed in _on_caos_gerado, exactly once.
	if Game.instability >= 100.0:
		phase = Phase.ENDED
		await _victory_sequence()
		victory.emit()
	elif _ending_day:
		phase = Phase.ENDED
		if Game.day >= Game.MAX_DAYS:
			await _defeat_sequence()
			defeat.emit()
		else:
			Game.day += 1
			_start_day()
	else:
		phase = Phase.ACTION
		for npc: NPC in _ai_actors().values():
			npc.ambient = true
		player.input_enabled = true
		if Game.ap == 0:
			hud.toast("Sem PA — encerre o dia para continuar.")
	hud.set_sim(false)


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


func _defeat_sequence() -> void:
	hud.set_ui_visible(false)
	cam_target = Vector2(640, 200)
	var k: NPC = npcs["npc_king"]
	k.position = Vector2(640, 168)
	k.say("Nenhum boato derruba esta coroa. A ordem está restaurada.", 5.0)
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
	# hover
	var mp := get_global_mouse_position()
	if phase == Phase.ACTION or phase == Phase.SIM:
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
	player.input_enabled = phase == Phase.ACTION
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
	elif phase == Phase.ACTION or phase == Phase.TERMINAL:
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
	if phase == Phase.ACTION or phase == Phase.TERMINAL:
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
