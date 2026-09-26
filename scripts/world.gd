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
var tufts: Array = []
var trees: Array = []
var fish: Array = []
var rings: Array = []
var lights: Array = []
var leaves: Array = []
var butterflies: Array = []
var clouds_bg: Array = []
var flowers: Array = []
var rocks: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 600:
		tufts.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(200, 960)))
	for i in 36:
		var p := Vector2(rng.randf_range(960, 1270), rng.randf_range(20, 320))
		trees.append({"p": p, "h": rng.randf_range(70, 110), "r": rng.randf_range(28, 45), "ph": rng.randf() * TAU, "type": rng.randi() % 3})
	for p in [Vector2(60, 560), Vector2(420, 560), Vector2(880, 600), Vector2(1150, 520), Vector2(40, 820), Vector2(400, 900), Vector2(1060, 860), Vector2(1200, 760), Vector2(330, 760), Vector2(920, 300),
			Vector2(180, 860), Vector2(260, 920), Vector2(500, 850), Vector2(1220, 900), Vector2(20, 380), Vector2(1260, 440)]:
		trees.append({"p": p, "h": rng.randf_range(65, 100), "r": rng.randf_range(25, 40), "ph": rng.randf() * TAU, "type": rng.randi() % 3})
	for i in 8:
		fish.append({"c": Vector2(700, 810) + Vector2(rng.randf_range(-120, 120), rng.randf_range(-50, 50)), "r": rng.randf_range(14, 45), "s": rng.randf_range(0.3, 0.9), "p": rng.randf() * TAU})
	for i in 30:
		leaves.append({"x": rng.randf_range(0, 1280), "y": rng.randf_range(-100, 960), "vx": rng.randf_range(-15, -5), "vy": rng.randf_range(8, 20), "rot": rng.randf() * TAU, "sz": rng.randf_range(2, 5), "col": rng.randi() % 3})
	for i in 8:
		butterflies.append({"x": rng.randf_range(100, 1100), "y": rng.randf_range(350, 800), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.8, 1.5), "r": rng.randf_range(30, 80), "cx": rng.randf_range(200, 1000), "cy": rng.randf_range(400, 700)})
	for i in 4:
		clouds_bg.append({"x": rng.randf_range(-200, 1400), "y": rng.randf_range(-40, 160), "w": rng.randf_range(100, 200), "sp": rng.randf_range(3, 8)})
	for i in 50:
		var fp := Vector2(rng.randf_range(10, 1270), rng.randf_range(220, 950))
		flowers.append({"p": fp, "col": [Color(1,0.3,0.3), Color(1,0.9,0.2), Color(0.9,0.5,0.9), Color(0.3,0.6,1)][rng.randi()%4], "sz": rng.randf_range(2,4)})
	for i in 30:
		rocks.append(Vector2(rng.randf_range(10, 1270), rng.randf_range(220, 950)))

	npc_root = Node2D.new()
	npc_root.y_sort_enabled = true
	obj_root = Node2D.new()
	fx_root = Node2D.new()
	add_child(obj_root)
	add_child(npc_root)
	add_child(fx_root)
	for id in Game.NPC_DEFS:
		var n := NPC.new()
		n.setup(id, Game.NPC_DEFS[id], self)
		npc_root.add_child(n)
		npcs[id] = n
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
		m.position = Vector2(960, 720)
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
	for lf in leaves:
		lf.x += float(lf.vx) * delta + sin(time * 2.0 + float(lf.rot)) * 8.0 * delta
		lf.y += float(lf.vy) * delta
		lf.rot = float(lf.rot) + delta * 2.0
		if float(lf.y) > 970.0:
			lf.y = -20.0
			lf.x = randf_range(0, 1280)
		if float(lf.x) < -20.0:
			lf.x = 1290.0
	shake = maxf(shake - delta * 14.0, 0.0)
	queue_redraw()


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


# ------------------------------------------------------------------ desenho do mapa
func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-700, -500, 2700, 2000), Color(0.08, 0.09, 0.12))
	draw_rect(Rect2(Vector2.ZERO, Game.MAP_SIZE), Color(0.32, 0.5, 0.2))
	draw_rect(Rect2(0, 0, 1280, 200), Color(0.28, 0.45, 0.18))
	draw_rect(Rect2(0, 700, 1280, 260), Color(0.35, 0.52, 0.22))
	for i in tufts.size():
		var tf: Vector2 = tufts[i]
		var sway := sin(time * 1.3 + tf.x * 0.05) * 1.8 * wind
		var h := 4.0 + sin(tf.x * 0.1 + tf.y * 0.07) * 2.0
		draw_line(tf, tf + Vector2(sway, -h), Color(0.42, 0.65, 0.35), 1.5)
		draw_line(tf + Vector2(2, 0), tf + Vector2(2 + sway * 0.8, -h + 1), Color(0.55, 0.7, 0.28), 1.0)
		if i % 5 == 0:
			draw_line(tf + Vector2(-1, 0), tf + Vector2(-1 + sway * 0.6, -h + 2), Color(0.48, 0.62, 0.3), 1.0)
	# estradas
	var dirt := Color(0.52, 0.38, 0.22)
	var dirt_dark := Color(0.45, 0.32, 0.18)
	draw_rect(Rect2(618, 200, 44, 270), dirt)
	draw_rect(Rect2(298, 446, 704, 30), dirt)
	draw_rect(Rect2(618, 472, 44, 490), dirt)
	draw_rect(Rect2(194, 498, 28, 214), dirt)
	draw_rect(Rect2(194, 698, 444, 28), dirt)
	draw_rect(Rect2(88, 446, 214, 30), dirt)
	draw_rect(Rect2(620, 202, 40, 266), dirt_dark)
	draw_rect(Rect2(300, 448, 700, 26), dirt_dark)
	draw_rect(Rect2(620, 474, 40, 486), dirt_dark)
	draw_rect(Rect2(196, 500, 24, 210), dirt_dark)
	draw_rect(Rect2(196, 700, 440, 24), dirt_dark)
	draw_rect(Rect2(90, 448, 210, 26), dirt_dark)
	for ri in 30:
		var rx := 300.0 + float(ri) * 24.0
		draw_circle(Vector2(rx, 461.0 + sin(float(ri) * 0.8) * 3.0), 2.0, Color(0.4, 0.3, 0.16, 0.3))
	# praça de pedra
	draw_rect(Rect2(540, 340, 200, 150), Color(0.478, 0.541, 0.604))
	for gx in range(540, 740, 20):
		draw_line(Vector2(gx, 340), Vector2(gx, 490), Color(0, 0, 0, 0.12), 1.0)
	for gy in range(340, 490, 20):
		draw_line(Vector2(540, gy), Vector2(740, gy), Color(0, 0, 0, 0.12), 1.0)
	# lago
	_draw_lake()
	# pedras
	for rk in rocks:
		var rv: Vector2 = rk
		draw_circle(rv, 3.5, Color(0.45, 0.42, 0.38))
		draw_circle(rv + Vector2(1, -1), 2, Color(0.52, 0.48, 0.44))
	# flores
	for fl in flowers:
		var fp: Vector2 = fl.p
		var fsz := float(fl.sz)
		var fc: Color = fl.col
		draw_circle(fp, fsz, fc)
		draw_circle(fp, fsz * 0.4, Color(1, 1, 0.6))
	# floresta e árvores
	var sorted_trees := trees.duplicate()
	sorted_trees.sort_custom(func(a, b): return float(a.p.y) < float(b.p.y))
	for td in sorted_trees:
		_draw_tree(td)
	# edifícios
	_draw_castle(font)
	_draw_house(Rect2(240, 380, 130, 90), Color(0.77, 0.66, 0.5), "PADARIA", font, Vector2(305, 470))
	_draw_house(Rect2(900, 380, 130, 90), Color(0.5, 0.52, 0.56), "FERRARIA", font, Vector2(965, 470))
	_draw_house(Rect2(140, 660, 150, 95), Color(0.9, 0.88, 0.8), "TEMPLO", font, Vector2(215, 755))
	_draw_house(Rect2(50, 370, 80, 70), Color(0.6, 0.48, 0.32), "", font, Vector2(90, 440))
	_draw_house(Rect2(390, 350, 85, 70), Color(0.55, 0.42, 0.28), "", font, Vector2(432, 420))
	_draw_house(Rect2(50, 510, 75, 65), Color(0.58, 0.45, 0.3), "", font, Vector2(87, 575))
	_draw_house(Rect2(1060, 380, 90, 75), Color(0.62, 0.5, 0.35), "", font, Vector2(1105, 455))
	_draw_house(Rect2(350, 660, 85, 65), Color(0.6, 0.5, 0.38), "", font, Vector2(392, 725))
	_draw_house(Rect2(1080, 520, 80, 65), Color(0.55, 0.45, 0.3), "", font, Vector2(1120, 585))
	_draw_interiors(font)
	_draw_plaza()
	# anéis de narrativa
	for r in rings:
		var a: float = 1.0 - r.age / 1.2
		var col := Color(1.0, 0.85, 0.3, a * 0.8) if not r.get("shout", false) else Color(1, 1, 1, a * 0.5)
		draw_arc(r.p, r.age * (160.0 if not r.get("shout", false) else 96.0), 0, TAU, 40, col, 3.0)
	if phase == Phase.TERMINAL or held:
		var hp := held.position if held else Vector2.ZERO
		if held:
			draw_arc(hp + Vector2(0, 18), 12, 0, TAU, 16, Color(1, 1, 1, 0.25), 1.0)
	# folhas caindo
	var leaf_cols := [Color(0.45, 0.65, 0.25, 0.7), Color(0.6, 0.5, 0.15, 0.7), Color(0.55, 0.35, 0.12, 0.7)]
	for lf in leaves:
		var lx := float(lf.x)
		var ly := float(lf.y)
		var lr := float(lf.rot)
		var lsz := float(lf.sz)
		var lc: Color = leaf_cols[int(lf.col) % 3]
		var pts := PackedVector2Array()
		for pi in 4:
			var ang := lr + float(pi) * PI / 2.0
			pts.append(Vector2(lx + cos(ang) * lsz, ly + sin(ang) * lsz * 0.6))
		draw_colored_polygon(pts, lc)
	# borboletas
	for bf in butterflies:
		var bx := float(bf.cx) + sin(time * float(bf.sp) + float(bf.ph)) * float(bf.r)
		var by := float(bf.cy) + cos(time * float(bf.sp) * 0.7 + float(bf.ph)) * float(bf.r) * 0.5 - 20.0
		var flap := maxf(absf(sin(time * 5.0 + float(bf.ph))), 0.15)
		var bcol := Color(0.9, 0.7, 0.2, 0.8)
		draw_circle(Vector2(bx, by), 1.5, Color(0.3, 0.2, 0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx - 5.0 * flap, by - 4.0), Vector2(bx - 3.0 * flap, by + 2.0)]), bcol)
		draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + 5.0 * flap, by - 4.0), Vector2(bx + 3.0 * flap, by + 2.0)]), bcol)


func _draw_lake() -> void:
	var c := Vector2(700, 810)
	var bank_col := Color(0.35, 0.28, 0.18)
	var bank := PackedVector2Array()
	for i in 60:
		var a := TAU * float(i) / 60.0
		var wobble := sin(a * 5.0 + 0.3) * 6.0 + sin(a * 3.0) * 4.0
		bank.append(c + Vector2(cos(a) * (220.0 + wobble), sin(a) * (105.0 + wobble * 0.5)))
	draw_colored_polygon(bank, bank_col)
	var mud := PackedVector2Array()
	for i in 60:
		var a := TAU * float(i) / 60.0
		var wobble := sin(a * 5.0 + 0.3) * 4.0
		mud.append(c + Vector2(cos(a) * (214.0 + wobble), sin(a) * (100.0 + wobble * 0.4)))
	draw_colored_polygon(mud, Color(0.3, 0.25, 0.15))
	var water_pts := PackedVector2Array()
	for i in 60:
		var a := TAU * float(i) / 60.0
		var wave := sin(time * 1.8 + a * 4.0) * 2.5
		water_pts.append(c + Vector2(cos(a) * (205.0 + wave), sin(a) * (94.0 + wave * 0.5)))
	draw_colored_polygon(water_pts, water_color.darkened(0.2))
	var inner := PackedVector2Array()
	for i in 60:
		var a := TAU * float(i) / 60.0
		var wave := sin(time * 2.0 + a * 3.0 + 1.0) * 2.0
		inner.append(c + Vector2(cos(a) * (195.0 + wave), sin(a) * (86.0 + wave * 0.4)))
	draw_colored_polygon(inner, water_color)
	var highlight := PackedVector2Array()
	for i in 60:
		var a := TAU * float(i) / 60.0
		highlight.append(c + Vector2(cos(a) * 160.0, sin(a) * 68.0) + Vector2(-20, -15))
	draw_colored_polygon(highlight, water_color.lightened(0.08))
	for i in 14:
		var wy := c.y - 70.0 + float(i) * 11.0
		var xo := sin(time * 1.2 + float(i) * 0.9) * 18.0
		var wa := 0.15 + 0.1 * sin(time * 2.0 + float(i))
		draw_line(Vector2(c.x - 100 + xo, wy), Vector2(c.x - 50 + xo, wy), Color(0.8, 0.92, 1.0, wa), 1.5)
		draw_line(Vector2(c.x + 20 - xo, wy + 4), Vector2(c.x + 80 - xo, wy + 4), Color(0.8, 0.92, 1.0, wa * 0.8), 1.5)
		if i % 3 == 0:
			draw_line(Vector2(c.x - 30 + xo * 0.5, wy + 2), Vector2(c.x + 10 + xo * 0.5, wy + 2), Color(0.85, 0.95, 1.0, wa * 0.6), 1.0)
	for i in 6:
		var sa := time * 0.8 + float(i) * 1.05
		var sp := c + Vector2(sin(sa) * 80.0, cos(sa * 0.7) * 35.0 - 10.0)
		var sparkle_a := maxf(0.0, sin(time * 3.0 + float(i) * 2.0)) * 0.7
		if sparkle_a > 0.1:
			draw_circle(sp, 2.0, Color(1, 1, 1, sparkle_a))
	for i in 8:
		var fa := time * 0.4 + float(i) * 0.8
		var foam_x := c.x + cos(fa * 1.3) * 180.0
		var foam_y := c.y + sin(fa * 1.3) * 80.0
		var foam_a := 0.2 + 0.15 * sin(time * 2.0 + float(i))
		draw_circle(Vector2(foam_x, foam_y), 3.0, Color(1, 1, 1, foam_a))
	for i in 4:
		var ra := fmod(time * 0.3 + float(i) * 1.5, 3.0)
		if ra < 2.5:
			var rp := c + Vector2(sin(float(i) * 2.1) * 80.0, cos(float(i) * 1.7) * 30.0)
			draw_arc(rp, ra * 12.0, 0, TAU, 24, Color(1, 1, 1, 0.15 * (1.0 - ra / 2.5)), 1.0)
	for i in 3:
		var lily_a := float(i) * 2.1 + 0.5
		var lp := c + Vector2(cos(lily_a) * 140.0, sin(lily_a) * 55.0)
		draw_circle(lp, 6.0, Color(0.15, 0.45, 0.2, 0.8))
		draw_circle(lp + Vector2(1, -1), 2.5, Color(1, 0.8, 0.85, 0.7))
	for f in fish:
		var a2 := time * float(f.s) + float(f.p)
		var fp: Vector2 = Vector2(f.c) + Vector2(cos(a2) * float(f.r) * 2.0, sin(a2) * float(f.r) * 0.6)
		if fish_dead:
			draw_circle(fp, 4.0, Color(0.85, 0.85, 0.8, 0.8))
			draw_circle(fp + Vector2(2, 0), 1.0, Color(0.2, 0.2, 0.2, 0.6))
		else:
			var dir := Vector2(-sin(a2), cos(a2) * 0.3).normalized()
			var fish_col := Color(1.0, 0.55, 0.2)
			draw_colored_polygon(PackedVector2Array([fp + dir * 3, fp + Vector2(-dir.y, dir.x) * 3, fp - dir * 8, fp + Vector2(dir.y, -dir.x) * 3]), fish_col)
			draw_colored_polygon(PackedVector2Array([fp - dir * 6, fp - dir * 12 + Vector2(-dir.y, dir.x) * 4, fp - dir * 12 + Vector2(dir.y, -dir.x) * 4]), fish_col.darkened(0.15))
			draw_circle(fp + dir * 1.5 + Vector2(-dir.y, dir.x) * 1.5, 1.0, Color(0.1, 0.1, 0.1))


func _draw_tree(td: Dictionary) -> void:
	var p: Vector2 = td.p
	var th := float(td.h)
	var tr2 := float(td.r)
	var tph := float(td.ph)
	var ttype := int(td.type)
	var sway := sin(time * 0.9 + tph) * 3.0 * wind
	var sway2 := sin(time * 1.3 + tph + 1.0) * 2.0 * wind
	var dark_trunk := Color(0.3, 0.18, 0.08)
	var light_trunk := Color(0.42, 0.26, 0.12)
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.3))
	draw_circle(p, tr2 * 0.5, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var trunk_w := tr2 * 0.18
	var trunk_pts := PackedVector2Array([
		p + Vector2(-trunk_w, 0), p + Vector2(-trunk_w * 0.7 + sway * 0.2, -th * 0.55),
		p + Vector2(trunk_w * 0.7 + sway * 0.2, -th * 0.55), p + Vector2(trunk_w, 0)])
	draw_colored_polygon(trunk_pts, dark_trunk)
	draw_line(p + Vector2(-trunk_w * 0.3, -th * 0.15), p + Vector2(-trunk_w * 0.3 + sway * 0.3, -th * 0.15 - 6), dark_trunk, 2.0)
	draw_line(p + Vector2(trunk_w * 0.5, -th * 0.25), p + Vector2(trunk_w * 0.8 + sway * 0.2, -th * 0.3), dark_trunk, 2.0)
	for i in 3:
		var bark_y := p.y - th * 0.1 * float(i + 1)
		draw_line(Vector2(p.x - trunk_w * 0.4, bark_y), Vector2(p.x + trunk_w * 0.2, bark_y + 2), light_trunk, 1.0)
	var canopy_center := p + Vector2(sway, -th * 0.65)
	var c_dark := Color(0.12, 0.32, 0.15)
	var c_mid := Color(0.18, 0.42, 0.22)
	var c_light := Color(0.28, 0.55, 0.28)
	var c_highlight := Color(0.38, 0.65, 0.35)
	if ttype == 1:
		c_dark = Color(0.15, 0.28, 0.12)
		c_mid = Color(0.22, 0.38, 0.18)
		c_light = Color(0.32, 0.5, 0.25)
		c_highlight = Color(0.42, 0.6, 0.3)
	elif ttype == 2:
		c_dark = Color(0.1, 0.35, 0.2)
		c_mid = Color(0.16, 0.45, 0.28)
		c_light = Color(0.24, 0.58, 0.35)
		c_highlight = Color(0.34, 0.68, 0.4)
	draw_circle(canopy_center + Vector2(0, tr2 * 0.3), tr2 * 0.95, c_dark)
	draw_circle(canopy_center + Vector2(-tr2 * 0.35 + sway2, -tr2 * 0.1), tr2 * 0.75, c_dark)
	draw_circle(canopy_center + Vector2(tr2 * 0.4 + sway2, -tr2 * 0.05), tr2 * 0.7, c_dark)
	draw_circle(canopy_center + Vector2(0, -tr2 * 0.15), tr2 * 0.85, c_mid)
	draw_circle(canopy_center + Vector2(-tr2 * 0.25 + sway2, -tr2 * 0.3), tr2 * 0.65, c_mid)
	draw_circle(canopy_center + Vector2(tr2 * 0.3 + sway2, -tr2 * 0.25), tr2 * 0.6, c_mid)
	draw_circle(canopy_center + Vector2(sway2 * 0.5, -tr2 * 0.35), tr2 * 0.55, c_light)
	draw_circle(canopy_center + Vector2(-tr2 * 0.15 + sway2, -tr2 * 0.45), tr2 * 0.4, c_light)
	draw_circle(canopy_center + Vector2(tr2 * 0.2 + sway2, -tr2 * 0.5), tr2 * 0.35, c_highlight)


func _draw_house(r: Rect2, floor_col: Color, label: String, font: Font, door: Vector2) -> void:
	var wall := Color(0.32, 0.2, 0.12)
	var shadow_off := Vector2(4, 4)
	draw_rect(Rect2(r.position + shadow_off, r.size), Color(0, 0, 0, 0.15))
	draw_rect(r, floor_col)
	for sy in range(int(r.position.y), int(r.position.y + r.size.y), 8):
		var soff := 6 if int((sy - int(r.position.y)) / 8.0) % 2 == 0 else 0
		for sx in range(int(r.position.x), int(r.position.x + r.size.x), 12):
			draw_line(Vector2(sx + soff, sy), Vector2(sx + soff, sy + 8), Color(0, 0, 0, 0.04), 1.0)
		draw_line(Vector2(r.position.x, sy), Vector2(r.position.x + r.size.x, sy), Color(0, 0, 0, 0.03), 1.0)
	draw_rect(r, wall, false, 3.0)
	var roof_pts := PackedVector2Array([
		Vector2(r.position.x - 8, r.position.y),
		Vector2(r.position.x + r.size.x / 2.0, r.position.y - r.size.y * 0.35),
		Vector2(r.position.x + r.size.x + 8, r.position.y)])
	draw_colored_polygon(roof_pts, Color(0.5, 0.2, 0.12))
	draw_line(roof_pts[0], roof_pts[1], Color(0.4, 0.15, 0.08), 2.0)
	draw_line(roof_pts[1], roof_pts[2], Color(0.4, 0.15, 0.08), 2.0)
	draw_rect(Rect2(door.x - 10, door.y - 4, 20, 8), Color(0.3, 0.18, 0.08))
	draw_rect(Rect2(door.x - 8, door.y - 2, 16, 5), Color(0.22, 0.12, 0.05))
	draw_circle(Vector2(door.x + 4, door.y), 1.5, Color(0.7, 0.6, 0.3))
	for wi in [0.25, 0.65]:
		if r.size.x > 80 or wi < 0.5:
			var wx := r.position.x + r.size.x * float(wi)
			var wy := r.position.y + r.size.y * 0.35
			draw_rect(Rect2(wx - 6, wy, 12, 14), Color(0.22, 0.15, 0.08))
			var glow := 0.4 + 0.2 * sin(time * 2.5 + wx)
			draw_rect(Rect2(wx - 4, wy + 2, 8, 10), Color(1.0, 0.75, 0.3, glow))
			draw_line(Vector2(wx, wy + 2), Vector2(wx, wy + 12), Color(0.22, 0.15, 0.08, 0.6), 1.0)
			draw_line(Vector2(wx - 4, wy + 7), Vector2(wx + 4, wy + 7), Color(0.22, 0.15, 0.08, 0.6), 1.0)
	var ch := Vector2(r.position.x + r.size.x - 18, r.position.y - r.size.y * 0.15)
	draw_rect(Rect2(ch.x - 5, ch.y - 14, 10, 20), Color(0.4, 0.38, 0.42))
	draw_rect(Rect2(ch.x - 7, ch.y - 16, 14, 4), Color(0.45, 0.42, 0.46))
	for i in 5:
		var f := fmod(time * 0.35 + float(i) * 0.22, 1.2)
		var sx := ch.x + sin(f * 5.0 + float(i)) * 5.0 + wind * f * 10.0
		var sy := ch.y - 18.0 - f * 40.0
		var sr := 2.5 + f * 3.5
		draw_circle(Vector2(sx, sy), sr, Color(0.7, 0.7, 0.75, 0.45 * maxf(0.0, 1.0 - f / 1.2)))
	if label != "":
		var sign_w := label.length() * 7.0 + 16.0
		var sign_x := r.position.x + r.size.x / 2.0 - sign_w / 2.0
		var sign_y := r.position.y - r.size.y * 0.35 - 18.0
		draw_rect(Rect2(sign_x, sign_y, sign_w, 16), Color(0.6, 0.45, 0.25))
		draw_rect(Rect2(sign_x, sign_y, sign_w, 16), Color(0.4, 0.25, 0.1), false, 1.5)
		draw_string(font, Vector2(sign_x, sign_y + 13), label, HORIZONTAL_ALIGNMENT_CENTER, sign_w, 11, Color(0.95, 0.9, 0.8))


func _draw_interiors(_font: Font) -> void:
	# padaria: mesa, forno, vitrine
	draw_rect(Rect2(250, 395, 40, 18), Color(0.63, 0.38, 0.16))
	draw_rect(Rect2(320, 392, 30, 22), Color(0.25, 0.22, 0.22))
	draw_rect(Rect2(324, 398, 22, 10), Color(1.0, 0.5, 0.15, 0.6 + 0.3 * sin(time * 8.0)))
	# ferraria: bigorna + forja
	draw_rect(Rect2(915, 420, 28, 10), Color(0.25, 0.27, 0.3))
	draw_rect(Rect2(985, 392, 26, 26), Color(0.2, 0.18, 0.18))
	var fl := 0.6 + 0.4 * sin(time * 12.0)
	draw_circle(Vector2(998, 405), 6.0 + fl * 2.0, Color(1.0, 0.55, 0.15, 0.85))
	if fmod(time, 0.7) < 0.1:
		draw_circle(Vector2(929, 414), 3.0, Color(1.0, 0.8, 0.3))
	# templo: altar e velas
	draw_rect(Rect2(190, 675, 40, 14), Color(0.75, 0.75, 0.8))
	for cx in [196, 222]:
		draw_rect(Rect2(cx, 668, 3, 8), Color(1, 1, 0.9))
		draw_circle(Vector2(cx + 1.5, 665), 2.5 + sin(time * 10.0 + cx) * 0.7, Color(1.0, 0.8, 0.3))


func _draw_castle(font: Font) -> void:
	var wall := Color(0.45, 0.5, 0.56)
	var wall_dark := Color(0.35, 0.4, 0.46)
	var _wall_light := Color(0.52, 0.57, 0.63)
	var stone_line := Color(0, 0, 0, 0.08)
	draw_rect(Rect2(480, -40, 320, 240), wall)
	for gy in range(-40, 200, 12):
		var offset := 10 if int(gy / 12.0) % 2 == 0 else 0
		for gx in range(480, 800, 20):
			draw_line(Vector2(gx + offset, gy), Vector2(gx + offset, gy + 12), stone_line, 1.0)
		draw_line(Vector2(480, gy), Vector2(800, gy), stone_line, 1.0)
	draw_rect(Rect2(460, -90, 50, 290), wall)
	draw_rect(Rect2(770, -90, 50, 290), wall)
	draw_rect(Rect2(590, -70, 100, 70), wall)
	for i in 5:
		draw_rect(Rect2(462 + float(i) * 10, -100, 6, 12), wall_dark)
	for i in 5:
		draw_rect(Rect2(772 + float(i) * 10, -100, 6, 12), wall_dark)
	for i in 10:
		draw_rect(Rect2(592 + float(i) * 10, -78, 6, 10), wall_dark)
	for i in 16:
		draw_rect(Rect2(480 + i * 20, -48 if i % 2 == 0 else -40, 14, 10), wall_dark)
	_draw_tower_roof_world(Vector2(460, -90), 50.0, 50.0)
	_draw_tower_roof_world(Vector2(770, -90), 50.0, 50.0)
	_draw_tower_roof_world(Vector2(600, -70), 80.0, 45.0)
	draw_rect(Rect2(500, 20, 280, 160), Color(0.3, 0.2, 0.22))
	draw_rect(Rect2(615, 18, 50, 164), Color(0.5, 0.1, 0.14))
	var carpet_stripe := Color(0.65, 0.5, 0.15)
	draw_rect(Rect2(615, 18, 2, 164), carpet_stripe)
	draw_rect(Rect2(663, 18, 2, 164), carpet_stripe)
	draw_rect(Rect2(618, 60, 44, 42), Color(0.82, 0.68, 0.18))
	draw_rect(Rect2(622, 64, 36, 34), Color(0.48, 0.08, 0.38))
	draw_rect(Rect2(618, 55, 44, 8), Color(0.85, 0.72, 0.2))
	for i in 3:
		draw_rect(Rect2(626 + float(i) * 10, 50, 6, 7), Color(0.85, 0.72, 0.2))
	draw_circle(Vector2(640, 57), 3, Color(0.9, 0.2, 0.2))
	draw_circle(Vector2(630, 57), 2, Color(0.2, 0.5, 0.9))
	draw_circle(Vector2(650, 57), 2, Color(0.2, 0.8, 0.3))
	for tx in [520, 570, 710, 760]:
		draw_rect(Rect2(tx - 2, 50, 4, 16), Color(0.4, 0.25, 0.1))
		var ff := 5.0 + sin(time * 10.0 + float(tx)) * 2.0
		draw_circle(Vector2(tx, 46 - sin(time * 12.0 + float(tx)) * 1.5), ff, Color(1.0, 0.55, 0.1, 0.85))
		draw_circle(Vector2(tx, 44), 3.0, Color(1.0, 0.9, 0.4, 0.7))
		draw_circle(Vector2(tx, 46), ff + 6.0, Color(1.0, 0.5, 0.1, 0.08))
	for wx in [510, 550, 720, 760]:
		draw_rect(Rect2(wx - 6, 30, 12, 16), wall_dark)
		draw_rect(Rect2(wx - 4, 32, 8, 12), Color(0.15, 0.2, 0.35, 0.7))
	for wx2 in [475, 505, 780, 795]:
		draw_rect(Rect2(wx2 - 4, -50, 8, 12), wall_dark)
		draw_rect(Rect2(wx2 - 2, -48, 4, 8), Color(0.15, 0.2, 0.35, 0.5))
	var open := gate_open
	draw_rect(Rect2(610, 164, 60, 36), Color(0.22, 0.14, 0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(610, 164), Vector2(640, 148), Vector2(670, 164)]), Color(0.22, 0.14, 0.06))
	if open < 0.95:
		for gi in 5:
			var gy := 164.0 + float(gi) * 7.0
			draw_rect(Rect2(612 + 28 * open, gy, 56 - 56 * open, 3), Color(0.35, 0.22, 0.1))
	var fy := -120.0 + 300.0 * flag_drop
	draw_line(Vector2(640, fy), Vector2(640, fy + 50), Color(0.3, 0.2, 0.1), 3.0)
	var wave := sin(time * 4.5) * 5.0
	draw_colored_polygon(PackedVector2Array([Vector2(642, fy), Vector2(678 + wave, fy + 5), Vector2(675 - wave, fy + 15), Vector2(642, fy + 20)]), Color(0.42, 0.17, 0.57))
	draw_colored_polygon(PackedVector2Array([Vector2(650 + wave * 0.5, fy + 6), Vector2(660 + wave * 0.5, fy + 6), Vector2(660 + wave * 0.5, fy + 14), Vector2(650 + wave * 0.5, fy + 14)]), Color(0.85, 0.7, 0.2, 0.7))
	if flag_drop > 0.9:
		draw_colored_polygon(PackedVector2Array([Vector2(642, 40), Vector2(678 + wave, 45), Vector2(675 - wave, 55), Vector2(642, 60)]), Color(0.3, 0.7, 0.35))
	if castle_damage > 0:
		for i in castle_damage * 4:
			var cx := 500.0 + float(i) * 35.0
			draw_line(Vector2(cx, 5), Vector2(cx + 8, 35 + float(i) * 6), Color(0.15, 0.12, 0.1, 0.7), 2.0)
			draw_line(Vector2(cx + 4, 15), Vector2(cx - 6, 45 + float(i) * 4), Color(0.15, 0.12, 0.1, 0.5), 1.5)
	for bx in [520, 615, 665, 760]:
		var ba := time * 0.6 + float(bx) * 0.1
		var bsway := sin(ba * 3.0) * 3.0
		draw_rect(Rect2(bx - 8, -35, 16, 30), Color(0.42, 0.17, 0.57, 0.8))
		draw_line(Vector2(bx - 8, -35 + bsway * 0.3), Vector2(bx + 8, -35 - bsway * 0.3), Color(0.42, 0.17, 0.57, 0.6), 1.0)
	draw_string(font, Vector2(540, 196), "CASTELO REAL", HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(1, 1, 1, 0.6))


func _draw_tower_roof_world(base: Vector2, w: float, h: float) -> void:
	var col := Color(0.35, 0.15, 0.12)
	draw_colored_polygon(PackedVector2Array([Vector2(base.x - 5, base.y), Vector2(base.x + w / 2.0, base.y - h), Vector2(base.x + w + 5, base.y)]), col)


func _draw_plaza() -> void:
	# fonte
	var f := Vector2(640, 400)
	draw_circle(f, 26.0, Color(0.55, 0.6, 0.66))
	draw_circle(f, 21.0, water_color.lightened(0.1) if not poisoned else water_color)
	for i in 5:
		var a := time * 2.0 + i * 1.26
		var h := fmod(time * 1.2 + i * 0.2, 1.0)
		draw_circle(f + Vector2(cos(a) * 6.0 * h, -14.0 * sin(h * PI)), 1.8, Color(0.8, 0.92, 1.0, 0.9))
	draw_rect(Rect2(f.x - 3, f.y - 12, 6, 12), Color(0.6, 0.65, 0.7))
	# poço
	var w := Vector2(555, 415)
	draw_circle(w, 13.0, Color(0.42, 0.44, 0.48))
	draw_circle(w, 9.0, water_color.darkened(0.5))
	draw_rect(Rect2(w.x - 14, w.y - 24, 3, 20), Color(0.42, 0.25, 0.1))
	draw_rect(Rect2(w.x + 11, w.y - 24, 3, 20), Color(0.42, 0.25, 0.1))
	draw_line(Vector2(w.x - 14, w.y - 24), Vector2(w.x + 14, w.y - 24), Color(0.42, 0.25, 0.1), 3.0)
	draw_rect(Rect2(w.x - 2, w.y - 20 + sin(time * 2.0) * 2.0, 5, 6), Color(0.5, 0.35, 0.15))
	# poste de decretos
	var nb := Vector2(725, 375)
	draw_rect(Rect2(nb.x - 2, nb.y - 26, 4, 28), Color(0.42, 0.25, 0.1))
	draw_rect(Rect2(nb.x - 14, nb.y - 34, 28, 16), Color(0.85, 0.8, 0.65))
	# tocha da praça
	var tp := Vector2(600, 350)
	draw_rect(Rect2(tp.x - 2, tp.y - 22, 4, 24), Color(0.35, 0.22, 0.1))
	if torch_on:
		draw_circle(tp + Vector2(0, -26 - sin(time * 12.0)), 6.0, Color(1.0, 0.6, 0.15, 0.95))
		draw_circle(tp + Vector2(0, -28), 3.0, Color(1.0, 0.9, 0.4))
	# banca do mercador
	if Game.day < 3:
		draw_rect(Rect2(680, 440, 50, 22), Color(0.75, 0.3, 0.25))
		draw_rect(Rect2(680, 432, 50, 10), Color(0.95, 0.9, 0.8))
