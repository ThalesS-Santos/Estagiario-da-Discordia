class_name NPC
extends CharacterBody2D
## NPC com spritesheet pixel art (baixo/cima/lado x 4 frames), sombra, balão de fala e emotes.

signal arrived

enum SuspicionState { CALM, ALERT, INVESTIGATING, SEARCHING, CONFRONTING }

const SUSPICION_CALM       := 0.0
const SUSPICION_ALERT      := 25.0
const SUSPICION_INVESTIGATE := 50.0
const SUSPICION_SEARCH     := 75.0
const SUSPICION_CONFRONT   := 100.0

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
var pursue_speed_mult := 1.0

var suspicion := 0.0
var suspicion_state: int = SuspicionState.CALM
var _suspicion_decay_paused := false

var pursuing := false
var pursue_target: Node2D = null
var pursue_timer := 0.0
var pursue_duration := 12.0
var pursue_lost_timer := 0.0
var _pursue_repath_t := 0.0
var _pursue_call_t := 0.0
var _pursue_shout_t := 0.0

var body: Sprite2D
var shadow: Sprite2D
var ui: NpcUI
var _bubble_box: StyleBoxTexture
var _tail: Texture2D
var _emotes: Texture2D

# Módulo 2: cone de visão (apenas NPCs de autoridade: guardas e rei)
var vision_cone: Area2D = null
var _vision_cone_polygon: CollisionPolygon2D = null

# Módulo 4: estado de empurrão NPC vs NPC
var _push_target: NPC = null      # NPC-alvo para colisão raivosa
var _push_cooldown := 0.0


func _is_authority() -> bool:
	return id in ["npc_guard", "npc_guard2", "npc_king"]


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
	if id == "npc_guard2":
		# Renato patrulha a cidade toda; Bram fica fixo no portão (só se move por comando direto).
		patrol = [Game.loc_pos("plaza"), Game.loc_pos("bakery") + Vector2(30, 10),
			Game.loc_pos("forge") + Vector2(-30, 10), Game.loc_pos("temple") + Vector2(20, 10),
			Game.loc_pos("stall") + Vector2(0, 20), Game.loc_pos("fountain") + Vector2(0, -20),
			Game.loc_pos("notice_board") + Vector2(0, 20)]
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
	if _is_authority():
		_build_vision_cone()


## Cria cone de visão triangular (~120 px) para NPCs de autoridade (guardas, rei).
## O Area2D fica rotacionado no _physics_process para bater com facing_direction.
func _build_vision_cone() -> void:
	vision_cone = Area2D.new()
	vision_cone.name = "VisionCone"
	vision_cone.collision_layer = 0
	vision_cone.collision_mask = 2  # camada do jogador
	vision_cone.monitorable = false
	var poly := CollisionPolygon2D.new()
	# Triângulo: ponta na origem, abrindo ~60° para a direita (+X = frente padrão)
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(120, -50),
		Vector2(120, 50),
	])
	vision_cone.add_child(poly)
	_vision_cone_polygon = poly
	vision_cone.body_entered.connect(_on_vision_cone_body_entered)
	add_child(vision_cone)


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
	bubble_label.position = Vector2(-85, -104)
	bubble_label.size = Vector2(170, 52)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.add_theme_stylebox_override("normal", _bubble_box)
	bubble_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.2))
	bubble_label.add_theme_font_size_override("font_size", 11)
	bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label.z_index = 100
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
	bubble_label.position = Vector2(-100 + randf_range(-30, 30), -118 + randf_range(-20, 10))
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


func hurt_mood(anger_amt: float, fear_amt: float) -> void:
	mood_anger = clampf(mood_anger + anger_amt, 0.0, 1.0)
	mood_fear = clampf(mood_fear + fear_amt, 0.0, 1.0)


func _in_water(p: Vector2) -> bool:
	return world != null and world.village != null and world.village.in_lake(p, 26.0)


func _pick_wander() -> Vector2:
	if id == "npc_orphan":
		return home + Vector2(randf_range(-110, 110), randf_range(-50, 8))
	if decor or def.get("wide_wander", false):
		return home + Vector2(randf_range(-70, 70), randf_range(-34, 34))
	return home + Vector2(randf_range(-28, 28), randf_range(-14, 14))


func add_suspicion(amount: float) -> void:
	var prev_state := suspicion_state
	suspicion = clampf(suspicion + amount, 0.0, 100.0)
	_update_suspicion_state()
	if suspicion_state != prev_state:
		_on_suspicion_state_changed(prev_state, suspicion_state)


func reduce_suspicion(amount: float) -> void:
	suspicion = clampf(suspicion - amount, 0.0, 100.0)
	_update_suspicion_state()


func _update_suspicion_state() -> void:
	if suspicion >= SUSPICION_CONFRONT:
		suspicion_state = SuspicionState.CONFRONTING
	elif suspicion >= SUSPICION_SEARCH:
		suspicion_state = SuspicionState.SEARCHING
	elif suspicion >= SUSPICION_INVESTIGATE:
		suspicion_state = SuspicionState.INVESTIGATING
	elif suspicion >= SUSPICION_ALERT:
		suspicion_state = SuspicionState.ALERT
	else:
		suspicion_state = SuspicionState.CALM


func _on_suspicion_state_changed(_from: int, to: int) -> void:
	match to:
		SuspicionState.ALERT:
			show_emote("?", 2.0)
		SuspicionState.INVESTIGATING:
			show_emote("!", 2.0)
			say("Hmm... estranho.", 3.0)
		SuspicionState.SEARCHING:
			show_emote("!", 2.5)
			say("Quem foi?!", 3.5)
		SuspicionState.CONFRONTING:
			show_emote("!", 3.0)
			say("Estagiário! O que você está fazendo?!", 4.5)
		_:
			pass


# ---- perseguição ----
func start_pursuit(target_node: Node2D, duration := 12.0) -> void:
	if fallen or pursuing:
		return
	pursuing = true
	pursue_target = target_node
	pursue_timer = 0.0
	pursue_duration = duration
	pursue_lost_timer = 0.0
	_pursue_repath_t = 0.0
	_pursue_call_t = 0.0
	_pursue_shout_t = 0.0
	running = true
	current_state = "RUN"
	show_emote("!", 2.0)
	say("Pare aí!", 3.0)


func stop_pursuit(reason := "") -> void:
	if not pursuing:
		return
	pursuing = false
	pursue_target = null
	running = false
	moving = false
	current_state = "IDLE"
	suspicion = clampf(suspicion, 0.0, 70.0)
	_suspicion_decay_paused = false
	if reason == "lost":
		show_emote("?", 2.5)
		say("Para onde ele foi?!", 3.0)
	elif reason == "timeout":
		show_emote("...", 2.0)
		say("Bah, não vale a pena.", 3.0)
	elif reason == "distracted":
		show_emote("!", 2.0)


func _tick_pursuit(delta: float) -> void:
	if not pursuing or not is_instance_valid(pursue_target):
		stop_pursuit("lost")
		return
	pursue_timer += delta
	if pursue_timer >= pursue_duration:
		stop_pursuit("timeout")
		return
	var dist := global_position.distance_to(pursue_target.global_position)
	# perdeu de vista
	if dist > 180.0:
		pursue_lost_timer += delta
		if pursue_lost_timer > 2.5:
			stop_pursuit("lost")
			return
	else:
		pursue_lost_timer = 0.0
	# recalcular caminho periodicamente
	_pursue_repath_t -= delta
	if _pursue_repath_t <= 0.0:
		_pursue_repath_t = 0.3
		walk_to(pursue_target.global_position, true)
	# gritar periodicamente
	_pursue_shout_t -= delta
	if _pursue_shout_t <= 0.0:
		_pursue_shout_t = 4.0
		var shouts := ["Volte aqui!", "Não vai escapar!", "Peguem ele!", "Eu vi o que você fez!"]
		say(shouts[randi() % shouts.size()], 2.5)
	# chamar reforço
	_pursue_call_t -= delta
	if _pursue_call_t <= 0.0 and dist < 120.0:
		_pursue_call_t = 6.0
		if world and world.has_method("_on_npc_calls_backup"):
			world._on_npc_calls_backup(self)
	# captura
	if dist < 24.0:
		if world and world.has_method("_on_npc_catches_player"):
			world._on_npc_catches_player(self)


func _process(delta: float) -> void:
	if world != null and (world.phase == 1 or world.get("ai_waiting") == true):
		return
	t += delta
	bubble_t = maxf(bubble_t - delta, 0.0)
	emote_t = maxf(emote_t - delta, 0.0)
	mood_anger = maxf(mood_anger - delta * 0.05, 0.0)
	mood_fear = maxf(mood_fear - delta * 0.05, 0.0)
	if not _suspicion_decay_paused and suspicion > 0.0:
		var decay := 3.0 if suspicion_state == SuspicionState.CALM else 1.5
		var decay_mult: float = Game.get_difficulty().suspicion_decay
		reduce_suspicion(delta * decay * decay_mult)
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
	# Módulo 2: rodar o cone de visão para bater com a direção que o NPC está olhando.
	if vision_cone != null:
		var cone_angle: float
		match dir:
			0: cone_angle = PI / 2.0           # frente (para baixo em top-down)
			1: cone_angle = -PI / 2.0          # costas (para cima)
			2: cone_angle = 0.0 if facing > 0 else PI  # lateral
			_: cone_angle = PI / 2.0
		vision_cone.rotation = cone_angle
	# Módulo 4: cooldown de empurrão e check de colisão raivosa NPC vs NPC
	if _push_cooldown > 0.0:
		_push_cooldown -= delta
	if current_state == "ANGRY" and _push_target == null and world != null and \
			Game.instability > 50.0 and not fallen:
		_check_npc_push_range()
	if pursuing:
		_tick_pursuit(delta)
	if moving and not fallen:
		if navigation_agent.is_navigation_finished():
			moving = false
			if global_position.distance_to(target) < 16.0:
				arrived.emit()
		else:
			var next := navigation_agent.get_next_path_position()
			motion = global_position.direction_to(next)
			var run_mult := (1.6 * pursue_speed_mult) if pursuing else (1.6 if running else 1.0)
			velocity = motion * minf(speed * run_mult * sp, global_position.distance_to(next) / maxf(delta, 0.001))
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
	elif ambient and not fallen and not pursuing and id != "npc_king":
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = randf_range(3.0, 7.0)
			if id == "npc_guard2" and not patrol.is_empty():
				patrol_i = (patrol_i + 1) % patrol.size()
				walk_to(patrol[patrol_i])
			else:
				var dest := _pick_wander()
				if not _in_water(dest):
					walk_to(dest)
	position = position.clamp(Vector2(10, 10), Game.MAP_SIZE - Vector2(10, 10))


## Módulo 2: corpo entrou no cone de visão — verifica se é o jogador com item suspeito.
func _on_vision_cone_body_entered(body: Node2D) -> void:
	if fallen or pursuing or not _is_authority():
		return
	if not body.is_in_group("player"):
		return
	# Só dispara se o jogador carrega item suspeito e não está em furtividade.
	var holding_sus: bool = body.has_method("is_holding_suspicious_item") and body.is_holding_suspicious_item()
	var in_stealth: bool = body.has_method("is_in_stealth_state") and body.is_in_stealth_state()
	if holding_sus and not in_stealth:
		_trigger_vision_detection(body)


func _trigger_vision_detection(target: Node2D) -> void:
	show_emote("!", 2.5)
	say("Alto aí! O que você tem aí?!", 4.0)
	Sfx.play("shout")
	if world and world.has_method("_on_vision_cone_caught"):
		world._on_vision_cone_caught(self, target)
	else:
		start_pursuit(target, 15.0)


## Módulo 4: verifica NPCs próximos para o caos de empurrão quando instabilidade > 50%.
func _check_npc_push_range() -> void:
	if _push_cooldown > 0.0:
		return
	if world == null:
		return
	var all_npcs: Array = world.npcs.values() if world.get("npcs") != null else []
	for other: NPC in all_npcs:
		if other == self or other.fallen or not is_instance_valid(other):
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist < 30.0:
			_do_push(other)
			break


func _do_push(other: NPC) -> void:
	_push_cooldown = 3.0
	_push_target = other
	# Animação de empurrão: o sprite dá um salto rápido na direção do alvo.
	var push_dir := global_position.direction_to(other.global_position)
	var push_tween := create_tween()
	push_tween.tween_property(body, "position",
		Vector2(push_dir.x * 6.0, push_dir.y * 6.0 - 4.0), 0.08).set_trans(Tween.TRANS_SINE)
	push_tween.tween_property(body, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BOUNCE)
	push_tween.tween_callback(func(): _push_target = null)
	# Partícula de fumaça/confusão entre os dois sprites.
	if world and world.has_method("emit_particle"):
		var midpoint := (global_position + other.global_position) / 2.0
		world.emit_particle("smoke_thin", midpoint)
		world.emit_particle("stars_dizzy", midpoint + Vector2(0, -8))
	# O alvo tropeça um pouco.
	other.hurt_mood(0.3, 0.1)


func apply_ai_directive(directive: Dictionary) -> void:
	if directive.get("npc_id") != id:
		return
	fear = int(directive.fear_level)
	anger = int(directive.anger_level)
	loyalty = int(directive.loyalty_level)
	var state: String = directive.new_state
	# Módulo 3: guarda com ANGRY vira perseguição imediata ao jogador.
	if state == "ANGRY" and _is_authority():
		state = "CHASE_PLAYER"
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
	elif state == "CHASE_PLAYER":
		# Módulo 3: inicia perseguição ao jogador com velocidade balanceada (130 px/s — 13% abaixo do jogador).
		var player_node := get_tree().get_first_node_in_group("player") as Node2D
		if player_node:
			# pursue_speed_mult calibrado para atingir ~130 px/s: speed(120) * run_mult(1.6) * mult = 130
			pursue_speed_mult = 130.0 / (speed * 1.6)
			start_pursuit(player_node, 20.0)
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
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		c.draw_rect(Rect2(-tw / 2.0 - 3, 4, tw + 6, 13), Color(0.04, 0.05, 0.08, 0.88))
		c.draw_rect(Rect2(-tw / 2.0 - 3, 4, tw + 6, 13), Color(1.0, 0.85, 0.35, 0.5), false, 1.0)
		c.draw_string(font, Vector2(-tw / 2.0, 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 1))
	if suspicion >= SUSPICION_ALERT:
		var bar_w := 22.0
		var bar_h := 3.0
		var bar_x := -bar_w / 2.0
		var bar_y := 20.0
		var fill := suspicion / 100.0 * bar_w
		var col: Color
		match suspicion_state:
			SuspicionState.ALERT:      col = Color(1.0, 0.85, 0.3)
			SuspicionState.INVESTIGATING: col = Color(1.0, 0.6, 0.1)
			SuspicionState.SEARCHING:  col = Color(1.0, 0.3, 0.1)
			_:                         col = Color(1.0, 0.1, 0.1)
		c.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.04, 0.05, 0.08, 0.85))
		c.draw_rect(Rect2(bar_x, bar_y, fill, bar_h), col)
		c.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), col.darkened(0.4), false, 1.0)
	if emote_t > 0.0 and emote != "":
		var bob := sin(t * 6.0) * 2.0
		var r := Rect2(-14, -h - 34 + bob, 28, 28)
		c.draw_style_box(_bubble_box, r)
		if EMOTES.has(emote):
			var i: int = EMOTES[emote]
			c.draw_texture_rect_region(_emotes, Rect2(r.position + Vector2(2, 2), Vector2(24, 24)), Rect2(i * 12, 0, 12, 12))
		else:
			c.draw_string(font, r.position + Vector2(0, 19), emote, HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color(0.2, 0.15, 0.25))
