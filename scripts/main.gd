extends Node
## Gerenciador de telas: abertura → menu → registro → briefing → jogo → fim.

const WorldScript := preload("res://scripts/world.gd")
const SettingsScript := preload("res://scripts/settings_panel.gd")

var ui_layer: CanvasLayer
var screen: Control
var world: Node2D
var flash_rect: ColorRect
var seq_id := 0
var menu_bg: MenuVillage


class ButterflyEffectLoading extends Control:
	var t := 0.0
	var progress := 0.0
	var current_msg := 0
	var messages := [
		"\"O bater de asas de uma borboleta...\"",
		"\"...pode causar um tufão no outro lado do mundo.\"",
		"Carregando simulação causal...",
		"Calculando instabilidade social...",
		"Iniciando Agência Panóptico..."
	]
	
	var title_lbl: Label
	var msg_lbl: Label
	
	func _ready() -> void:
		var tw = create_tween()
		tw.tween_property(self, "progress", 1.0, 8.0)
		
		var mt = Timer.new()
		mt.wait_time = 2.0
		mt.autostart = true
		mt.timeout.connect(func(): current_msg = mini(current_msg + 1, messages.size() - 1))
		add_child(mt)
		
		title_lbl = Label.new()
		title_lbl.text = "O PARADOXO DO ESTAGIÁRIO"
		title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		title_lbl.position = Vector2(0, 160)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 42)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		add_child(title_lbl)
		
		msg_lbl = Label.new()
		msg_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		msg_lbl.position = Vector2(0, 560)
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_lbl.add_theme_font_size_override("font_size", 20)
		add_child(msg_lbl)
		
	func _process(d: float) -> void:
		t += d
		
		if is_instance_valid(msg_lbl):
			msg_lbl.text = messages[current_msg]
			msg_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 0.6 + 0.4 * sin(t * 3.0)))
		
		queue_redraw()
		
	func _draw() -> void:
		var c = size / 2.0
		var bar_w = 700.0
		var bar_x = c.x - bar_w / 2.0
		var bar_y = c.y + 40.0
		
		# Barra base
		draw_rect(Rect2(bar_x - 4, bar_y - 4, bar_w + 8, 12), Color(0.1, 0.15, 0.2))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, 4), Color(0.4, 0.8, 1.0))
		
		# O Furacão (Movendo com o progresso e crescendo)
		var hurr_x = bar_x + bar_w * progress
		var hurr_size = 20.0 + progress * 160.0
		var hurr_steps = 8 + int(progress * 24.0)
		
		if progress > 0.02:
			for i in hurr_steps:
				var hp = float(i) / float(hurr_steps)
				var w = hurr_size * (0.15 + hp * 0.85)
				var hy = bar_y - hp * hurr_size * 1.2 + 5.0
				
				var off = sin(t * 18.0 + float(i)) * (hurr_size * 0.1)
				var rect_w = w + sin(t * 25.0 + float(i*2)) * 12.0
				
				var line_thick = 2.0 + progress * 5.0
				draw_line(Vector2(hurr_x + off - rect_w/2.0, hy), Vector2(hurr_x + off + rect_w/2.0, hy), Color(0.6, 0.75, 0.9, 0.5 + hp * 0.5), line_thick)
				draw_line(Vector2(hurr_x + off - rect_w/2.0 + 6.0, hy+2), Vector2(hurr_x + off + rect_w/2.0 - 6.0, hy+2), Color(0.9, 0.95, 1.0, 0.7 + hp * 0.3), line_thick * 0.6)
				
				# Folhas e poeira
				for p_i in 2:
					var angle = t * 25.0 + float(i * 3 + p_i * 10)
					var px = hurr_x + cos(angle) * (w * 0.65)
					var py = hy + sin(angle) * 8.0
					var is_leaf = (i + p_i) % 3 == 0
					var p_col = Color(0.4, 0.8, 0.3) if is_leaf else Color(1.0, 1.0, 1.0, 0.8)
					var part_size = 2.0 + progress * 3.0
					draw_rect(Rect2(px, py, part_size, part_size), p_col)
					
		# A Borboleta Pixelada (Estática no início da barra, batendo as asas)
		var b_x = bar_x - 30.0
		var b_y = bar_y - 25.0 + sin(t * 8.0) * 5.0
		
		var flap = int(t * 14.0) % 4
		if flap == 3: flap = 1 # Animação: 0, 1, 2, 1
		
		var palette = {
			"y": Color(1.0, 0.85, 0.2),  # Amarelo principal
			"o": Color(1.0, 0.5, 0.1),   # Laranja detalhes
			"d": Color(0.8, 0.3, 0.1),   # Laranja escuro
			"w": Color(1.0, 1.0, 0.9),   # Branco brilho
			"b": Color(0.3, 0.15, 0.05), # Corpo marrom
			"a": Color(0.1, 0.05, 0.0)   # Antenas
		}
		
		var frames = [
			[ # 0 - abertas
				" a          a ",
				"  a        a  ",
				"  wyy    yyw  ",
				" yyyyo  oyyyy ",
				" dywyo  oywyd ",
				" yyyyoaaoyyyy ",
				"  yyyobboyyy  ",
				"  ydy bb ydy  ",
				"   y  bb  y   ",
				"      bb      "
			],
			[ # 1 - meio
				"              ",
				"  a        a  ",
				"   wyy  yyw   ",
				"  yyyyoooyyy  ",
				"  dywaaawyd   ",
				"   yyobboyy   ",
				"   yd bb dy   ",
				"      bb      ",
				"      bb      ",
				"              "
			],
			[ # 2 - fechadas
				"              ",
				"              ",
				"    a    a    ",
				"     y  y     ",
				"    ywaawy    ",
				"    yobboy    ",
				"     d  d     ",
				"      bb      ",
				"      bb      ",
				"              "
			]
		]
		
		var p_size = 4.0
		var frame_data = frames[flap]
		for row in frame_data.size():
			var line_str = frame_data[row]
			for col in line_str.length():
				var ch = line_str[col]
				if palette.has(ch):
					draw_rect(Rect2(b_x + col * p_size, b_y + row * p_size, p_size, p_size), palette[ch])


class MenuBtn extends Button:
	var hover_t := 0.0
	var glow_color := Color(1.0, 0.85, 0.35, 0.0)
	var base_glow := Color(1.0, 0.85, 0.35)

	func _init(txt: String, cb: Callable, glow := Color(1.0, 0.85, 0.35)) -> void:
		text = txt
		base_glow = glow
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(320, 48)
		add_theme_font_size_override("font_size", 18)
		add_theme_color_override("font_color", Color(0.65, 0.8, 0.7))
		add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
		add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		add_theme_color_override("font_disabled_color", Color(0.3, 0.35, 0.3))
		pressed.connect(func():
			Sfx.play("confirm")
			cb.call())
		mouse_entered.connect(func():
			Sfx.play("bip")
			var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(self, "hover_t", 1.0, 0.2))
		mouse_exited.connect(func():
			var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(self, "hover_t", 0.0, 0.3))

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg_a := 0.06 + hover_t * 0.12
		draw_rect(r, Color(0.1, 0.15, 0.2, bg_a))
		var border_a := 0.15 + hover_t * 0.55
		var bc := base_glow
		bc.a = border_a
		draw_rect(r, bc, false, 1.5)
		if hover_t > 0.01:
			var ga := hover_t * 0.08
			draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(bc.r, bc.g, bc.b, ga))
			var arrow_x := 14.0 * hover_t
			var ac := Color(1.0, 0.9, 0.4, hover_t * 0.8)
			var cy := size.y / 2.0
			draw_line(Vector2(8, cy), Vector2(8 + arrow_x, cy), ac, 2.0)
			draw_line(Vector2(8 + arrow_x, cy), Vector2(4 + arrow_x, cy - 4), ac, 2.0)
			draw_line(Vector2(8 + arrow_x, cy), Vector2(4 + arrow_x, cy + 4), ac, 2.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.load_settings()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	# scanlines
	var scan_layer := CanvasLayer.new()
	scan_layer.layer = 100
	add_child(scan_layer)
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float l = mod(FRAGCOORD.y, 3.0) < 1.0 ? 0.07 : 0.0; COLOR = vec4(0.0, 0.0, 0.0, l); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	scan.material = mat
	scan_layer.add_child(scan)
	var fl := CanvasLayer.new()
	fl.layer = 101
	add_child(fl)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(flash_rect)
	show_loading()


func _unhandled_input(event: InputEvent) -> void:
	# atalho de desenvolvimento: Home pula direto para o jogo (sem tutorial)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_HOME and world == null:
		Game.reset()
		start_game(false)


# ---------------------------------------------------------------- utilidades
func _new_screen() -> Control:
	seq_id += 1
	if screen:
		screen.queue_free()
	if world:
		world.queue_free()
		world = null
	get_tree().paused = false
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.theme = Game.ui_theme
	ui_layer.add_child(screen)
	return screen


func _flash(dur := 0.35) -> void:
	flash_rect.color = Color(1, 1, 1, 1)
	create_tween().tween_property(flash_rect, "color:a", 0.0, dur)


func _lbl(parent: Control, text: String, size: int, col: Color, pos := Vector2.ZERO, w := 1280.0, center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 40)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("confirm")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("bip"))
	parent.add_child(b)
	return b


func _bg(parent: Control, col := Color.BLACK) -> void:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _type(label: Label, text: String, cps := 45.0) -> void:
	label.text = text
	label.visible_characters = 0
	var my := seq_id
	var tw := create_tween()
	tw.tween_method(func(v):
		if is_instance_valid(label): label.visible_characters = int(v), 0.0, float(text.length()), text.length() / cps)
	await tw.finished
	if my == seq_id and is_instance_valid(label):
		label.visible_characters = -1


func _wait(sec: float) -> bool:
	## Espera cancelável: retorna false se a tela mudou durante a espera.
	var my := seq_id
	await get_tree().create_timer(sec).timeout
	return my == seq_id


func _menu_backdrop() -> void:
	## Fundo vivo do menu: a própria aldeia em pixel art, à noite.
	if menu_bg == null:
		menu_bg = MenuVillage.new()
		add_child(menu_bg)
		move_child(menu_bg, 0)


func _clear_menu_backdrop() -> void:
	if menu_bg:
		menu_bg.queue_free()
		menu_bg = null


# ---------------------------------------------------------------- telas
func show_loading() -> void:
	var s := _new_screen()
	_menu_backdrop()
	
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	s.add_child(dim)
	
	var anim := ButterflyEffectLoading.new()
	anim.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(anim)
	
	var my := seq_id
	var timer := 0.0
	while timer < 8.5 and my == seq_id:
		timer += 0.1
		await get_tree().create_timer(0.1).timeout
		
	if my == seq_id:
		_flash()
		show_menu()


func show_menu() -> void:
	var s := _new_screen()
	_menu_backdrop()
	var vign := ColorRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh := Shader.new()
	vsh.code = "shader_type canvas_item;\nvoid fragment(){\n\tfloat cx = 1.0 - smoothstep(0.12, 0.42, abs(UV.x - 0.5));\n\tfloat top = 1.0 - smoothstep(0.0, 0.7, UV.y);\n\tCOLOR = vec4(0.02, 0.02, 0.06, 0.22 + 0.45 * cx + 0.25 * top);\n}"
	var vmat := ShaderMaterial.new()
	vmat.shader = vsh
	vign.material = vmat
	s.add_child(vign)
	# glow behind title
	var glow := ColorRect.new()
	glow.position = Vector2(240, 20)
	glow.size = Vector2(800, 180)
	glow.color = Color(0, 0, 0, 0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_sh := Shader.new()
	glow_sh.code = "shader_type canvas_item;\nuniform float time;\nvoid fragment(){\n\tvec2 uv = UV - 0.5;\n\tfloat d = length(uv * vec2(1.0, 2.0));\n\tfloat a = smoothstep(0.5, 0.0, d) * (0.08 + 0.04 * sin(time * 1.5));\n\tCOLOR = vec4(1.0, 0.85, 0.35, a);\n}"
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_sh
	glow.material = glow_mat
	s.add_child(glow)
	var title_line1 := _lbl(s, "O   P A R A D O X O", 52, Color(1.0, 0.88, 0.38), Vector2(0, 40))
	title_line1.size = Vector2(1280, 60)
	var title_line2 := _lbl(s, "D O   E S T A G I Á R I O", 52, Color(1.0, 0.82, 0.3), Vector2(0, 100))
	title_line2.size = Vector2(1280, 60)
	var _sub := _lbl(s, "Agência Panóptico  //  ID do Operador: %s" % (Game.player_name if Game.player_name != "ESTAGIARIO" else "[não registrado]"), 13, Color(0.5, 0.75, 0.6, 0.8), Vector2(0, 172))
	var line := ColorRect.new()
	line.position = Vector2(440, 195)
	line.size = Vector2(400, 1)
	line.color = Color(0.5, 0.75, 0.6, 0.3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(line)
	var box := VBoxContainer.new()
	box.position = Vector2(480, 218)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 6)
	s.add_child(box)
	var b_start := MenuBtn.new("INICIAR MISSÃO", func():
		_flash()
		show_name_entry())
	box.add_child(b_start)
	var b_load := MenuBtn.new("CARREGAR ARQUIVOS", func():
		if Game.load_game():
			_flash()
			start_game(false), Color(0.5, 0.8, 1.0))
	b_load.disabled = not Game.has_save()
	box.add_child(b_load)
	var b_cfg := MenuBtn.new("CONFIGURAÇÕES", func():
		var sp := SettingsScript.new()
		sp.position = Vector2(400, 160)
		sp.closed.connect(sp.queue_free)
		s.add_child(sp), Color(0.7, 0.8, 0.7))
	box.add_child(b_cfg)
	var b_cred := MenuBtn.new("CRÉDITOS", show_credits, Color(0.7, 0.8, 0.7))
	box.add_child(b_cred)
	var b_quit := MenuBtn.new("SAIR", func(): get_tree().quit(), Color(0.8, 0.4, 0.4))
	box.add_child(b_quit)
	# version tag
	_lbl(s, "Game Jam CIMATEC 2026.2  |  Tema: Efeito Borboleta", 11, Color(0.4, 0.55, 0.45, 0.5), Vector2(0, 690))
	# animate title shimmer
	var my := seq_id
	var shimmer_t := 0.0
	while my == seq_id:
		shimmer_t += 0.03
		var pulse := 0.85 + 0.15 * sin(shimmer_t * 1.2)
		title_line1.modulate = Color(pulse, pulse * 0.95, pulse * 0.8)
		title_line2.modulate = Color(pulse * 0.95, pulse * 0.88, pulse * 0.7)
		if is_instance_valid(glow) and glow.material:
			(glow.material as ShaderMaterial).set_shader_parameter("time", shimmer_t)
		await get_tree().create_timer(0.03).timeout


func show_name_entry() -> void:
	var s := _new_screen()
	_bg(s, Color(0.02, 0.03, 0.05))
	var l := _lbl(s, "", 20, Color(0.6, 1.0, 0.75), Vector2(300, 240), 700.0, false)
	_type(l, "AGÊNCIA PANÓPTICO // SISTEMA DE REGISTRO\nInsira seu ID de Operador:")
	var le := LineEdit.new()
	le.position = Vector2(300, 340)
	le.size = Vector2(400, 40)
	le.max_length = 12
	le.placeholder_text = "> _"
	le.text_changed.connect(func(_t): Sfx.play("clack"))
	s.add_child(le)
	le.call_deferred("grab_focus")
	le.text_submitted.connect(func(t: String):
		var nm := t.strip_edges()
		if nm == "":
			nm = "ESTAGIARIO"
		Game.player_name = nm.to_upper()
		Sfx.play("confirm")
		le.editable = false
		l.text = "ID registrado. Bem-vindo, %s.\nPreparando portal dimensional..." % Game.player_name
		l.visible_characters = -1
		if await _wait(2.2):
			_flash()
			Game.reset()
			start_game(true))


func start_game(new_game: bool) -> void:
	_new_screen()
	_clear_menu_backdrop()
	screen.queue_free()
	screen = null
	world = WorldScript.new()
	world.tutorial = new_game
	world.victory.connect(show_victory)
	world.defeat.connect(show_defeat)
	world.quit_to_menu.connect(func():
		_flash()
		show_menu())
	add_child(world)


func show_credits() -> void:
	var s := _new_screen()
	_bg(s)
	var chars := "01ABCDEF{}[]<>=;:/#$%"
	var side_l := _lbl(s, "", 12, Color(0.2, 0.7, 0.4, 0.5), Vector2(20, 0), 200.0, false)
	var side_r := _lbl(s, "", 12, Color(0.2, 0.7, 0.4, 0.5), Vector2(1060, 0), 200.0, false)
	var credits := "O PARADOXO DO ESTAGIÁRIO\nGame Jam CIMATEC 2026.2 — Tema: Efeito Borboleta\n\n\nDESENVOLVIDO POR\nThales — Backend / IA / Integração\nEduardo — Engine / Gameplay\nDanilo — UI / Assets\n\n\nMOTOR IA\nGemini (Google) — integração via backend\n\n\nENGINE\nGodot 4.x\n\n\nASSETS\nTiny Town — Kenney (kenney.nl, CC0)\nPersonagens, castelo, árvores e animações:\npixel art própria no estilo Kenney\n\n\nAGRADECIMENTOS\nCIMATEC · Game Jam 2026.2\n\n\n> rm -rf /linha_do_tempo\n> ...\n> Anomalia removida."
	var cl := _lbl(s, credits, 20, Color(0.75, 1.0, 0.85), Vector2(340, 720), 600.0)
	cl.size = Vector2(600, 900)
	_btn(s, "[ VOLTAR ]", show_menu).position = Vector2(20, 660)
	var my := seq_id
	var tw := create_tween()
	tw.tween_property(cl, "position:y", -700.0, 26.0)
	tw.finished.connect(func():
		if my == seq_id:
			show_menu())
	while my == seq_id:
		var a := ""
		var b := ""
		for r in 45:
			for i in 12:
				a += chars[randi() % chars.length()]
				b += chars[randi() % chars.length()]
			a += "\n"
			b += "\n"
		side_l.text = a
		side_r.text = b
		await get_tree().create_timer(0.15).timeout


func show_defeat() -> void:
	var s := _new_screen()
	_bg(s)
	var l := _lbl(s, "", 22, Color(1.0, 0.5, 0.45), Vector2(240, 200), 800.0)
	Sfx.play("horn")
	_type(l, "ANOMALIA NÃO CONTIDA.\nDEMISSÃO DO ESTAGIÁRIO\n\nOperador %s, a missão fracassou.\nO Rei permanece no trono." % Game.player_name, 40.0)
	if not await _wait(6.0):
		return
	var box := HBoxContainer.new()
	box.position = Vector2(400, 520)
	s.add_child(box)
	_btn(box, "[ TENTAR NOVAMENTE ]", func():
		Game.reset()
		_flash()
		start_game(false))
	_btn(box, "[ MENU PRINCIPAL ]", show_menu)


func show_victory() -> void:
	var s := _new_screen()
	_bg(s, Color(1, 1, 1))
	_flash(1.0)
	Sfx.play("horn")
	var l := _lbl(s, "", 22, Color(0.7, 1.0, 0.85), Vector2(190, 200), 900.0)
	var bg := s.get_child(0) as ColorRect
	create_tween().tween_property(bg, "color", Color.BLACK, 1.0)
	if not await _wait(1.0):
		return
	_type(l, "\"Missão cumprida, Operador %s. Anomalia neutralizada. Parabéns. A linha do tempo foi... protegida.\"\n\n...Preparando seu próximo destino." % Game.player_name, 38.0)
	if not await _wait(9.0):
		return
	l.text = ""
	_type(l, "MISSÃO CONCLUÍDA\nO Rei foi deposto.\nEfeito Borboleta atingido.\nA linha do tempo está... protegida?", 30.0)
	if not await _wait(6.0):
		return
	# --- plot twist
	_flash(0.3)
	l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	l.text = "[ESTÁTICA]  ...  [ERRO NO SISTEMA]"
	l.visible_characters = -1
	Sfx.play("error")
	if not await _wait(2.0):
		return
	l.text = ""
	_type(l, "\"Operador. Se você está ouvindo isto, chegou ao fim da primeira missão. Preciso que saiba a verdade sobre a Agência Panóptico.\n\nO Rei Aldemar I não era uma anomalia. Ele ia unificar estes reinos e iniciar a maior era de paz que este mundo conheceria. A Agência o eliminou. E você foi a ferramenta.\n\nA cientista da Fase 2 vai libertar a humanidade da tirania corporativa. A colônia em Marte, na Fase 3, é a primeira aliança pacífica entre espécies. Todas as suas missões são assassinatos. A Agência não protege a linha do tempo. Ela a controla.\"", 34.0)
	if not await _wait(19.0):
		return
	_flash(0.3)
	l.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	l.text = ""
	_type(l, "O Diretor: \"Conexão não autorizada encerrada. Operador, desconsidere os erros do sistema. Preparando próxima missão.\"", 40.0)
	if not await _wait(5.0):
		return
	# --- teaser
	for card in ["Metrópole Global — 2142\nArranha-céus, chuva de código, uma cientista em laboratório holográfico.", "Colônia Ares-7 — 3050\nUm domo em Marte. Humanos e alienígenas na mesma sala de reunião.", "Sede da Agência Panóptico\nServidores infinitos, portais dimensionais, o ícone do Diretor pulsando."]:
		_flash(0.25)
		l.text = card
		l.visible_characters = -1
		Sfx.play("whoosh")
		if not await _wait(3.4):
			return
	_flash(0.3)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	l.text = "O efeito borboleta não acabou."
	if not await _wait(3.5):
		return
	l.visible = false
	var box := VBoxContainer.new()
	box.position = Vector2(480, 300)
	s.add_child(box)
	var next := _btn(box, "[ PRÓXIMA MISSÃO (EM BREVE) ]", func(): pass)
	next.disabled = true
	_btn(box, "[ MENU PRINCIPAL ]", show_menu)
	_btn(box, "[ JOGAR NOVAMENTE ]", func():
		Game.reset()
		_flash()
		start_game(false))
