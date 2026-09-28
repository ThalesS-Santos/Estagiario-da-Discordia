class_name PlayerIntern
extends CharacterBody2D
## O Estagiário: controller top-down com state machine, animação procedural e interação (objetos + fofoca).
## Para ser detectável, marque objetos com o grupo "grabbable" e NPCs com o grupo "gossip_target".

signal open_gossip_terminal(npc: Node2D)
signal gossip_blocked(npc: Node2D)
signal object_grabbed(obj: Node2D)
signal object_released(obj: Node2D)
signal emotion_changed(emotion: String)
signal drop_requested(obj: Node2D, world_pos: Vector2) ## emitido no clique quando external_drop_control = true
signal footstep_made(world_pos: Vector2, loudness: float) ## NPCs escutam isto; não é emitido em STEALTH.

enum State { IDLE, WALK, STEALTH, INTERACT }

@export_group("Movimento")
@export var walk_speed: float = 150.0
@export var stealth_speed: float = 70.0
@export var suspicious_speed_mult: float = 0.9

@export_group("Furtividade")
@export var stealth_scale_y: float = 0.9
@export var stealth_tilt_deg: float = 5.0
@export var posture_lerp: float = 12.0

@export_group("Câmera")
@export var cam_smoothing_speed: float = 5.0
@export var cam_lookahead_max: float = 50.0 ## px máximos de "espiada" na direção do mouse
@export var cam_lookahead_lerp: float = 6.0

@export_group("Animação procedural")
@export var base_scale: Vector2 = Vector2(2, 2) ## escala pixel-art do Sprite2D
@export var sheet_path: String = "res://assets/gen/chars/player_intern.png" ## folha 64x72 (4 colunas x 3 linhas: frente, costas, perfil)
@export var sheet_faces_left: bool = true ## a linha de perfil dos NPCs olha para a esquerda
@export var breathe_speed: float = 2.0
@export var breathe_amount: float = 0.025
@export var bob_speed: float = 14.0
@export var bob_height: float = 2.0
@export var hair_sway_deg: float = 14.0
@export var cloak_sway_deg: float = 22.0
@export var spring_stiffness: float = 140.0 ## rigidez da mola de capa/cabelo
@export var spring_damping: float = 7.0 ## amortecimento (baixo = balança mais ao parar)
@export var footstep_interval: float = 0.32

@export_group("Emoções")
@export var panic_duration: float = 1.6
@export var smug_duration: float = 2.5
@export var nervous_look_interval: Vector2 = Vector2(0.25, 0.7)

@export_group("Interação")
@export var pick_radius: float = 22.0 ## tolerância do clique do mouse sobre um objeto
@export var grab_time: float = 0.25
@export var behind_dot_limit: float = 0.3 ## dot(frente do NPC, dir NPC->jogador) acima disso = está na frente
@export var whisper_lean_deg: float = 12.0
@export var external_drop_control: bool = false ## true: quem gerencia o soltar (ex.: world.gd) decide o destino do objeto

@onready var sprite: Sprite2D = $Sprite2D
@onready var head: Sprite2D = $Sprite2D/HeadSprite
@onready var hair: Sprite2D = $Sprite2D/HairSprite
@onready var cloak_tail: Sprite2D = $Sprite2D/CloakTailSprite
@onready var bubble: Sprite2D = $Sprite2D/EmotionBubble
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var zone: Area2D = $InteractionZone
@onready var hand_target: Node2D = $HandTarget

var state: State = State.IDLE
var emotion: String = "NEUTRAL"
var facing_x: float = 1.0
var held_object: Node2D = null
var input_enabled: bool = true ## false congela o jogador (terminal aberto, simulação)
var scripted_dir: Vector2 = Vector2.ZERO ## cinemáticas: anda nessa direção enquanto o input está desligado
var grab_gate: Callable = Callable() ## (obj) -> bool: permite ao jogo aprovar/cobrar o ato de pegar

# Parâmetros animados pelo AnimationPlayer (panic_jump / whisper).
var fx_hop: float = 0.0
var fx_squash: Vector2 = Vector2.ONE
var fx_lean: float = 0.0

var _t: float = 0.0
var _move_dir: Vector2 = Vector2.ZERO
var _prev_velocity: Vector2 = Vector2.ZERO
var _step_timer: float = 0.0
var _hair_spring := Spring.new()
var _cloak_spring := Spring.new()
var _tilt: float = 0.0
var _posture_y: float = 1.0
var _breath_rate: float = 1.0
var _grab_tween: Tween
var _attached: bool = false
var _gossip_npc: Node2D = null
var _look_timer: float = 0.0
var _head_look: float = 0.0
var _emotion_timer: SceneTreeTimer
var _sweat: CPUParticles2D
var _sprite_base_pos: Vector2
var _row: int = 0 ## 0 frente, 1 costas, 2 perfil
var _has_crouch_rows: bool = false


## Mola amortecida simples usada por cabelo e capa (rotação em radianos).
class Spring:
	var value: float = 0.0
	var vel: float = 0.0

	func update(target: float, stiffness: float, damping: float, dt: float) -> float:
		vel += ((target - value) * stiffness - vel * damping) * dt
		value += vel * dt
		return value


func _ready() -> void:
	_ensure_input_actions()
	_setup_sheet()
	_sprite_base_pos = sprite.position
	sprite.scale = base_scale
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = cam_smoothing_speed
	bubble.visible = false
	_build_shadow()
	_build_animations()
	_build_sweat()
	set_emotion("NEUTRAL")


# ------------------------------------------------------------------ folha de sprites (mesmo layout dos NPCs)
## Sprite2D com Hframes=4 / Vframes=3 e pivô nos pés; as camadas modulares antigas ficam ocultas.
func _setup_sheet() -> void:
	sprite.texture = load(sheet_path)
	sprite.hframes = 4
	@warning_ignore("integer_division")
	sprite.vframes = maxi(sprite.texture.get_height() / 24, 3) # 3 linhas em pé (+3 agachado, se a folha tiver)
	_has_crouch_rows = sprite.vframes >= 6
	sprite.centered = false
	sprite.offset = Vector2(-8, -23)
	head.visible = false
	hair.visible = false
	cloak_tail.visible = false
	bubble.position = Vector2(0, -30)


## Linha (frente/costas/perfil) pelo último movimento e coluna pelo ciclo de caminhada [1,2,3,2].
func _update_sheet_frame() -> void:
	var v := velocity
	if v.length() > 5.0:
		if absf(v.x) > absf(v.y) * 0.9:
			_row = 2
		else:
			_row = 0 if v.y > 0.0 else 1
	var col := 0
	if v.length() > 5.0:
		var cycle := [1, 2, 3, 2]
		var rate := 11.0 if state == State.WALK else 6.0
		col = cycle[int(_t * rate) % 4]
	var flip_right := facing_x > 0.0
	if emotion == "NERVOUS" and v.length() <= 5.0 and _head_look != 0.0:
		_row = 2 # olha rapidamente para os lados
		flip_right = _head_look > 0.0
	var crouch_offset := 3 if (state == State.STEALTH and _has_crouch_rows) else 0
	sprite.frame = (_row + crouch_offset) * 4 + col
	sprite.flip_h = _row == 2 and (flip_right if sheet_faces_left else not flip_right)


# ------------------------------------------------------------------ input
## Registra as ações do Input Map caso não existam no projeto.
func _ensure_input_actions() -> void:
	var keys := {
		"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"stealth": KEY_SHIFT, "interact": KEY_E,
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("mouse_click"):
		InputMap.add_action("mouse_click")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("mouse_click", mb)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.INTERACT or not input_enabled:
		return
	if event.is_action_pressed("mouse_click"):
		if held_object:
			if external_drop_control:
				drop_requested.emit(held_object, drop_position())
			else:
				_release_object()
		else:
			_try_grab_at_mouse()
	elif event.is_action_pressed("interact"):
		_try_start_gossip()


# ------------------------------------------------------------------ state machine
func _physics_process(delta: float) -> void:
	_move_dir = Vector2.ZERO
	if state != State.INTERACT:
		if input_enabled:
			_move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down") # já normalizado (8 direções)
		elif scripted_dir != Vector2.ZERO:
			_move_dir = scripted_dir
		var wants_stealth := input_enabled and Input.is_action_pressed("stealth")
		if wants_stealth:
			_change_state(State.STEALTH)
		elif _move_dir != Vector2.ZERO:
			_change_state(State.WALK)
		else:
			_change_state(State.IDLE)

	var speed := 0.0
	match state:
		State.WALK:
			speed = walk_speed
		State.STEALTH:
			speed = stealth_speed
		_:
			speed = 0.0
	if emotion == "SUSPICIOUS":
		speed *= suspicious_speed_mult
	velocity = _move_dir * speed if state != State.INTERACT else Vector2.ZERO
	move_and_slide()

	if absf(_move_dir.x) > 0.1:
		facing_x = signf(_move_dir.x)
	_emit_footsteps(delta)
	if held_object and _attached and input_enabled and is_instance_valid(held_object):
		held_object.global_position = hand_target.global_position


func _change_state(new_state: State) -> void:
	if new_state == state:
		return
	_exit_state(state)
	state = new_state
	_enter_state(new_state)


func _enter_state(s: State) -> void:
	if s == State.INTERACT:
		velocity = Vector2.ZERO
		_move_dir = Vector2.ZERO


func _exit_state(_s: State) -> void:
	pass


## Passos só geram sinal sonoro ao andar (WALK); em STEALTH ficam silenciosos.
func _emit_footsteps(delta: float) -> void:
	if state != State.WALK or velocity == Vector2.ZERO:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = footstep_interval
		footstep_made.emit(global_position, 1.0)


# ------------------------------------------------------------------ frame: câmera + animação procedural
func _process(delta: float) -> void:
	_t += delta
	_update_camera(delta)
	_update_procedural(delta)
	_update_nervous(delta)


## Lookahead: a câmera se desloca (até cam_lookahead_max px) em direção ao cursor.
func _update_camera(delta: float) -> void:
	var to_mouse: Vector2 = (get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5) / camera.zoom
	var target: Vector2 = (to_mouse * 0.3).limit_length(cam_lookahead_max)
	camera.position = camera.position.lerp(target, clampf(cam_lookahead_lerp * delta, 0.0, 1.0))


func _update_procedural(delta: float) -> void:
	var moving := velocity.length() > 5.0
	var speed_ratio := velocity.x / maxf(walk_speed, 1.0)

	# Respiração (idle): senoide sutil no Scale Y; NERVOUS respira 2x mais rápido; SMUG infla o peito.
	var breath := sin(_t * TAU * breathe_speed * 0.5 * _breath_rate) * breathe_amount
	var chest_x := 0.0
	if emotion == "SMUG":
		breath += 0.04
		chest_x = 0.04

	# Postura furtiva: achata (Scale Y) e inclina na direção do movimento.
	var stealth_on := state == State.STEALTH
	var target_y := stealth_scale_y if stealth_on and not _has_crouch_rows else 1.0 # com frames agachados não precisa achatar
	_posture_y = lerpf(_posture_y, target_y, clampf(posture_lerp * delta, 0.0, 1.0))
	var target_tilt := deg_to_rad(stealth_tilt_deg) * signf(_move_dir.x) if stealth_on and moving else 0.0
	_tilt = lerpf(_tilt, target_tilt, clampf(posture_lerp * delta, 0.0, 1.0))

	# Sussurro: inclina o corpo para o NPC (fx_lean animado).
	var lean := 0.0
	if fx_lean != 0.0 and is_instance_valid(_gossip_npc):
		lean = deg_to_rad(whisper_lean_deg) * fx_lean * signf(_gossip_npc.global_position.x - global_position.x)
		facing_x = signf(_gossip_npc.global_position.x - global_position.x)

	_update_sheet_frame()
	sprite.scale = Vector2(
		base_scale.x * (1.0 + chest_x) * fx_squash.x,
		base_scale.y * _posture_y * (1.0 + breath) * fx_squash.y * (1.0 - 0.05 * fx_lean))
	sprite.rotation = _tilt * facing_x + lean + _cloak_spring.value * 0.35 # inércia do corpo/capa

	# Passos: bobbing vertical enquanto anda (mais lento e baixo em stealth).
	var bob := 0.0
	if moving:
		var rate := bob_speed * (0.6 if stealth_on else 1.0)
		bob = -absf(sin(_t * rate)) * bob_height * (0.5 if stealth_on else 1.0)
	sprite.position = _sprite_base_pos + Vector2(0.0, bob + fx_hop)

	# Cabelo e capa: molas guiadas pela velocidade. Ao parar bruscamente o alvo cai a 0 e a mola
	# (sub-amortecida) ultrapassa, balançando a capa para frente por inércia antes de assentar.
	var hair_target := deg_to_rad(hair_sway_deg) * speed_ratio * facing_x * 0.5 + sin(_t * 2.3) * 0.02
	var cloak_target := deg_to_rad(cloak_sway_deg) * speed_ratio * facing_x * 0.5 + sin(_t * 1.7) * 0.015
	hair.rotation = _hair_spring.update(hair_target, spring_stiffness, spring_damping, delta)
	cloak_tail.rotation = _cloak_spring.update(cloak_target, spring_stiffness * 0.8, spring_damping * 0.7, delta)
	_prev_velocity = velocity

	# Cabeça: olhar de lado (NERVOUS) desloca cabeça e cabelo.
	head.position.x = lerpf(head.position.x, _head_look, clampf(20.0 * delta, 0.0, 1.0))
	hair.position.x = head.position.x


## NERVOUS: a cabeça olha rapidamente para os lados.
func _update_nervous(delta: float) -> void:
	if emotion != "NERVOUS":
		_head_look = 0.0
		return
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(nervous_look_interval.x, nervous_look_interval.y)
		_head_look = [-1.5, 0.0, 1.5].pick_random()


# ------------------------------------------------------------------ emoções
func set_emotion(emotion_state: String) -> void:
	var e := emotion_state.to_upper().strip_edges()
	if e.begins_with("PANIC"):
		e = "PANIC"
	elif e.begins_with("SMUG") or e == "JOY":
		e = "SMUG"
	if e not in ["NEUTRAL", "SUSPICIOUS", "NERVOUS", "PANIC", "SMUG"]:
		push_warning("Emoção desconhecida: %s" % emotion_state)
		return
	emotion = e
	_breath_rate = 2.0 if e == "NERVOUS" else 1.0
	_sweat.emitting = e == "NERVOUS"
	bubble.visible = e in ["SUSPICIOUS", "PANIC", "SMUG"]
	match e:
		"SUSPICIOUS":
			head.frame = 1 # olhos cerrados
			bubble.frame = 0 # ???
		"PANIC":
			head.frame = 0
			bubble.frame = 1 # !
			anim.play("panic_jump")
		"SMUG":
			head.frame = 2 # sorriso
			bubble.frame = 2
		_:
			head.frame = 0
	if e == "PANIC":
		_revert_after(panic_duration)
	elif e == "SMUG":
		_revert_after(smug_duration)
	emotion_changed.emit(e)


func _revert_after(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds)
	_emotion_timer = timer
	timer.timeout.connect(func() -> void:
		if _emotion_timer == timer:
			set_emotion("NEUTRAL"))


func _build_shadow() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load("res://assets/gen/chars/shadow.png")
	shadow.scale = Vector2(2, 2)
	shadow.show_behind_parent = true
	add_child(shadow)
	move_child(shadow, 0)


func _build_sweat() -> void:
	_sweat = CPUParticles2D.new()
	_sweat.name = "SweatParticles"
	_sweat.texture = load("res://assets/gen/player/sweat.png")
	_sweat.position = Vector2(3, -19) # testa (coordenadas locais do sprite)
	_sweat.amount = 4
	_sweat.lifetime = 0.7
	_sweat.direction = Vector2(1, -1)
	_sweat.spread = 35.0
	_sweat.initial_velocity_min = 6.0
	_sweat.initial_velocity_max = 12.0
	_sweat.gravity = Vector2(0, 60)
	_sweat.emitting = false
	sprite.add_child(_sweat)


# ------------------------------------------------------------------ animações (AnimationPlayer)
func _build_animations() -> void:
	var lib := AnimationLibrary.new()

	var jump := Animation.new()
	jump.length = 0.45
	var t_hop := jump.add_track(Animation.TYPE_VALUE)
	jump.track_set_path(t_hop, NodePath(".:fx_hop"))
	jump.track_insert_key(t_hop, 0.0, 0.0)
	jump.track_insert_key(t_hop, 0.2, -12.0)
	jump.track_insert_key(t_hop, 0.45, 0.0)
	var t_sq := jump.add_track(Animation.TYPE_VALUE)
	jump.track_set_path(t_sq, NodePath(".:fx_squash"))
	jump.track_insert_key(t_sq, 0.0, Vector2(1.0, 1.0))
	jump.track_insert_key(t_sq, 0.08, Vector2(0.9, 1.25)) # estica ao saltar
	jump.track_insert_key(t_sq, 0.3, Vector2(0.95, 1.1))
	jump.track_insert_key(t_sq, 0.4, Vector2(1.1, 0.75)) # encolhe ao pousar
	jump.track_insert_key(t_sq, 0.45, Vector2(1.0, 1.0))
	lib.add_animation("panic_jump", jump)

	var whisper := Animation.new()
	whisper.length = 0.3
	var t_lean := whisper.add_track(Animation.TYPE_VALUE)
	whisper.track_set_path(t_lean, NodePath(".:fx_lean"))
	whisper.track_insert_key(t_lean, 0.0, 0.0)
	whisper.track_insert_key(t_lean, 0.3, 1.0)
	whisper.track_set_interpolation_type(t_lean, Animation.INTERPOLATION_CUBIC)
	lib.add_animation("whisper", whisper)

	anim.add_animation_library("", lib)


# ------------------------------------------------------------------ interação: objetos
func _nodes_in_zone(group: StringName) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var r := _zone_radius()
	for n: Node in get_tree().get_nodes_in_group(group):
		var n2 := n as Node2D
		if n2 and n2 != held_object and n2.visible and n2.global_position.distance_to(zone.global_position) <= r:
			out.append(n2)
	return out


func _zone_radius() -> float:
	var cs := zone.get_child(0) as CollisionShape2D
	return (cs.shape as CircleShape2D).radius if cs and cs.shape is CircleShape2D else 40.0


func _try_grab_at_mouse() -> void:
	var mouse := get_global_mouse_position()
	var best: Node2D = null
	var best_d := pick_radius
	for o in _nodes_in_zone(&"grabbable"):
		var d := o.global_position.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = o
	if best and (not grab_gate.is_valid() or grab_gate.call(best)):
		_grab_object(best)


func _grab_object(obj: Node2D) -> void:
	held_object = obj
	_attached = false
	if _grab_tween:
		_grab_tween.kill()
	_grab_tween = create_tween()
	_grab_tween.tween_property(obj, "global_position", hand_target.global_position, grab_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_grab_tween.tween_callback(func() -> void: _attached = true)
	object_grabbed.emit(obj)


## Ponto de soltura: na direção do mouse, limitado ao alcance da zona de interação.
func drop_position() -> Vector2:
	return global_position + (get_global_mouse_position() - global_position).limit_length(_zone_radius() + 20.0)


## Esquece o objeto sem animar (quando o jogo assumiu o controle dele).
func forget_held() -> void:
	held_object = null
	_attached = false
	if _grab_tween:
		_grab_tween.kill()


func _release_object() -> void:
	var obj := held_object
	held_object = null
	_attached = false
	if _grab_tween:
		_grab_tween.kill()
	if obj:
		var drop_pos := global_position + Vector2(18.0 * facing_x, 4.0)
		var tw := create_tween()
		tw.tween_property(obj, "global_position", drop_pos, 0.3) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		object_released.emit(obj)


# ------------------------------------------------------------------ interação: fofoca
## Direção para onde o NPC olha (usa get_facing_vector() se existir; senão as variáveis dir/facing do NPC do jogo).
func _npc_facing(npc: Node2D) -> Vector2:
	if npc.has_method("get_facing_vector"):
		return npc.call("get_facing_vector")
	if "dir" in npc:
		match int(npc.get("dir")):
			0: return Vector2.DOWN
			1: return Vector2.UP
			_: return Vector2(float(npc.get("facing")) if "facing" in npc else 1.0, 0.0)
	return Vector2.DOWN


## O jogador deve estar atrás ou ao lado do NPC (fora do cone frontal).
func _is_behind_or_beside(npc: Node2D) -> bool:
	var to_player := (global_position - npc.global_position).normalized()
	return _npc_facing(npc).dot(to_player) < behind_dot_limit


func _try_start_gossip() -> void:
	var best: Node2D = null
	var best_d := INF
	for n in _nodes_in_zone(&"gossip_target"):
		var d := n.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return
	if not _is_behind_or_beside(best):
		gossip_blocked.emit(best)
		return
	_gossip_npc = best
	_change_state(State.INTERACT)
	head.frame = 3 # mão na boca
	anim.play("whisper")
	open_gossip_terminal.emit(best)


## Módulo 2: retorna true se o jogador carrega um item considerado suspeito por guardas.
func is_holding_suspicious_item() -> bool:
	if held_object == null:
		return false
	# Item é suspeito se tiver tag "real", "arma", "missao" ou "proibido" na sua definição.
	if held_object.has_method("get") and held_object.get("def") is Dictionary:
		for tag: String in held_object.def.get("tags", []):
			if tag in ["real", "arma", "missao", "proibido", "chave", "reliquia"]:
				return true
	# Fallback: qualquer item carregado é suspeito perto de autoridades.
	return held_object != null


## Módulo 2: retorna true se o jogador estiver em modo furtivo (agachado/stealth).
func is_in_stealth_state() -> bool:
	return state == State.STEALTH


## Chame quando o terminal de fofoca fechar para devolver o controle ao jogador.
func end_interaction() -> void:
	if state != State.INTERACT:
		return
	anim.play_backwards("whisper")
	head.frame = {"SUSPICIOUS": 1, "SMUG": 2}.get(emotion, 0)
	_change_state(State.IDLE)
