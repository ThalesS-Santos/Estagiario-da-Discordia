class_name Village
extends Node2D
## Cenário da aldeia montado a partir dos assets gerados (assets/gen/map.json + PNGs).
## O World e o menu usam a mesma aldeia; o estado visual (água, portão, bandeiras...) é controlado por fora.

const GEN := "res://assets/gen/"
const PX := 2.0
const WATER_BASE := Color(0.16, 0.42, 0.69)

var data: Dictionary = {}
var meta: Dictionary = {}
var _tex_cache: Dictionary = {}

var ysort: Node2D
var fx_top: Node2D
var lake_water: AnimSprite
var lake_sparkle: AnimSprite
var fountain_layers: Array = []
var gate: AnimSprite
var cracks: Array = []
var royal_flags: Array = []
var rebel_flags: Array = []
var flag_tops: Array = []
var torch_flames: Array = []
var lights: Array = []
var fish: Array = []
var leaves: Array = []
var butterflies: Array = []
var chickens: Array = []

var time := 0.0
var water_color := WATER_BASE
var fish_dead := false
var gate_open := 0.0
var flag_drop := 0.0
var castle_damage := 0
var torch_on := true
var wind := 1.0
var night := 0.0
var map_rect := Rect2(0, 0, 1280, 960)


func _init() -> void:
	var f := FileAccess.open(GEN + "map.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
			meta = data.get("meta", {})


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()


# ------------------------------------------------------------------ fábrica de sprites
func tex(key: String) -> Texture2D:
	if not _tex_cache.has(key):
		_tex_cache[key] = load(GEN + key + ".png")
	return _tex_cache[key]


func make(key: String, pos: Vector2, opts: Dictionary = {}) -> AnimSprite:
	var m: Dictionary = meta.get(key, {})
	var s := AnimSprite.new()
	s.texture = tex(key)
	s.hframes = int(m.get("hframes", 1))
	s.vframes = int(m.get("vframes", 1))
	s.centered = false
	var o: Array = opts.get("origin", m.get("origin", [0, 0]))
	var fw := float(s.texture.get_width()) / float(s.hframes)
	var ox := float(o[0])
	if bool(opts.get("flip", false)):
		s.flip_h = true
		ox = fw - ox
	s.offset = -Vector2(ox, float(o[1]))
	s.scale = Vector2(PX, PX)
	s.position = pos
	s.fps = float(opts.get("fps", m.get("fps", 0.0)))
	s.phase = float(opts.get("phase", randf()))
	s.row = int(opts.get("row", 0))
	return s


func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ------------------------------------------------------------------ montagem
func _build() -> void:
	var ground := Sprite2D.new()
	ground.texture = tex("terrain/ground")
	ground.centered = false
	ground.scale = Vector2(PX, PX)
	ground.z_index = -20
	add_child(ground)
	# fora do mapa: faixa escura
	var outside := ColorRect.new()
	outside.color = Color(0.09, 0.2, 0.13)
	outside.position = Vector2(-800, -600)
	outside.size = Vector2(2880, 2160)
	outside.z_index = -30
	outside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outside)

	_build_lake()
	_build_castle()

	var decor := Node2D.new()
	decor.z_index = -5
	add_child(decor)
	for d in data.get("decor", []):
		decor.add_child(make(str(d.s), _v(d.p), {"phase": float(d.get("phase", 0.0)), "row": int(d.get("row", 0))}))

	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	for d in data.get("placed", []):
		var pos := _v(d.p)
		if d.has("layers"):
			var holder := Node2D.new()
			holder.position = pos
			for l in d.layers:
				var sp := make(str(l), Vector2.ZERO)
				holder.add_child(sp)
				if str(l) != "props/fountain_base":
					fountain_layers.append(sp)
			ysort.add_child(holder)
		else:
			ysort.add_child(make(str(d.s), pos, {"phase": float(d.get("phase", randf())), "flip": bool(d.get("flip", false))}))
	var castle: Dictionary = data.get("castle", {})
	ysort.add_child(make("buildings/throne", _v(castle.get("throne", [640, 80]))))

	fx_top = Node2D.new()
	fx_top.z_index = 5
	add_child(fx_top)
	var anchors: Dictionary = data.get("anchors", {})
	for p in anchors.get("smoke", []):
		fx_top.add_child(make("props/smoke", _v(p), {"phase": randf()}))
	for fl in anchors.get("flames", []):
		var small := bool(fl.get("small", false))
		var base_y := float(fl.base)
		var fp := _v(fl.p)
		var holder := Node2D.new()
		holder.position = Vector2(fp.x, base_y)
		var flame := make("props/flame_small" if small else "props/flame", Vector2(0, fp.y - base_y))
		holder.add_child(flame)
		ysort.add_child(holder)
		_add_light(Vector2(fp.x, fp.y - 4), 0.6 if small else 1.0)
		if str(fl.kind) == "torch":
			torch_flames.append(holder)
	for p in anchors.get("chickens", []):
		var ch := make("props/chicken", _v(p), {"fps": 0.0, "row": randi() % 2})
		ysort.add_child(ch)
		chickens.append({"n": ch, "home": _v(p), "t": randf() * 3.0, "state": 0, "target": _v(p)})
	_build_ambient()


func _add_light(pos: Vector2, strength: float) -> void:
	var l := PointLight2D.new()
	l.texture = tex("props/glow")
	l.position = pos
	l.color = Color(1.0, 0.62, 0.25)
	l.texture_scale = 2.4 * strength + 0.6
	l.energy = 0.0
	l.set_meta("strength", strength)
	add_child(l)
	lights.append(l)


func _build_lake() -> void:
	var lk: Dictionary = data.get("lake", {})
	var lp := _v(lk.get("pos", [0, 0]))
	var shore := Sprite2D.new()
	shore.texture = tex("terrain/lake_shore")
	shore.centered = false
	shore.scale = Vector2(PX, PX)
	shore.position = lp
	shore.z_index = -15
	add_child(shore)
	var lm: Dictionary = meta.get("terrain/lake", {})
	var nf := int(lm.get("hframes", 8))
	for i in 2:
		var s := AnimSprite.new()
		s.texture = tex("terrain/lake_water" if i == 0 else "terrain/lake_sparkle")
		s.hframes = nf
		s.centered = false
		s.scale = Vector2(PX, PX)
		s.position = lp
		s.fps = float(lm.get("fps", 5.0))
		s.z_index = -14 + i * 2
		add_child(s)
		if i == 0:
			lake_water = s
		else:
			lake_sparkle = s
	var anchors: Dictionary = data.get("anchors", {})
	for f in anchors.get("fish", []):
		var n := make("props/fish", _v(f.c), {"fps": 0.0})
		n.z_index = -13
		n.modulate = Color(1, 1, 1, 0.8)
		add_child(n)
		fish.append({"n": n, "c": _v(f.c), "r": float(f.r), "s": float(f.s), "p": float(f.p)})
	for l in anchors.get("lilies", []):
		var n := make("props/lily", Vector2(float(l[0]), float(l[1])), {"phase": float(l[2])})
		n.z_index = -11
		add_child(n)


func _build_castle() -> void:
	var c: Dictionary = data.get("castle", {})
	var root := Node2D.new()
	root.z_index = -8
	add_child(root)
	var base := Sprite2D.new()
	base.texture = tex("buildings/castle")
	base.centered = false
	base.scale = Vector2(PX, PX)
	base.position = _v(c.get("pos", [448, 0]))
	root.add_child(base)
	for lv in [1, 2, 3]:
		var cr := Sprite2D.new()
		cr.texture = tex("buildings/castle_cracks_%d" % lv)
		cr.centered = false
		cr.scale = Vector2(PX, PX)
		cr.position = base.position
		cr.visible = false
		root.add_child(cr)
		cracks.append(cr)
	gate = make("buildings/castle_gate", _v(c.get("gate", [640, 224])), {"fps": 0.0})
	root.add_child(gate)
	for b in c.get("banners", []):
		root.add_child(make("props/banner", _v(b)))
	for wt in c.get("wall_torches", []):
		var p := _v(wt)
		root.add_child(make("props/wall_torch", p))
		root.add_child(make("props/flame_small", p + Vector2(0, -16)))
		_add_light(p + Vector2(0, -20), 0.7)
	for fp in c.get("flags", []):
		var p := _v(fp)
		root.add_child(make("props/flagpole", p))
		var top := p + Vector2(2, -74)
		flag_tops.append(top)
		var rf := make("props/flag_royal", top, {"phase": randf()})
		root.add_child(rf)
		royal_flags.append(rf)
		var gf := make("props/flag_rebel", top, {"phase": randf()})
		gf.visible = false
		root.add_child(gf)
		rebel_flags.append(gf)


func _build_ambient() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 28:
		var lf := make("props/leaf", Vector2(rng.randf_range(0, 1280), rng.randf_range(-100, 960)),
				{"row": rng.randi() % 4, "phase": rng.randf()})
		lf.fps = rng.randf_range(3.0, 7.0)
		fx_top.add_child(lf)
		leaves.append({"n": lf, "vx": rng.randf_range(-18, -6), "vy": rng.randf_range(10, 24), "w": rng.randf() * TAU})
	for i in 12:
		var c := Vector2(rng.randf_range(80, 1200), rng.randf_range(300, 900))
		var bf := make("props/butterfly", c, {"row": rng.randi() % 4, "phase": rng.randf()})
		fx_top.add_child(bf)
		butterflies.append({"n": bf, "c": c, "r": rng.randf_range(30, 80), "sp": rng.randf_range(0.5, 1.2), "ph": rng.randf() * TAU})


# ------------------------------------------------------------------ animação por frame
func _process(delta: float) -> void:
	time += delta
	var wc := Color(minf(water_color.r * 1.25, 1.0), minf(water_color.g * 1.25, 1.0), minf(water_color.b * 1.25, 1.0))
	if lake_water:
		lake_water.modulate = wc
	for l in fountain_layers:
		l.modulate = wc
	for i in cracks.size():
		cracks[i].visible = castle_damage == i + 1
	if gate:
		gate.frame = 1 if gate_open > 0.5 else 0
	for i in royal_flags.size():
		var top: Vector2 = flag_tops[i]
		royal_flags[i].position = top + Vector2(0, 52.0 * flag_drop)
		royal_flags[i].visible = flag_drop < 0.98
		rebel_flags[i].visible = flag_drop >= 0.98
	for h in torch_flames:
		h.visible = torch_on
	for l in lights:
		l.energy = night * 1.1 * float(l.get_meta("strength"))
	for f in fish:
		var n: AnimSprite = f.n
		if fish_dead:
			n.frame = 2
			n.position = n.position.lerp(Vector2(f.c) + Vector2(0, -6), delta * 0.5)
			n.flip_h = false
			continue
		var a: float = time * float(f.s) + float(f.p)
		var np := Vector2(f.c) + Vector2(cos(a) * float(f.r) * 1.8, sin(a) * float(f.r) * 0.5)
		n.flip_h = np.x > n.position.x
		n.position = np
		n.frame = int(time * 5.0 + float(f.p)) % 2
	for lf in leaves:
		var n: AnimSprite = lf.n
		n.position.x += (float(lf.vx) * wind + sin(time * 1.7 + float(lf.w)) * 14.0) * delta
		n.position.y += float(lf.vy) * delta
		if n.position.y > 980.0:
			n.position = Vector2(randf_range(0, 1400), -30.0)
		if n.position.x < -30.0:
			n.position.x = 1300.0
	for bf in butterflies:
		var n: AnimSprite = bf.n
		var a: float = time * float(bf.sp) + float(bf.ph)
		var np := Vector2(bf.c) + Vector2(sin(a) * float(bf.r), cos(a * 0.7) * float(bf.r) * 0.5 + sin(a * 3.1) * 6.0)
		n.flip_h = np.x < n.position.x
		n.position = np
		n.visible = night < 0.5
	for ch in chickens:
		_chicken(ch, delta)


func _chicken(ch: Dictionary, delta: float) -> void:
	var n: AnimSprite = ch.n
	ch.t = float(ch.t) - delta
	var state := int(ch.state)
	if state == 2:
		var to: Vector2 = Vector2(ch.target) - n.position
		if to.length() < 2.0:
			ch.state = 0
		else:
			n.position += to.normalized() * 28.0 * delta
			n.flip_h = to.x > 0
			n.frame = n.row * 4 + (3 if int(time * 8.0) % 2 == 0 else 0)
	elif state == 1:
		n.frame = n.row * 4 + 1 + int(time * 6.0) % 2
	else:
		n.frame = n.row * 4
	if float(ch.t) <= 0.0:
		ch.t = randf_range(1.0, 3.5)
		var r := randf()
		if r < 0.4:
			ch.state = 1
		elif r < 0.8:
			ch.state = 2
			ch.target = Vector2(ch.home) + Vector2(randf_range(-50, 50), randf_range(-24, 24))
		else:
			ch.state = 0


func in_lake(p: Vector2, margin := 0.0) -> bool:
	var lk: Dictionary = data.get("lake", {})
	if lk.is_empty():
		return false
	var c := _v(lk.center)
	var rx := float(lk.rx) + margin
	var ry := float(lk.ry) + margin
	return pow((p.x - c.x) / rx, 2.0) + pow((p.y - c.y) / ry, 2.0) < 1.0


func location(key: String) -> Vector2:
	var locs: Dictionary = data.get("locations", {})
	return _v(locs[key]) if locs.has(key) else Vector2.ZERO
