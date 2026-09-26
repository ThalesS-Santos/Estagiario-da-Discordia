extends Node2D
## Mundo da aldeia: mapa, NPCs, objetos, fase de ação (jogador) e fase de simulação (IA).

signal victory
signal defeat
signal quit_to_menu

enum Phase { ACTION, TERMINAL, SIM, ENDED }

const HudScript := preload("res://scripts/hud.gd")

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
var sim_delta := 0.0
var sim_running := false
var snapshot := {}
var rings: Array = []
var village: Village
var villagers: Array = []
var overlay: Overlay


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
		n.setup(vid, {"name": "", "role": "Aldeão", "size": Vector2(28, 44), "home_pos": Vector2(float(p[0]), float(p[1])), "decor": true}, self)
		npc_root.add_child(n)
		villagers.append(n)
	for id in Game.OBJECTS:
		var d: Dictionary = Game.OBJECTS[id]
		var o := WorldObject.new()
		o.setup(id, d, Game.loc_pos(d.loc) + d.off)
		obj_root.add_child(o)
		objects[id] = o
	cam = Camera2D.new()
	add_child(cam)
	cam.position = cam_target
	mod = CanvasModulate.new()
	add_child(mod)
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	Game.instability_changed.connect(func(_v): pass)
	_start_day()
	if tutorial:
		hud.show_tutorial()


# ------------------------------------------------------------------ dia
func _start_day() -> void:
	phase = Phase.ACTION
	clock = 8.0
	sim_running = false
	follow = null
	actions_today.clear()
	Game.reset_ap()
	for id in npcs:
		var n: NPC = npcs[id]
		n.get_up()
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
		m.position = Vector2(-500, -500)
	else:
		m.position = Vector2(640, 960)
		m.walk_to(Game.loc_pos("stall") + Vector2(0, 20))
		m.home = Game.loc_pos("stall") + Vector2(0, 20)
	npcs["npc_guard"].position = Game.loc_pos("castle_gate") + Vector2(0, 14)
	_snapshot()
	hud.new_day()
	Game.save_game()


func _snapshot() -> void:
	snapshot = {"instab": Game.instability, "npc": Game.npc_state.duplicate(true), "poisoned": poisoned, "fish_dead": fish_dead, "water": water_color, "rumors": Game.rumors, "obj": {}}
	for id in objects:
		snapshot.obj[id] = objects[id].position


func restart_day() -> void:
	if phase == Phase.SIM or phase == Phase.ENDED:
		return
	if held:
		held.held = false
		held = null
	for id in objects:
		objects[id].position = snapshot.obj[id]
		objects[id].attached_to = null
	Game.set_instability(snapshot.instab)
	Game.npc_state = snapshot.npc.duplicate(true)
	poisoned = snapshot.poisoned
	fish_dead = snapshot.fish_dead
	water_color = snapshot.water
	Game.rumors = snapshot.rumors
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
	_commit_drop(Game.loc_pos("lake") + Vector2(0, -60), "O Rei mandou envenenar a agua do lago")
	await get_tree().create_timer(1.0).timeout
	end_day_requested()


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
	var bd := 28.0
	for id in npcs:
		var n: NPC = npcs[id]
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
	var o := _obj_at(mp)
	if held:
		if o and o != held:
			# segundo clique em outro objeto cancela o primeiro (sem gastar PA)
			held.held = false
			held.position = held_from
			Game.refund_ap(1)
			held = null
			_try_pick(o)
			return
		_open_drop_terminal(mp)
		return
	if o:
		_try_pick(o)
		return
	var n := _npc_at(mp)
	if n:
		hud.show_npc(n, true)


func _right_click() -> void:
	if phase != Phase.ACTION or not held:
		return
	var mp := get_global_mouse_position()
	_commit_drop(mp, "")


func _try_pick(o: WorldObject) -> void:
	if Game.ap < 2:
		hud.toast("PA insuficiente — pegar + soltar custam 2 PA.")
		Sfx.play("error")
		return
	Game.spend_ap(1)
	held = o
	held_from = o.position
	o.held = true
	Sfx.play("whoosh")


func _open_drop_terminal(mp: Vector2) -> void:
	phase = Phase.TERMINAL
	drop_pos = mp
	held.position = mp
	var loc := Game.nearest_location(mp)
	hud.open_terminal(held.def.name, Game.loc_name(loc))


func terminal_cancel() -> void:
	if phase == Phase.TERMINAL:
		phase = Phase.ACTION


func terminal_submit(text: String) -> void:
	if phase != Phase.TERMINAL:
		return
	_commit_drop(drop_pos, text.strip_edges())


func _commit_drop(p: Vector2, narrative: String) -> void:
	if not held:
		return
	Game.spend_ap(1)
	var o := held
	held = null
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
	if Game.ap < 2:
		hud.toast("Sem PA suficientes — encerrando o dia...")
		get_tree().create_timer(1.6).timeout.connect(func():
			if phase == Phase.ACTION and not held:
				end_day_requested())


func undo() -> void:
	if phase != Phase.ACTION:
		return
	if held:
		held.held = false
		held.position = held_from
		held = null
		Game.refund_ap(1)
		return
	if actions_today.is_empty():
		return
	var a: Dictionary = actions_today.pop_back()
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
		Game.refund_ap(1)
	_start_simulation()


# ------------------------------------------------------------------ simulação
func _build_payload() -> Dictionary:
	var acts: Array = []
	for a in actions_today:
		acts.append(a.payload)
	var ws := {}
	for id in npcs:
		ws[id] = {"fear": Game.npc_state[id].fear, "anger": Game.npc_state[id].anger, "loyalty": Game.npc_state[id].loyalty,
			"credulity": Game.npc_state[id].cred, "x": int(npcs[id].position.x), "y": int(npcs[id].position.y)}
	var mem := {}
	for id in npcs:
		mem[id] = Game.npc_state[id].memories
	return {"player": Game.player_name, "day": Game.day, "instability": Game.instability, "rumors": Game.rumors,
		"actions": acts, "world_state": {"npcs": ws, "water_poisoned": poisoned}, "npc_memories": mem}


func _start_simulation() -> void:
	phase = Phase.SIM
	hud.set_sim(true)
	hud.toast("A IA está escrevendo o roteiro...")
	for id in npcs:
		npcs[id].ambient = false
		npcs[id].moving = false
	var payload := _build_payload()
	var res: Dictionary = await Director.simulate(payload)
	for a in actions_today:
		if a.payload.narrative != "":
			Game.rumors += 1
	sim_events = res.events.duplicate()
	sim_delta = float(res.instability_delta)
	_apply_world_changes(res.get("world_changes", {}))
	# reações do Rei e do Guarda conforme a instabilidade
	var proj := Game.instability + sim_delta
	var last_t := 0.0
	for e in sim_events:
		last_t = maxf(last_t, float(e.t))
	if proj >= 80.0:
		sim_events.append({"t": last_t + 2, "npc_id": "npc_guard", "action": "run_to", "target": "castle_yard", "dialogue": "", "particles": ["dust_small"], "sound": ""})
		sim_events.append({"t": last_t + 6, "npc_id": "npc_guard", "action": "talk_to", "target": "npc_king", "dialogue": "Majestade, o povo está inquieto!", "particles": ["exclamation"], "sound": "gasp"})
		sim_events.append({"t": last_t + 6.5, "npc_id": "npc_king", "action": "walk_to", "target": "castle_yard", "dialogue": "", "particles": [], "sound": ""})
		last_t += 6.5
	if proj >= 95.0:
		sim_events.append({"t": last_t + 2, "npc_id": "npc_king", "action": "flee", "target": "north", "dialogue": "Guardas! Protejam-me!", "particles": ["exclamation"], "sound": "horn"})
		last_t += 2
	sim_events.sort_custom(func(a, b): return float(a.t) < float(b.t))
	sim_time = 0.0
	sim_idx = 0
	sim_end = last_t + 5.0
	sim_running = true
	hud.toast("Fonte do roteiro: %s" % {"ia": "IA (backend)", "local": "modo offline", "fallback": "fallback genérico"}.get(Director.last_source, "?"), 3.0)


func _apply_world_changes(wc: Dictionary) -> void:
	if wc.get("water_poisoned", false):
		poisoned = true
	if wc.has("castle_damage"):
		castle_damage = clampi(int(wc.castle_damage), 0, 3)


func _finish_sim() -> void:
	sim_running = false
	phase = Phase.ENDED
	hud.set_sim(false)
	var before := Game.instability
	Game.add_instability(sim_delta)
	for id in npcs:
		if id != "npc_king":
			Game.bump(id, "anger", sim_delta * 0.3)
			Game.bump(id, "fear", sim_delta * 0.2)
	Sfx.play("tension")
	hud.toast("Instabilidade %+d%%" % int(round(Game.instability - before)), 2.5)
	await get_tree().create_timer(2.0).timeout
	if Game.instability >= 100.0:
		await _victory_sequence()
		victory.emit()
	elif Game.day >= Game.MAX_DAYS:
		await _defeat_sequence()
		defeat.emit()
	else:
		Game.day += 1
		_start_day()


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
	if held:
		held.position = held.position.lerp(mp + Vector2(0, -18), 0.35) if phase == Phase.ACTION else drop_pos
	# simulação
	if sim_running:
		sim_time += delta * float(Game.settings.sim_speed)
		while sim_idx < sim_events.size() and float(sim_events[sim_idx].t) <= sim_time:
			_dispatch(sim_events[sim_idx])
			sim_idx += 1
		clock = lerpf(8.0, 22.0, clampf(sim_time / maxf(sim_end, 1.0), 0.0, 1.0))
		if sim_idx >= sim_events.size() and sim_time >= sim_end:
			var idle := true
			for id in npcs:
				if npcs[id].moving:
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
	elif phase == Phase.ACTION:
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var k := Vector2.ZERO
		if Input.is_key_pressed(KEY_A): k.x -= 1
		if Input.is_key_pressed(KEY_D): k.x += 1
		if Input.is_key_pressed(KEY_W): k.y -= 1
		if Input.is_key_pressed(KEY_S): k.y += 1
		cam_target += (v + k).limit_length(1.0) * 420.0 * delta
	_update_cam(delta)
	# luz ambiente
	mod.color = _ambient()
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
