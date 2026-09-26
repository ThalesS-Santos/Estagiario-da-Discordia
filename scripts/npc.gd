class_name NPC
extends CharacterBody2D
## NPC com spritesheet pixel art (baixo/cima/lado x 4 frames), sombra, balão de fala e emotes.

signal arrived

@export var speed := 120.0
@export var fear := 0
@export var anger := 0
@export var loyalty := 100
@export var current_state := "IDLE"
var navigation_agent: NavigationAgent2D
var bubble_label: Label
var bubble_tween: Tween
var motion := Vector2.ZERO
var stuck_time := 0.0

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
	add_to_group("gossip_target")
	fear = int(d.get("fear", 0))
	anger = int(d.get("anger", 0))
	loyalty = int(d.get("loyalty", 100))
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
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	collider.shape = circle
	add_child(collider)
	navigation_agent = NavigationAgent2D.new()
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 6.0
	add_child(navigation_agent)


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
	bubble_label = Label.new()
	bubble_label.position = Vector2(-100, -118)
	bubble_label.size = Vector2(200, 64)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.add_theme_stylebox_override("normal", _bubble_box)
	bubble_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.2))
	bubble_label.add_theme_font_size_override("font_size", 13)
	bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label.z_index = 11
	bubble_label.visible = false
	add_child(bubble_label)


class NpcUI extends Node2D:
	var npc

	func _draw() -> void:
		npc.draw_ui(self)


func walk_to(p: Vector2, run := false) -> void:
	if fallen:
		return
	target = p
	navigation_agent.target_position = p
	stuck_time = 0.0
	moving = true
	running = run
	current_state = "RUN" if run else "WALK"
	last_active = world.time if world else 0.0
	if absf(p.x - position.x) > 2.0:
		facing = signf(p.x - position.x)


func say(text: String, dur := 3.5) -> void:
	bubble = text
	bubble_t = dur
	bubble_label.text = text.left(AIContract.MAX_DIALOGUE)
	bubble_label.visible = true
	bubble_label.pivot_offset = Vector2(100, 64)
	bubble_label.scale = Vector2.ZERO
	if bubble_tween:
		bubble_tween.kill()
	bubble_tween = create_tween()
	bubble_tween.tween_property(bubble_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
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
	if decor or def.get("wide_wander", false):
		return home + Vector2(randf_range(-70, 70), randf_range(-34, 34))
	return home + Vector2(randf_range(-28, 28), randf_range(-14, 14))


func _process(delta: float) -> void:
	if world != null and (world.phase == 1 or world.get("ai_waiting") == true):
		return
	t += delta
	bubble_t = maxf(bubble_t - delta, 0.0)
	emote_t = maxf(emote_t - delta, 0.0)
	mood_anger = maxf(mood_anger - delta * 0.05, 0.0)
	mood_fear = maxf(mood_fear - delta * 0.05, 0.0)
	bubble_label.visible = bubble_t > 0.0
	_update_sprite(motion)
	ui.queue_redraw()


func _physics_process(delta: float) -> void:
	if world != null and (world.phase == 1 or world.get("ai_waiting") == true):
		return
	var sp := 1.0 if world == null or world.phase != 2 else float(Game.settings.sim_speed)
	motion = Vector2.ZERO
	velocity = Vector2.ZERO
	if world != null and not world.village.navigation.navigation_ready:
		return
	if NavigationServer2D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return
	if moving and not fallen:
		if navigation_agent.is_navigation_finished():
			moving = false
			if global_position.distance_to(target) < 16.0:
				arrived.emit()
		else:
			var next := navigation_agent.get_next_path_position()
			motion = global_position.direction_to(next)
			velocity = motion * minf(speed * (1.6 if running else 1.0) * sp, global_position.distance_to(next) / maxf(delta, 0.001))
			var before := global_position
			move_and_slide()
			stuck_time = stuck_time + delta if global_position.distance_to(before) < 0.05 else 0.0
			if stuck_time > 2.0:
				moving = false
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


func apply_ai_directive(directive: Dictionary) -> void:
	if directive.get("npc_id") != id:
		return
	fear = int(directive.fear_level)
	anger = int(directive.anger_level)
	loyalty = int(directive.loyalty_level)
	var state: String = directive.new_state
	get_up()
	moving = false
	var destination: String = directive.target_node_to_move
	# Explicit registries only. Never resolve arbitrary model-provided NodePaths.
	if world != null and world.has_method("get_ai_target"):
		var target_node: Node2D = world.get_ai_target(destination)
		if target_node != null:
			walk_to(target_node.global_position, state == "RUN" or state == "AFRAID")
	elif Game.LOCATIONS.has(destination):
		walk_to(Game.loc_pos(destination), state == "RUN" or state == "AFRAID")
	elif world != null and world.get("npcs") != null and world.npcs.has(destination):
		walk_to(world.npcs[destination].global_position, state == "RUN")
	current_state = state
	if state == "FALLEN":
		fall()
	hurt_mood(float(anger) / 100.0, float(fear) / 100.0)
	if directive.dialogue_bubble != "":
		say(directive.dialogue_bubble, 4.0)


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
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		c.draw_rect(Rect2(-tw / 2.0 - 5, 4, tw + 10, 16), Color(0.04, 0.05, 0.08, 0.88))
		c.draw_rect(Rect2(-tw / 2.0 - 5, 4, tw + 10, 16), Color(1.0, 0.85, 0.35, 0.6), false, 1.0)
		c.draw_string(font, Vector2(-tw / 2.0, 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 1))
	if emote_t > 0.0 and emote != "":
		var bob := sin(t * 6.0) * 2.0
		var r := Rect2(-14, -h - 34 + bob, 28, 28)
		c.draw_style_box(_bubble_box, r)
		if EMOTES.has(emote):
			var i: int = EMOTES[emote]
			c.draw_texture_rect_region(_emotes, Rect2(r.position + Vector2(2, 2), Vector2(24, 24)), Rect2(i * 12, 0, 12, 12))
		else:
			c.draw_string(font, r.position + Vector2(0, 19), emote, HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color(0.2, 0.15, 0.25))
