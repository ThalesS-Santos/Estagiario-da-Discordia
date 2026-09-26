class_name NPC
extends Node2D
## NPC com spritesheet pixel art (baixo/cima/lado x 4 frames), sombra, balão de fala e emotes.

signal arrived

const GEN := "res://assets/gen/"
const EMOTES := {"!": 0, "?": 1, "<3": 2, "* *": 3, "...": 4, "zz": 5}

var id := ""
var def: Dictionary = {}
var world
var home := Vector2.ZERO
var target := Vector2.ZERO
var moving := false
var running := false
var fallen := false
var ambient := true
var decor := false
var t := 0.0
var facing := 1.0
var dir := 0
var bubble := ""
var bubble_t := 0.0
var emote := ""
var emote_t := 0.0
var last_active := -100.0
var mood_anger := 0.0
var mood_fear := 0.0
var carrying = null
var wander_t := 2.0
var patrol: Array = []
var patrol_i := 0
var dust_t := 0.0

var body: Sprite2D
var shadow: Sprite2D
var ui: NpcUI
var _bubble_box: StyleBoxTexture
var _tail: Texture2D
var _emotes: Texture2D


func setup(npc_id: String, d: Dictionary, w) -> void:
	id = npc_id
	def = d
	world = w
	decor = bool(d.get("decor", false))
	if d.has("home_pos"):
		home = d.home_pos
	else:
		home = Game.loc_pos(d.home)
	if id == "npc_king":
		home = Game.loc_pos("throne") + Vector2(0, 6)
	position = home
	target = home
	t = randf() * 10.0
	wander_t = randf_range(0.5, 4.0)
	if id == "npc_guard":
		patrol = [Game.loc_pos("castle_gate") + Vector2(0, 14), Game.loc_pos("fountain") + Vector2(-60, 50), Game.loc_pos("well") + Vector2(0, 34)]
	_build_sprites()


func _build_sprites() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow = Sprite2D.new()
	shadow.texture = load(GEN + "chars/shadow.png")
	shadow.scale = Vector2(2, 2)
	shadow.position = Vector2(0, 0)
	add_child(shadow)
	body = Sprite2D.new()
	body.texture = load(GEN + "chars/%s.png" % id)
	body.hframes = 4
	body.vframes = 3
	body.centered = false
	body.offset = Vector2(-8, -23)
	body.scale = Vector2(2, 2)
	add_child(body)
	_bubble_box = StyleBoxTexture.new()
	_bubble_box.texture = load(GEN + "props/bubble.png")
	_bubble_box.set_texture_margin_all(4)
	_bubble_box.set_content_margin_all(6)
	_tail = load(GEN + "props/bubble_tail.png")
	_emotes = load(GEN + "props/emotes.png")
	ui = NpcUI.new()
	ui.npc = self
	ui.z_index = 10
	add_child(ui)


class NpcUI extends Node2D:
	var npc

	func _draw() -> void:
		npc.draw_ui(self)


func walk_to(p: Vector2, run := false) -> void:
	if fallen:
		return
	target = p
	moving = true
	running = run
	last_active = world.time if world else 0.0
	if absf(p.x - position.x) > 2.0:
		facing = signf(p.x - position.x)


func say(text: String, dur := 3.5) -> void:
	bubble = text
	bubble_t = dur
	last_active = world.time if world else 0.0


func show_emote(sym: String, dur := 1.6) -> void:
	emote = sym
	emote_t = dur


func fall() -> void:
	if fallen:
		return
	fallen = true
	moving = false
	show_emote("* *", 6.0)
	last_active = world.time if world else 0.0


func get_up() -> void:
	fallen = false
	emote = ""


func hurt_mood(anger: float, fear: float) -> void:
	mood_anger = clampf(mood_anger + anger, 0.0, 1.0)
	mood_fear = clampf(mood_fear + fear, 0.0, 1.0)


func _in_water(p: Vector2) -> bool:
	return world != null and world.village != null and world.village.in_lake(p, 26.0)


func _pick_wander() -> Vector2:
	if id == "npc_orphan":
		return home + Vector2(randf_range(-110, 110), randf_range(-50, 8))
	if decor:
		return home + Vector2(randf_range(-70, 70), randf_range(-34, 34))
	return home + Vector2(randf_range(-28, 28), randf_range(-14, 14))


func _process(delta: float) -> void:
	var sp := 1.0 if world == null or world.phase != 2 else float(Game.settings.sim_speed)
	t += delta
	bubble_t = maxf(bubble_t - delta, 0.0)
	emote_t = maxf(emote_t - delta, 0.0)
	mood_anger = maxf(mood_anger - delta * 0.05, 0.0)
	mood_fear = maxf(mood_fear - delta * 0.05, 0.0)
	var vel := Vector2.ZERO
	if moving and not fallen:
		var to := target - position
		var step := (110.0 if running else 55.0) * delta * sp
		if to.length() <= step + 1.0:
			position = target
			moving = false
			arrived.emit()
		else:
			vel = to.normalized()
			position += vel * step
		if running and world:
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.18
				world.emit_particle("dust_small", global_position + Vector2(0, 2))
	elif ambient and not fallen and id != "npc_king":
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = randf_range(3.0, 7.0)
			if id == "npc_guard" and not patrol.is_empty():
				patrol_i = (patrol_i + 1) % patrol.size()
				walk_to(patrol[patrol_i])
			else:
				var dest := _pick_wander()
				if not _in_water(dest):
					walk_to(dest)
	position = position.clamp(Vector2(10, 10), Game.MAP_SIZE - Vector2(10, 10))
	_update_sprite(vel)
	ui.queue_redraw()


func _update_sprite(vel: Vector2) -> void:
	if vel != Vector2.ZERO:
		if absf(vel.x) > absf(vel.y) * 0.9:
			dir = 2
			facing = signf(vel.x)
		else:
			dir = 0 if vel.y > 0 else 1
	var col := 0
	if moving and not fallen:
		var cyc := [1, 2, 3, 2]
		col = cyc[int(t * (11.0 if running else 6.5)) % 4]
	body.frame = dir * 4 + col
	body.flip_h = dir == 2 and facing > 0
	if fallen:
		body.rotation = PI / 2.0 * -facing
		body.position = Vector2(-10.0 * facing, -8)
		body.frame = 2 * 4
	else:
		body.rotation = 0.0
		body.position = Vector2.ZERO
	var m := Color.WHITE
	if mood_anger > 0.05:
		m = m.lerp(Color(1.0, 0.55, 0.5), mood_anger * 0.7)
	if mood_fear > 0.05:
		m = m.lerp(Color(0.75, 0.8, 1.0), mood_fear * 0.6)
	body.modulate = m
	shadow.scale = Vector2(2.6 if running and moving else 2.0, 2.0)


func draw_ui(c: CanvasItem) -> void:
	var h := 48.0
	var font := ThemeDB.fallback_font
	if world and world.show_names and not decor and str(def.get("name", "")) != "":
		var nm := str(def.name)
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		c.draw_rect(Rect2(-tw / 2.0 - 4, 5, tw + 8, 14), Color(0.1, 0.07, 0.12, 0.55))
		c.draw_string(font, Vector2(-tw / 2.0, 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	if emote_t > 0.0 and emote != "":
		var bob := sin(t * 6.0) * 2.0
		var r := Rect2(-14, -h - 34 + bob, 28, 28)
		c.draw_style_box(_bubble_box, r)
		if EMOTES.has(emote):
			var i: int = EMOTES[emote]
			c.draw_texture_rect_region(_emotes, Rect2(r.position + Vector2(2, 2), Vector2(24, 24)), Rect2(i * 12, 0, 12, 12))
		else:
			c.draw_string(font, r.position + Vector2(0, 19), emote, HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color(0.2, 0.15, 0.25))
	if bubble_t > 0.0 and bubble != "":
		var bw := 170.0
		var lines := int(ceil(bubble.length() / 25.0))
		var bh := 14.0 + lines * 14.0
		var bp := Vector2(-bw / 2.0, -h - 22.0 - bh)
		c.draw_style_box(_bubble_box, Rect2(bp, Vector2(bw, bh)))
		c.draw_texture_rect(_tail, Rect2(Vector2(-6, bp.y + bh - 2), Vector2(12, 8)), false)
		c.draw_multiline_string(font, bp + Vector2(8, 16), bubble, HORIZONTAL_ALIGNMENT_LEFT, bw - 16, 12, 8, Color(0.16, 0.12, 0.2))
