class_name NPC
extends Node2D
## NPC desenhado proceduralmente: corpo em camadas, idle/walk/run, reações e balões de fala.

signal arrived

var id := ""
var def: Dictionary = {}
var world
var home := Vector2.ZERO
var target := Vector2.ZERO
var moving := false
var running := false
var fallen := false
var ambient := true
var t := 0.0
var facing := 1.0
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


func setup(npc_id: String, d: Dictionary, w) -> void:
	id = npc_id
	def = d
	world = w
	home = Game.loc_pos(d.home)
	if id == "npc_king":
		home = Vector2(640, 118)
	position = home
	target = home
	t = randf() * 10.0
	if id == "npc_guard":
		patrol = [Game.loc_pos("castle_gate") + Vector2(0, 14), Game.loc_pos("fountain") + Vector2(-40, 40), Game.loc_pos("well") + Vector2(0, 30)]
	z_index = 0


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


func _process(delta: float) -> void:
	var sp := 1.0 if world == null or world.phase != 2 else float(Game.settings.sim_speed)
	t += delta
	bubble_t = maxf(bubble_t - delta, 0.0)
	emote_t = maxf(emote_t - delta, 0.0)
	mood_anger = maxf(mood_anger - delta * 0.05, 0.0)
	mood_fear = maxf(mood_fear - delta * 0.05, 0.0)
	if moving and not fallen:
		var to := target - position
		var step := (110.0 if running else 55.0) * delta * sp
		if to.length() <= step + 1.0:
			position = target
			moving = false
			arrived.emit()
		else:
			position += to.normalized() * step
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
			elif id == "npc_orphan":
				walk_to(position + Vector2(randf_range(-120, 120), randf_range(-60, 60)).clamp(Vector2(-120, -60), Vector2(120, 60)))
			else:
				walk_to(home + Vector2(randf_range(-28, 28), randf_range(-14, 14)))
	position = position.clamp(Vector2(10, 10), Game.MAP_SIZE - Vector2(10, 10))
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = def.size
	var body: Color = def.color
	var skin: Color = def.skin
	if mood_anger > 0.05:
		body = body.lerp(Color(0.9, 0.2, 0.15), mood_anger * 0.6)
		skin = skin.lerp(Color(0.95, 0.35, 0.3), mood_anger * 0.7)
	if mood_fear > 0.05:
		skin = skin.lerp(Color(0.95, 0.95, 0.95), mood_fear * 0.6)
	var breathe := sin(t * 4.2) * 1.0
	var walk_phase := sin(t * (16.0 if running else 9.0)) if moving else 0.0
	# sombra — oval que estica ao correr
	var shadow_stretch := 1.3 if running and moving else 1.0
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(shadow_stretch, 0.3))
	draw_circle(Vector2.ZERO, sz.x * 0.5, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, sz.x * 0.5, Color(0, 0, 0, 0.12), false, 0.5)
	if fallen:
		draw_set_transform(Vector2(0, -sz.x * 0.35), PI / 2.0 * -facing, Vector2.ONE)
	else:
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(facing, 1.0))
	var h := sz.y
	var w := sz.x
	var outline := Color(0.08, 0.06, 0.05)

	# --- PERNAS e PÉS ---
	var shoe := Color(0.22, 0.18, 0.14)
	var pants := body.darkened(0.35)
	if id == "npc_orphan":
		shoe = skin.darkened(0.15)  # descalça
		pants = Color(0.45, 0.35, 0.28)
	elif id == "npc_guard":
		pants = Color(0.38, 0.3, 0.2)
		shoe = Color(0.3, 0.25, 0.18)
	elif id == "npc_priestess":
		pants = Color(0.9, 0.88, 0.95)
	var leg_l_y := walk_phase * 3.0 if moving else 0.0
	var leg_r_y := -walk_phase * 3.0 if moving else 0.0
	# perna esquerda
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.3, -11 + leg_l_y), Vector2(-w * 0.08, -11 + leg_l_y),
		Vector2(-w * 0.06, -1 + leg_l_y), Vector2(-w * 0.32, -1 + leg_l_y)
	]), pants)
	# perna direita
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.08, -11 + leg_r_y), Vector2(w * 0.3, -11 + leg_r_y),
		Vector2(w * 0.32, -1 + leg_r_y), Vector2(w * 0.06, -1 + leg_r_y)
	]), pants)
	# pé esquerdo (sapato ou pé descalço)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.34, -1 + leg_l_y), Vector2(-w * 0.04, -1 + leg_l_y),
		Vector2(-w * 0.02, 2 + leg_l_y), Vector2(-w * 0.36, 2 + leg_l_y)
	]), shoe)
	draw_line(Vector2(-w * 0.36, 2 + leg_l_y), Vector2(-w * 0.02, 2 + leg_l_y), outline, 0.5)
	# pé direito
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.04, -1 + leg_r_y), Vector2(w * 0.34, -1 + leg_r_y),
		Vector2(w * 0.36, 2 + leg_r_y), Vector2(w * 0.02, 2 + leg_r_y)
	]), shoe)
	draw_line(Vector2(w * 0.02, 2 + leg_r_y), Vector2(w * 0.36, 2 + leg_r_y), outline, 0.5)

	# --- TRONCO (com respiração) ---
	var top := -h + 14.0 + breathe * 0.5
	var torso_h := h - 24.0 - breathe * 0.5
	var tw := w * 0.52 + breathe * 0.3  # largura do tronco respira
	# corpo oval via polígono arredondado
	var torso_pts := PackedVector2Array()
	var torso_outline_pts := PackedVector2Array()
	var segs := 10
	# lado esquerdo (de cima para baixo)
	for i in range(segs + 1):
		var frac := float(i) / float(segs)
		var bx := -tw * (0.8 + 0.2 * sin(frac * PI))
		var by := top + frac * torso_h
		torso_pts.append(Vector2(bx, by))
		torso_outline_pts.append(Vector2(bx, by))
	# lado direito (de baixo para cima)
	for i in range(segs, -1, -1):
		var frac := float(i) / float(segs)
		var bx := tw * (0.8 + 0.2 * sin(frac * PI))
		var by := top + frac * torso_h
		torso_pts.append(Vector2(bx, by))
	draw_colored_polygon(torso_pts, body)
	# contorno do tronco
	for i in range(torso_pts.size() - 1):
		draw_line(torso_pts[i], torso_pts[i + 1], outline, 0.7)
	draw_line(torso_pts[torso_pts.size() - 1], torso_pts[0], outline, 0.7)
	# detalhe de sombreamento no tronco (lado escuro)
	var shade := body.darkened(0.2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-tw * 0.9, top + 2), Vector2(-tw * 0.5, top + 2),
		Vector2(-tw * 0.4, top + torso_h - 2), Vector2(-tw * 0.85, top + torso_h - 2)
	]), shade)

	# --- PESCOÇO ---
	var neck_y := top - 1.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, neck_y), Vector2(3, neck_y),
		Vector2(3.5, neck_y - 4), Vector2(-3.5, neck_y - 4)
	]), skin)
	draw_line(Vector2(-3, neck_y), Vector2(-3.5, neck_y - 4), skin.darkened(0.15), 0.5)
	draw_line(Vector2(3, neck_y), Vector2(3.5, neck_y - 4), skin.darkened(0.15), 0.5)

	# --- ADEREÇOS POR NPC (tronco / roupa) ---
	match id:
		"npc_king":
			# manto púrpura com gola de arminho
			var _robe_c := Color(0.38, 0.12, 0.52)
			var gold := Color(0.85, 0.72, 0.2)
			var ermine := Color(0.95, 0.93, 0.88)
			# gola de arminho
			draw_colored_polygon(PackedVector2Array([
				Vector2(-tw * 0.95, top + 1), Vector2(tw * 0.95, top + 1),
				Vector2(tw * 0.85, top + 5), Vector2(-tw * 0.85, top + 5)
			]), ermine)
			# manchas de arminho
			for i in 3:
				draw_circle(Vector2(-tw * 0.6 + i * tw * 0.55, top + 3), 0.8, Color(0.1, 0.1, 0.1))
			# faixa dourada vertical central
			draw_rect(Rect2(-1.5, top + 5, 3, torso_h - 7), gold)
			# faixa dourada horizontal no peito
			draw_rect(Rect2(-tw * 0.7, top + 8, tw * 1.4, 2), gold)
			# barra inferior dourada
			draw_rect(Rect2(-tw * 0.9, top + torso_h - 3, tw * 1.8, 2.5), gold)
		"npc_baker":
			# avental branco
			var apron := Color(0.97, 0.97, 0.95)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-tw * 0.65, top + 6), Vector2(tw * 0.65, top + 6),
				Vector2(tw * 0.7, top + torso_h), Vector2(-tw * 0.7, top + torso_h)
			]), apron)
			draw_line(Vector2(-tw * 0.65, top + 6), Vector2(tw * 0.65, top + 6), Color(0.8, 0.8, 0.78), 0.7)
			# cordão do avental
			draw_line(Vector2(-tw * 0.6, top + 8), Vector2(tw * 0.6, top + 8), Color(0.7, 0.65, 0.6), 0.7)
			# manchas de farinha
			draw_circle(Vector2(-tw * 0.2, top + 12), 1.5, Color(1, 1, 0.98, 0.5))
			draw_circle(Vector2(tw * 0.3, top + 15), 1.2, Color(1, 1, 0.98, 0.4))
			draw_circle(Vector2(0, top + torso_h - 4), 1.8, Color(1, 1, 0.98, 0.45))
		"npc_smith":
			# avental de couro
			var leather := Color(0.4, 0.25, 0.14)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-tw * 0.55, top + 4), Vector2(tw * 0.55, top + 4),
				Vector2(tw * 0.6, top + torso_h + 1), Vector2(-tw * 0.6, top + torso_h + 1)
			]), leather)
			draw_line(Vector2(-tw * 0.55, top + 4), Vector2(tw * 0.55, top + 4), Color(0.3, 0.18, 0.08), 0.8)
			# tira do avental
			draw_line(Vector2(0, top + 1), Vector2(0, top + 4), leather.darkened(0.2), 1.2)
			# marcas de fuligem
			draw_circle(Vector2(-tw * 0.3, top + 10), 1.0, Color(0.15, 0.12, 0.1, 0.5))
			draw_circle(Vector2(tw * 0.15, top + 14), 0.8, Color(0.15, 0.12, 0.1, 0.4))
			draw_circle(Vector2(tw * 0.4, top + 8), 0.7, Color(0.15, 0.12, 0.1, 0.35))
		"npc_guard":
			# placas de armadura no peito
			var metal := Color(0.6, 0.62, 0.68)
			var metal_h := Color(0.72, 0.74, 0.8)
			# peito central
			draw_colored_polygon(PackedVector2Array([
				Vector2(-tw * 0.6, top + 2), Vector2(tw * 0.6, top + 2),
				Vector2(tw * 0.55, top + torso_h * 0.6),
				Vector2(0, top + torso_h * 0.7),
				Vector2(-tw * 0.55, top + torso_h * 0.6)
			]), metal)
			# brilho da armadura
			draw_line(Vector2(-tw * 0.1, top + 3), Vector2(-tw * 0.1, top + torso_h * 0.4), metal_h, 1.0)
			# cinto de espada
			draw_rect(Rect2(-tw * 0.85, top + torso_h * 0.65, tw * 1.7, 2.5), Color(0.35, 0.25, 0.15))
			draw_circle(Vector2(0, top + torso_h * 0.65 + 1.2), 1.5, Color(0.7, 0.65, 0.2))
			# espada no quadril
			draw_line(Vector2(tw * 0.7, top + torso_h * 0.5), Vector2(tw * 0.7, top + torso_h + 8), Color(0.55, 0.55, 0.6), 1.8)
			draw_line(Vector2(tw * 0.55, top + torso_h * 0.5), Vector2(tw * 0.85, top + torso_h * 0.5), Color(0.45, 0.35, 0.2), 1.5)
			# escudo nas costas (visível como arco)
			draw_arc(Vector2(-tw * 0.8, top + 6), 5.0, -PI * 0.3, PI * 0.7, 8, Color(0.5, 0.15, 0.15), 1.5)
		"npc_priestess":
			# vestes brancas fluidas
			var robe_w := Color(0.95, 0.93, 1.0)
			# drapeado — linhas verticais suaves
			for i in range(-2, 3):
				var lx := float(i) * tw * 0.3
				draw_line(Vector2(lx, top + 6), Vector2(lx + sin(t * 2.0 + i) * 0.8, top + torso_h), robe_w.darkened(0.08), 0.5)
			# amuleto / pendente
			var pendant_y := top + 8
			draw_line(Vector2(-1, top + 1), Vector2(0, pendant_y), Color(0.7, 0.6, 0.2), 0.6)
			draw_line(Vector2(1, top + 1), Vector2(0, pendant_y), Color(0.7, 0.6, 0.2), 0.6)
			draw_circle(Vector2(0, pendant_y + 2), 2.0, Color(0.3, 0.6, 0.85))
			draw_circle(Vector2(0, pendant_y + 2), 2.0, Color(0.5, 0.7, 0.95), false, 0.6)
			# barra decorativa inferior
			draw_rect(Rect2(-tw * 0.85, top + torso_h - 2, tw * 1.7, 2), Color(0.8, 0.75, 0.5))
		"npc_merchant":
			# túnica colorida com cinto
			var belt := Color(0.4, 0.28, 0.15)
			# padrão decorativo na túnica
			draw_rect(Rect2(-tw * 0.4, top + 4, tw * 0.8, 2), Color(0.8, 0.65, 0.2))
			# cinto
			draw_rect(Rect2(-tw * 0.85, top + torso_h * 0.55, tw * 1.7, 3), belt)
			draw_circle(Vector2(0, top + torso_h * 0.55 + 1.5), 1.5, Color(0.7, 0.6, 0.15))
			# bolsa no cinto
			draw_colored_polygon(PackedVector2Array([
				Vector2(tw * 0.4, top + torso_h * 0.55 + 3),
				Vector2(tw * 0.7, top + torso_h * 0.55 + 3),
				Vector2(tw * 0.65, top + torso_h * 0.55 + 8),
				Vector2(tw * 0.45, top + torso_h * 0.55 + 8)
			]), Color(0.5, 0.35, 0.18))
			draw_line(Vector2(tw * 0.45, top + torso_h * 0.55 + 5), Vector2(tw * 0.65, top + torso_h * 0.55 + 5), belt.darkened(0.2), 0.6)
		"npc_orphan":
			# roupas remendadas
			var patch1 := Color(0.5, 0.55, 0.4)
			var patch2 := Color(0.55, 0.38, 0.35)
			# remendo 1
			draw_rect(Rect2(-tw * 0.4, top + 6, 5, 5), patch1)
			draw_line(Vector2(-tw * 0.4, top + 6), Vector2(-tw * 0.4 + 5, top + 11), Color(0.3, 0.3, 0.25), 0.4)
			draw_line(Vector2(-tw * 0.4 + 5, top + 6), Vector2(-tw * 0.4, top + 11), Color(0.3, 0.3, 0.25), 0.4)
			# remendo 2
			draw_rect(Rect2(tw * 0.1, top + torso_h - 8, 4, 4), patch2)
			draw_line(Vector2(tw * 0.1, top + torso_h - 6), Vector2(tw * 0.1 + 4, top + torso_h - 6), Color(0.35, 0.25, 0.2), 0.4)

	# --- BRAÇOS com mãos ---
	var arm_c := body.darkened(0.12)
	var arm_swing_l := walk_phase * 3.0 if moving else 0.0
	var arm_swing_r := -walk_phase * 3.0 if moving else 0.0
	var arm_len := 13.0
	var arm_w := 3.5

	# braço esquerdo
	var al_top := top + 2
	var al_x := -tw - 1.5
	if id == "npc_smith":
		arm_w = 4.5  # braços musculosos
	draw_colored_polygon(PackedVector2Array([
		Vector2(al_x - arm_w * 0.5, al_top + arm_swing_l),
		Vector2(al_x + arm_w * 0.5, al_top + arm_swing_l),
		Vector2(al_x + arm_w * 0.4, al_top + arm_len + arm_swing_l),
		Vector2(al_x - arm_w * 0.4, al_top + arm_len + arm_swing_l)
	]), arm_c)
	# mão esquerda
	draw_circle(Vector2(al_x, al_top + arm_len + 1.5 + arm_swing_l), 2.0, skin)

	# braço direito
	var ar_x := tw + 1.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(ar_x - arm_w * 0.5, al_top + arm_swing_r),
		Vector2(ar_x + arm_w * 0.5, al_top + arm_swing_r),
		Vector2(ar_x + arm_w * 0.4, al_top + arm_len + arm_swing_r),
		Vector2(ar_x - arm_w * 0.4, al_top + arm_len + arm_swing_r)
	]), arm_c)
	# mão direita
	draw_circle(Vector2(ar_x, al_top + arm_len + 1.5 + arm_swing_r), 2.0, skin)

	# adereço de mão para NPCs específicos
	match id:
		"npc_king":
			# cetro na mão direita
			var scepter_base := al_top + arm_len + 1.5 + arm_swing_r
			draw_line(Vector2(ar_x, scepter_base), Vector2(ar_x, scepter_base - 20), Color(0.75, 0.65, 0.15), 1.5)
			draw_circle(Vector2(ar_x, scepter_base - 21), 2.5, Color(0.85, 0.2, 0.2))
			draw_circle(Vector2(ar_x, scepter_base - 21), 2.5, Color(0.95, 0.8, 0.2), false, 0.6)
		"npc_merchant":
			# cajado / bastão de caminhada
			var stick_base := al_top + arm_len + 1.5 + arm_swing_l
			draw_line(Vector2(al_x, stick_base), Vector2(al_x - 2, stick_base + 14), Color(0.5, 0.38, 0.2), 1.8)
		"npc_guard":
			# escudo no braço esquerdo (mais visível)
			var shield_y := al_top + 4 + arm_swing_l
			draw_colored_polygon(PackedVector2Array([
				Vector2(al_x - 4, shield_y), Vector2(al_x + 2, shield_y),
				Vector2(al_x + 2, shield_y + 8), Vector2(al_x - 1, shield_y + 10),
				Vector2(al_x - 4, shield_y + 8)
			]), Color(0.55, 0.15, 0.12))
			draw_polyline(PackedVector2Array([
				Vector2(al_x - 4, shield_y), Vector2(al_x + 2, shield_y),
				Vector2(al_x + 2, shield_y + 8), Vector2(al_x - 1, shield_y + 10),
				Vector2(al_x - 4, shield_y + 8), Vector2(al_x - 4, shield_y)
			]), Color(0.7, 0.65, 0.2), 0.8)

	# --- CABEÇA ---
	var head := Vector2(0, top - 6.0)
	# orelhas
	draw_circle(head + Vector2(-8.5, 1), 2.5, skin)
	draw_circle(head + Vector2(-8.5, 1), 2.5, skin.darkened(0.15), false, 0.5)
	draw_circle(head + Vector2(8.5, 1), 2.5, skin)
	draw_circle(head + Vector2(8.5, 1), 2.5, skin.darkened(0.15), false, 0.5)
	# cabeça principal (mais oval)
	draw_circle(head, 8.5, skin)
	draw_circle(head, 8.5, outline, false, 0.6)
	# bochechas (rubor sutil)
	draw_circle(head + Vector2(-4, 2.5), 2.0, Color(0.9, 0.55, 0.5, 0.2))
	draw_circle(head + Vector2(5, 2.5), 2.0, Color(0.9, 0.55, 0.5, 0.2))
	# olhos — dois olhos estilo Pokémon
	var eye_c := Color(0.08, 0.08, 0.12)
	draw_circle(head + Vector2(-3.0, -1.0), 1.5, Color(0.95, 0.95, 1.0))  # esclerótica esq
	draw_circle(head + Vector2(-3.0, -1.0), 1.0, eye_c)  # pupila esq
	draw_circle(head + Vector2(-3.5, -1.8), 0.5, Color(1, 1, 1))  # brilho esq
	draw_circle(head + Vector2(3.5, -1.0), 1.5, Color(0.95, 0.95, 1.0))  # esclerótica dir
	draw_circle(head + Vector2(3.5, -1.0), 1.0, eye_c)  # pupila dir
	draw_circle(head + Vector2(3.0, -1.8), 0.5, Color(1, 1, 1))  # brilho dir
	# sobrancelhas sutis
	if mood_anger > 0.1:
		draw_line(head + Vector2(-4.5, -3.5), head + Vector2(-1.5, -3.0), outline, 0.8)
		draw_line(head + Vector2(2.0, -3.0), head + Vector2(5.0, -3.5), outline, 0.8)
	else:
		draw_line(head + Vector2(-4.5, -3.2), head + Vector2(-1.5, -3.2), Color(0.25, 0.2, 0.18), 0.6)
		draw_line(head + Vector2(2.0, -3.2), head + Vector2(5.0, -3.2), Color(0.25, 0.2, 0.18), 0.6)
	# nariz (ponto sutil)
	draw_circle(head + Vector2(0.5, 1.5), 0.7, skin.darkened(0.15))
	# boca (linha sutil)
	if mood_fear > 0.3:
		draw_arc(head + Vector2(0.5, 3.5), 2.0, 0.2, PI - 0.2, 4, Color(0.4, 0.2, 0.2), 0.6)
	elif mood_anger > 0.3:
		draw_line(head + Vector2(-2, 3.5), head + Vector2(3, 3.5), Color(0.4, 0.2, 0.2), 0.7)
	else:
		draw_arc(head + Vector2(0.5, 2.5), 2.0, 0.3, PI - 0.3, 4, Color(0.55, 0.35, 0.3), 0.5)

	# chapéu / cabelo
	_draw_hat(head)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# nome
	var font := ThemeDB.fallback_font
	if world and world.show_names:
		draw_string(font, Vector2(-40, 12), def.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 1, 1, 0.75))
	# emote
	if emote_t > 0.0:
		var ey := -h - 14.0 - (sin(t * 6.0) * 2.0)
		draw_string(font, Vector2(-30, ey), emote, HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(1.0, 0.9, 0.3))
	# balão
	if bubble_t > 0.0 and bubble != "":
		var bw := 150.0
		var lines := int(ceil(bubble.length() / 22.0))
		var bh := 8.0 + lines * 14.0
		var bp := Vector2(-bw / 2.0, -h - 20.0 - bh)
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.05, 0.07, 0.1, 0.9))
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.9, 0.9, 0.7), false, 1.0)
		draw_multiline_string(font, bp + Vector2(6, 14), bubble, HORIZONTAL_ALIGNMENT_LEFT, bw - 12, 11, 8, Color(1, 1, 0.9))


func _draw_hat(head: Vector2) -> void:
	var outline := Color(0.08, 0.06, 0.05)
	match def.hat:
		"crown":
			# coroa detalhada com gemas
			var gold := Color(1.0, 0.82, 0.2)
			var gold_d := Color(0.85, 0.68, 0.12)
			var gold_h := Color(1.0, 0.92, 0.55)
			# base da coroa
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 8, head.y - 7), Vector2(head.x + 8, head.y - 7),
				Vector2(head.x + 9, head.y - 12), Vector2(head.x - 9, head.y - 12)
			]), gold)
			# faixa decorativa na base
			draw_rect(Rect2(head.x - 8.5, head.y - 9, 17, 2), gold_d)
			# pontas da coroa (5 pontas)
			for i in 5:
				var px := head.x - 8 + i * 4
				draw_colored_polygon(PackedVector2Array([
					Vector2(px - 1, head.y - 12), Vector2(px + 2.5, head.y - 12),
					Vector2(px + 0.75, head.y - 17 - (1 if i == 2 else 0))
				]), gold)
			# gemas (rubi central, safiras laterais)
			draw_circle(Vector2(head.x, head.y - 10), 1.5, Color(0.85, 0.12, 0.15))
			draw_circle(Vector2(head.x, head.y - 10), 1.5, Color(0.95, 0.3, 0.3), false, 0.4)
			draw_circle(Vector2(head.x - 4, head.y - 10), 1.0, Color(0.2, 0.35, 0.85))
			draw_circle(Vector2(head.x + 4, head.y - 10), 1.0, Color(0.2, 0.35, 0.85))
			# brilho metálico
			draw_line(Vector2(head.x - 6, head.y - 12), Vector2(head.x - 4, head.y - 12), gold_h, 0.6)
			# contorno
			draw_polyline(PackedVector2Array([
				Vector2(head.x - 8, head.y - 7), Vector2(head.x + 8, head.y - 7),
				Vector2(head.x + 9, head.y - 12), Vector2(head.x - 9, head.y - 12), Vector2(head.x - 8, head.y - 7)
			]), outline, 0.6)
		"cap_blue":
			# chapéu de chef (toque) — gordo e fofo
			var cap := Color(0.95, 0.95, 0.98)
			var cap_s := Color(0.85, 0.85, 0.9)
			# aba inferior
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 9, head.y - 7), Vector2(head.x + 9, head.y - 7),
				Vector2(head.x + 8, head.y - 10), Vector2(head.x - 8, head.y - 10)
			]), cap_s)
			# corpo do chapéu (puffs arredondados)
			draw_circle(Vector2(head.x - 3, head.y - 15), 6.0, cap)
			draw_circle(Vector2(head.x + 3, head.y - 15), 6.0, cap)
			draw_circle(Vector2(head.x, head.y - 17), 5.5, cap)
			# contorno suave
			draw_arc(Vector2(head.x, head.y - 15), 8.0, -PI * 0.9, -PI * 0.1, 10, outline, 0.5)
			# faixa na base
			draw_rect(Rect2(head.x - 8, head.y - 10, 16, 2.5), Color(0.2, 0.4, 0.85))
		"helm":
			# capacete de guarda com viseira
			var metal := Color(0.58, 0.6, 0.68)
			var metal_h := Color(0.72, 0.74, 0.82)
			var metal_d := Color(0.42, 0.44, 0.5)
			# calota do capacete
			draw_arc(head, 9.5, -PI, 0, 14, metal, 9.5, true)
			# brilho no capacete
			draw_arc(head + Vector2(-2, 0), 7.0, -PI * 0.8, -PI * 0.3, 6, metal_h, 1.5)
			# borda inferior
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 10, head.y - 1), Vector2(head.x + 10, head.y - 1),
				Vector2(head.x + 10.5, head.y + 1), Vector2(head.x - 10.5, head.y + 1)
			]), metal_d)
			# viseira (proteção facial)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x + 5, head.y - 2), Vector2(head.x + 12, head.y + 0),
				Vector2(head.x + 11, head.y + 3), Vector2(head.x + 5, head.y + 2)
			]), metal_d)
			# fenda da viseira
			draw_line(Vector2(head.x + 6, head.y + 0.5), Vector2(head.x + 10.5, head.y + 1), Color(0.15, 0.12, 0.1), 0.8)
			# crista no topo (pluma)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 1, head.y - 9), Vector2(head.x + 1, head.y - 9),
				Vector2(head.x + 2, head.y - 14), Vector2(head.x - 2, head.y - 13)
			]), Color(0.7, 0.2, 0.15))
			# contorno
			draw_arc(head, 9.5, -PI, 0, 14, outline, 0.6)
		"hair_dark":
			# cabelo escuro do ferreiro — curto, bagunçado e grosso
			var hair := Color(0.15, 0.1, 0.06)
			var hair_h := Color(0.25, 0.18, 0.12)
			# base do cabelo
			draw_arc(head, 9.0, -PI, -0.1, 12, hair, 4.0, true)
			# textura — mechas
			draw_line(head + Vector2(-6, -7), head + Vector2(-7, -11), hair_h, 1.5)
			draw_line(head + Vector2(-2, -8), head + Vector2(-3, -12), hair_h, 1.5)
			draw_line(head + Vector2(2, -8), head + Vector2(1, -12), hair_h, 1.2)
			draw_line(head + Vector2(5, -7), head + Vector2(5, -11), hair_h, 1.5)
			# costeletas / lateral
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 8.5, head.y - 3), Vector2(head.x - 7, head.y - 3),
				Vector2(head.x - 7, head.y + 3), Vector2(head.x - 8.5, head.y + 2)
			]), hair)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x + 7, head.y - 3), Vector2(head.x + 8.5, head.y - 3),
				Vector2(head.x + 8.5, head.y + 2), Vector2(head.x + 7, head.y + 3)
			]), hair)
		"hair_bun":
			# cabelo castanho da sacerdotisa com coque
			var hair := Color(0.38, 0.24, 0.14)
			var hair_h := Color(0.5, 0.34, 0.2)
			# base do cabelo — franja
			draw_arc(head + Vector2(0, -1), 9.0, -PI, -0.2, 12, hair, 3.5, true)
			# franja lateral suave
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 7, head.y - 6), Vector2(head.x - 3, head.y - 7),
				Vector2(head.x - 2, head.y - 4), Vector2(head.x - 6, head.y - 2)
			]), hair)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x + 3, head.y - 7), Vector2(head.x + 7, head.y - 6),
				Vector2(head.x + 6, head.y - 2), Vector2(head.x + 2, head.y - 4)
			]), hair)
			# coque (mais detalhado)
			draw_circle(head + Vector2(-5, -11), 4.5, hair)
			draw_circle(head + Vector2(-5, -11), 4.5, hair.darkened(0.2), false, 0.6)
			# brilho no coque
			draw_circle(head + Vector2(-6, -12.5), 1.2, hair_h)
			# prendedor do coque
			draw_circle(head + Vector2(-5, -11), 1.0, Color(0.7, 0.6, 0.2))
			# mechas que caem
			draw_line(head + Vector2(-8, head.y * 0 - 2), head + Vector2(-9, head.y * 0 + 4), hair, 1.2)
			draw_line(head + Vector2(7, head.y * 0 - 2), head + Vector2(8, head.y * 0 + 4), hair, 1.0)
		"wide":
			# chapéu de aba larga do mercador
			var hat_c := Color(0.5, 0.35, 0.15)
			var hat_h := Color(0.6, 0.45, 0.22)
			var hat_d := Color(0.38, 0.25, 0.1)
			# aba larga
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 16, head.y - 6), Vector2(head.x + 16, head.y - 6),
				Vector2(head.x + 15, head.y - 4), Vector2(head.x - 15, head.y - 4)
			]), hat_c)
			draw_line(Vector2(head.x - 15, head.y - 4), Vector2(head.x + 15, head.y - 4), hat_d, 0.6)
			# copa do chapéu (arredondada)
			draw_colored_polygon(PackedVector2Array([
				Vector2(head.x - 8, head.y - 6), Vector2(head.x + 8, head.y - 6),
				Vector2(head.x + 7, head.y - 11), Vector2(head.x + 4, head.y - 14),
				Vector2(head.x - 4, head.y - 14), Vector2(head.x - 7, head.y - 11)
			]), hat_c)
			# faixa decorativa
			draw_rect(Rect2(head.x - 8, head.y - 9, 16, 2.5), hat_d)
			# pena no chapéu
			draw_line(head + Vector2(6, -11), head + Vector2(10, -18), Color(0.7, 0.2, 0.15), 1.0)
			draw_line(head + Vector2(10, -18), head + Vector2(12, -16), Color(0.7, 0.2, 0.15), 0.8)
			# brilho
			draw_line(head + Vector2(-5, -12), head + Vector2(-3, -12), hat_h, 0.8)
			# contorno
			draw_polyline(PackedVector2Array([
				Vector2(head.x - 16, head.y - 6), Vector2(head.x + 16, head.y - 6),
				Vector2(head.x + 15, head.y - 4), Vector2(head.x - 15, head.y - 4), Vector2(head.x - 16, head.y - 6)
			]), outline, 0.5)
		"hair_messy":
			# cabelo desgrenhado da órfã (mais detalhado)
			var hair := Color(0.3, 0.18, 0.1)
			var hair_h := Color(0.42, 0.28, 0.16)
			# base do cabelo cobrindo o topo
			draw_arc(head + Vector2(0, -1), 9.0, -PI, 0, 12, hair, 3.0, true)
			# mechas espetadas em várias direções
			var strands := [
				[Vector2(-7, -6), Vector2(-10, -14)],
				[Vector2(-4, -8), Vector2(-6, -16)],
				[Vector2(-1, -8), Vector2(-1, -15)],
				[Vector2(2, -8), Vector2(4, -16)],
				[Vector2(5, -7), Vector2(8, -14)],
				[Vector2(7, -5), Vector2(11, -11)],
				[Vector2(-8, -4), Vector2(-12, -10)],
			]
			for s in strands:
				draw_line(head + s[0], head + s[1], hair, 2.0)
				draw_line(head + s[0] + Vector2(0.5, 0), head + s[1] + Vector2(0.8, -0.5), hair_h, 0.8)
			# fios soltos caindo
			draw_line(head + Vector2(-8, -2), head + Vector2(-10, 4), hair, 1.0)
			draw_line(head + Vector2(7, -2), head + Vector2(9, 3), hair, 0.8)
			# folha ou galho preso no cabelo (detalhe fofo)
			draw_line(head + Vector2(4, -14), head + Vector2(6, -15), Color(0.3, 0.5, 0.2), 0.8)
			draw_circle(head + Vector2(6.5, -15.5), 1.2, Color(0.35, 0.55, 0.25))
