class_name MenuVillage
extends Node2D
## Fundo do menu: a aldeia em pixel art à noite, com câmera passeando, moradores e vagalumes.
## Também serve de "world" mínimo para os NPCs (phase/time/show_names/village/emit_particle).

var village: Village
var cam: Camera2D
var phase := 0
var time := 0.0
var show_names := false
var fireflies: Array = []


func _ready() -> void:
	village = Village.new()
	add_child(village)
	village.night = 0.9
	var mod := CanvasModulate.new()
	mod.color = Color(0.26, 0.29, 0.52)
	add_child(mod)
	for id in ["npc_guard", "npc_baker", "npc_smith", "npc_orphan", "npc_priestess", "npc_king"]:
		var n := NPC.new()
		n.setup(id, Game.NPC_DEFS[id], self)
		village.ysort.add_child(n)
	var vdata: Dictionary = village.data.get("villagers", {})
	for vid in vdata:
		var p: Array = vdata[vid]
		var n := NPC.new()
		n.setup(vid, {"name": "", "size": Vector2(28, 44), "home_pos": Vector2(float(p[0]), float(p[1])), "decor": true}, self)
		village.ysort.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		var c := Vector2(rng.randf_range(0, 1280), rng.randf_range(160, 900))
		var f := village.make("props/firefly", c, {"phase": rng.randf()})
		f.z_index = 6
		add_child(f)
		fireflies.append({"n": f, "c": c, "r": rng.randf_range(10, 40), "sp": rng.randf_range(0.3, 0.8), "ph": rng.randf() * TAU})
	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.position = Vector2(640, 250)
	add_child(cam)
	cam.make_current()


func _process(delta: float) -> void:
	time += delta
	cam.position = Vector2(640.0 + sin(time * 0.06) * 200.0, 250.0 + sin(time * 0.045) * 60.0)
	for f in fireflies:
		var a: float = time * float(f.sp) + float(f.ph)
		f.n.position = Vector2(f.c) + Vector2(sin(a) * float(f.r), cos(a * 1.3) * float(f.r) * 0.6)


func emit_particle(_kind: String, _pos: Vector2) -> void:
	pass
