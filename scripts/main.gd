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


class RegistroScreen extends Control:
	signal done

	const I_DIR := "res://assets/gen/intro/"
	const PX := 4.0
	const I_PANEL := Rect2(36, 6, 248, 94)
	const CYAN := Color("7ff6ff")

	enum St { BOOT, INPUT, CLOSING, DONE }
	var _st := St.BOOT
	var _t := 0.0
	var _bay_frame := 0
	var _nudge := 0.0

	var _bg_rect: ColorRect
	var _bay: TextureRect
	var _beam: TextureRect
	var _holo: Control
	var _arm_root: Control
	var _scr: TextureRect
	var _hand: TextureRect
	var _fade: ColorRect
	var _htw: Tween
	var _le: LineEdit
	var _hdr: Label
	var _prompt_lbl: Label
	var _hint: Label
	var _status: Label
	var _scan: ColorRect

	func _ready() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_STOP
		_mk_space_bg()
		_bay = _lay(_atl("bay.png", 0), self)
		_bay.modulate = Color(1, 1, 1, 0.45)
		_beam = _lay(_atl("holo_beam.png", 0), self)
		_beam.modulate.a = 0.0
		_build_holo()
		_arm_root = Control.new()
		_arm_root.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_arm_root)
		_lay(load(I_DIR + "arm_left.png"), _arm_root)
		_scr = _lay(_atl("device_screen.png", 0), _arm_root)
		_hand = _lay(load(I_DIR + "hand_right.png"), self)
		_hand.position = _hrest()
		_fade = ColorRect.new()
		_fade.color = Color.WHITE
		_fade.set_anchors_preset(PRESET_FULL_RECT)
		_fade.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_fade)
		_boot()

	func _mk_space_bg() -> void:
		_bg_rect = ColorRect.new()
		_bg_rect.set_anchors_preset(PRESET_FULL_RECT)
		_bg_rect.mouse_filter = MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float time;\nfloat hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}\nvoid fragment(){\n\tvec2 uv=UV;vec3 c=vec3(0.012,0.016,0.035);\n\tc+=vec3(0.04,0.015,0.06)*smoothstep(0.55,0.0,length(uv-vec2(0.15,0.25)));\n\tc+=vec3(0.01,0.035,0.06)*smoothstep(0.5,0.0,length(uv-vec2(0.85,0.15)));\n\tc+=vec3(0.02,0.01,0.04)*smoothstep(0.6,0.0,length(uv-vec2(0.5,0.75)));\n\tfor(float s=50.0;s<=90.0;s+=40.0){\n\t\tvec2 g=floor(uv*s);float h=hash(g);\n\t\tif(h>0.92){\n\t\t\tvec2 ct=(g+0.5)/s;float d=length(uv-ct)*s;\n\t\t\tfloat b=smoothstep(0.5,0.0,d)*(0.4+0.6*max(sin(time*(0.8+h*2.5)+h*6.28),0.0));\n\t\t\tc+=b*mix(vec3(0.7,0.8,1.0),vec3(0.5,1.0,0.95),h);\n\t\t}\n\t}\n\tfloat period=3.5;float tt=mod(time,period)/period;float seed=floor(time/period);\n\tvec2 st=vec2(hash(vec2(seed,0.0)),hash(vec2(seed,1.0))*0.4);\n\tvec2 vel=vec2(0.25+hash(vec2(seed,2.0))*0.15,0.07);\n\tvec2 pos=st+vel*tt;vec2 dir=normalize(vel);vec2 dp=uv-pos;\n\tfloat behind=-dot(dp,dir);float cl=clamp(behind,0.0,0.04);\n\tfloat dist=length(dp+dir*cl);\n\tfloat b2=smoothstep(0.003,0.0,dist)*(1.0-cl/0.04);\n\tc+=vec3(0.9,0.95,1.0)*b2*(1.0-smoothstep(0.0,0.7,tt))*step(tt,0.7);\n\tCOLOR=vec4(c,1.0);\n}"
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_bg_rect.material = mat
		add_child(_bg_rect)

	func _boot() -> void:
		_arm_root.position.y = 720.0
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, 0.8)
		await tw.finished
		if _st != St.BOOT:
			return
		Sfx.play("whoosh")
		tw = create_tween()
		tw.tween_property(_arm_root, "position:y", 0.0, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		if _st != St.BOOT:
			return
		_tap()
		await get_tree().create_timer(0.12).timeout
		if _st != St.BOOT:
			return
		Sfx.play("bip")
		for i in 6:
			_sscr(1 if i % 2 == 0 else 0)
			await get_tree().create_timer(0.06).timeout
		if _st != St.BOOT:
			return
		_sscr(2)
		Sfx.play("portal_open")
		tw = create_tween()
		tw.tween_property(_beam, "modulate:a", 1.0, 0.18)
		tw.tween_property(_holo, "scale:y", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_holo, "modulate:a", 1.0, 0.2)
		await tw.finished
		if _st != St.BOOT:
			return
		_hdr.visible_characters = 0
		tw = create_tween()
		tw.tween_method(func(v):
			if is_instance_valid(_hdr):
				_hdr.visible_characters = int(v), 0.0, float(_hdr.text.length()), 0.5)
		await tw.finished
		if _st != St.BOOT:
			return
		_hdr.visible_characters = -1
		_prompt_lbl.visible_characters = 0
		tw = create_tween()
		tw.tween_method(func(v):
			if is_instance_valid(_prompt_lbl):
				_prompt_lbl.visible_characters = int(v), 0.0, float(_prompt_lbl.text.length()), 0.45)
		await tw.finished
		if _st != St.BOOT:
			return
		_prompt_lbl.visible_characters = -1
		_st = St.INPUT
		_le.visible = true
		_le.call_deferred("grab_focus")
		_hint.visible = true
		_status.visible = true
		_scan.visible = true
		var x0 := I_PANEL.position.x * PX
		var y0 := I_PANEL.position.y * PX
		var h := I_PANEL.size.y * PX
		var stw := create_tween().set_loops()
		stw.tween_property(_scan, "position:y", y0 + h - 50.0, 2.5)
		stw.tween_property(_scan, "position:y", y0 + 60.0, 2.5)

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(_bg_rect) and _bg_rect.material:
			(_bg_rect.material as ShaderMaterial).set_shader_parameter("time", _t)
		if is_instance_valid(_bay):
			var bf := int(_t * 7.0) % 4
			if bf != _bay_frame:
				_bay_frame = bf
				(_bay.texture as AtlasTexture).region.position.x = bf * 320
		if is_instance_valid(_beam) and _beam.modulate.a > 0:
			(_beam.texture as AtlasTexture).region.position.x = (int(_t * 11.0) % 3) * 320
		_nudge = move_toward(_nudge, 0.0, delta * 30.0)
		if _st == St.INPUT and is_instance_valid(_arm_root):
			_arm_root.position.y = (roundf(sin(_t * 1.7)) + roundf(_nudge)) * PX
			if is_instance_valid(_holo):
				_holo.modulate.a = 0.92 + 0.08 * sin(_t * 23.0) * sin(_t * 3.1)
			_sscr(2 + (int(_t * 8.0) % 2))

	func _input(event: InputEvent) -> void:
		if _st == St.DONE or _st == St.CLOSING:
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_do_submit("")

	func _do_submit(text: String) -> void:
		if _st == St.CLOSING or _st == St.DONE:
			return
		_st = St.CLOSING
		var nm := text.strip_edges()
		if nm == "":
			nm = "ESTAGIARIO"
		Game.player_name = nm.to_upper()
		Sfx.play("confirm")
		if is_instance_valid(_le):
			_le.editable = false
		_prompt_lbl.text = "ID registrado. Bem-vindo, %s." % Game.player_name
		_prompt_lbl.visible_characters = -1
		_hint.text = "Preparando portal dimensional..."
		await get_tree().create_timer(1.8).timeout
		if _st != St.CLOSING:
			return
		Sfx.play("whoosh")
		var tw := create_tween()
		tw.tween_property(_holo, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_beam, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func(): _sscr(0))
		tw.tween_property(_arm_root, "position:y", 720.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play("whoosh"))
		tw.tween_property(_bay, "modulate", Color(2, 2.5, 2.8, 0.6), 0.35)
		tw.parallel().tween_property(_fade, "color", Color(1, 1, 1, 1), 0.35)
		await tw.finished
		_st = St.DONE
		done.emit()

	func _build_holo() -> void:
		_holo = Control.new()
		_holo.size = Vector2(1280, 720)
		_holo.pivot_offset = Vector2(640, I_PANEL.end.y * PX)
		_holo.scale.y = 0.0
		_holo.modulate.a = 0.0
		_holo.mouse_filter = MOUSE_FILTER_PASS
		add_child(_holo)
		_lay(load(I_DIR + "holo_panel.png"), _holo)
		var font: Font = Game.ui_theme.default_font if Game.ui_theme else null
		var x0 := I_PANEL.position.x * PX
		var y0 := I_PANEL.position.y * PX
		var w := I_PANEL.size.x * PX
		var h := I_PANEL.size.y * PX
		_hdr = _mlbl(font, 15, CYAN)
		_hdr.text = "PANÓPTICO // SISTEMA DE REGISTRO"
		_hdr.position = Vector2(x0 + 60, y0 + 14)
		_holo.add_child(_hdr)
		_prompt_lbl = _mlbl(font, 20, Color("d8fbff"))
		_prompt_lbl.text = "Insira seu ID de Operador:"
		_prompt_lbl.position = Vector2(x0 + 44, y0 + 110)
		_prompt_lbl.size = Vector2(w - 88, 40)
		_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_holo.add_child(_prompt_lbl)
		_le = LineEdit.new()
		_le.position = Vector2(x0 + w / 2.0 - 220, y0 + 185)
		_le.size = Vector2(440, 50)
		_le.max_length = 12
		_le.placeholder_text = "> _"
		_le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_le.visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.015, 0.06, 0.08, 0.85)
		sb.border_color = Color(0.5, 0.96, 1.0, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		_le.add_theme_stylebox_override("normal", sb)
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = Color(0.02, 0.08, 0.12, 0.9)
		sbf.border_color = CYAN
		sbf.set_border_width_all(2)
		sbf.set_corner_radius_all(3)
		sbf.content_margin_left = 12
		sbf.content_margin_right = 12
		sbf.content_margin_top = 8
		sbf.content_margin_bottom = 8
		_le.add_theme_stylebox_override("focus", sbf)
		if font:
			_le.add_theme_font_override("font", font)
		_le.add_theme_font_size_override("font_size", 22)
		_le.add_theme_color_override("font_color", Color("d8fbff"))
		_le.add_theme_color_override("font_placeholder_color", Color(0.4, 0.7, 0.65, 0.4))
		_le.add_theme_color_override("caret_color", CYAN)
		_le.text_changed.connect(func(_txt): Sfx.play("clack"); _tap())
		_le.text_submitted.connect(_do_submit)
		_holo.add_child(_le)
		_hint = _mlbl(font, 13, Color(0.5, 0.85, 0.9, 0.5))
		_hint.text = "ENTER ▸ confirmar   |   vazio = ESTAGIÁRIO"
		_hint.position = Vector2(x0 + 44, y0 + h - 56)
		_hint.size = Vector2(w - 88, 24)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.visible = false
		_holo.add_child(_hint)
		_status = _mlbl(font, 11, Color(0.4, 0.7, 0.6, 0.5))
		_status.text = "◉ CANAL SEGURO  |  DIMENSÃO α-3  |  COORD 14.7-F"
		_status.position = Vector2(x0 + 44, y0 + h - 32)
		_status.size = Vector2(w - 88, 20)
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status.visible = false
		_holo.add_child(_status)
		_scan = ColorRect.new()
		_scan.size = Vector2(w - 20, 2)
		_scan.position = Vector2(x0 + 10, y0 + 60)
		_scan.color = Color(0.5, 1.0, 0.95, 0.12)
		_scan.mouse_filter = MOUSE_FILTER_IGNORE
		_scan.visible = false
		_holo.add_child(_scan)

	func _tap() -> void:
		if _htw:
			_htw.kill()
		_hand.position = _hrest()
		_htw = create_tween()
		_htw.tween_property(_hand, "position", Vector2.ZERO, 0.08).set_ease(Tween.EASE_OUT)
		_htw.tween_callback(func():
			_sscr(3)
			_nudge = 2.0)
		_htw.tween_interval(0.05)
		_htw.tween_property(_hand, "position", _hrest(), 0.16).set_ease(Tween.EASE_IN)

	func _hrest() -> Vector2:
		return Vector2(80, 80) * PX

	func _sscr(f: int) -> void:
		(_scr.texture as AtlasTexture).region.position.x = f * 320

	func _atl(file: String, f: int) -> AtlasTexture:
		var a := AtlasTexture.new()
		a.atlas = load(I_DIR + file)
		a.region = Rect2(f * 320, 0, 320, 180)
		return a

	func _lay(tex: Texture2D, parent: Node) -> TextureRect:
		var t := TextureRect.new()
		t.texture = tex
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2(320, 180)
		t.scale = Vector2(PX, PX)
		t.mouse_filter = MOUSE_FILTER_IGNORE
		parent.add_child(t)
		return t

	func _mlbl(font: Font, sz: int, col: Color) -> Label:
		var l := Label.new()
		if font:
			l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", sz)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color(0.17, 0.9, 0.96, 0.22))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = MOUSE_FILTER_IGNORE
		return l


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
	show_menu()


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


func _victory_btn(parent: Control, text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(col.r, col.g, col.b, 0.3)
	style.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	hover_style.border_color = Color(col.r, col.g, col.b, 0.7)
	b.add_theme_stylebox_override("hover", hover_style)
	var press_style := style.duplicate()
	press_style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
	b.add_theme_stylebox_override("pressed", press_style)
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
	Music.set_menu_active(true)
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
	var reg := RegistroScreen.new()
	s.add_child(reg)
	var my := seq_id
	await reg.done
	if my == seq_id:
		_flash()
		Game.reset()
		start_game(true)


func start_game(new_game: bool) -> void:
	Music.set_menu_active(false)
	_show_game_loading()
	await get_tree().process_frame
	_clear_menu_backdrop()
	world = WorldScript.new()
	world.tutorial = new_game
	world.victory.connect(show_victory)
	world.defeat.connect(show_defeat)
	world.quit_to_menu.connect(func():
		_flash()
		show_menu())
	add_child(world)
	_flash()
	if screen:
		screen.queue_free()
		screen = null


func _show_game_loading() -> void:
	var s := _new_screen()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	s.add_child(dim)
	var anim := ButterflyEffectLoading.new()
	anim.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(anim)


func show_credits() -> void:
	var s := _new_screen()
	_bg(s)
	var chars := "01ABCDEF{}[]<>=;:/#$%"
	var side_l := _lbl(s, "", 12, Color(0.2, 0.7, 0.4, 0.5), Vector2(20, 0), 200.0, false)
	var side_r := _lbl(s, "", 12, Color(0.2, 0.7, 0.4, 0.5), Vector2(1060, 0), 200.0, false)
	# Cabeçalho fixo estilo terminal
	var header := _lbl(s, "// AGÊNCIA PANÓPTICO — REGISTRO DE OPERADORES //", 14, Color(0.45, 0.9, 0.55, 0.75), Vector2(240, 32), 800.0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credits := "\n\n"
	credits += "=====================================\n"
	credits += "   O PARADOXO DO ESTAGIÁRIO\n"
	credits += "=====================================\n\n"
	credits += "Game Jam CIMATEC 2026.2\n"
	credits += "Tema: Efeito Borboleta\n"
	credits += "\n\n\n"
	credits += "> EQUIPE / OPERADORES\n"
	credits += "-------------------------------------\n\n"
	credits += "Thales Sena\n"
	credits += "  Backend, integração com IA\n"
	credits += "  e direção técnica\n\n"
	credits += "Danilo Lima\n"
	credits += "  UI/UX, HUD pixel-art\n"
	credits += "  e diálogos dos NPCs\n\n"
	credits += "Davi Braz\n"
	credits += "  Level design da vila\n"
	credits += "  e balanceamento de PA\n\n"
	credits += "Matheus Sobral\n"
	credits += "  Gameplay, sistemas de\n"
	credits += "  simulação e boatos\n\n"
	credits += "João Pedro\n"
	credits += "  Trilha sonora, efeitos\n"
	credits += "  e ambientação musical\n\n"
	credits += "Claude (Anthropic)\n"
	credits += "  Só umas coisinhas de\n"
	credits += "  programação, nada demais\n"
	credits += "\n\n\n"
	credits += "> MOTOR DE IA\n"
	credits += "-------------------------------------\n\n"
	credits += "Gemini (Google)\n"
	credits += "  Diretor de cena da vila.\n"
	credits += "  Backend próprio hospedado\n"
	credits += "  em Cloudflare Workers.\n"
	credits += "\n\n\n"
	credits += "> ENGINE\n"
	credits += "-------------------------------------\n\n"
	credits += "Godot 4.7\n"
	credits += "  Renderer GL Compatibility\n"
	credits += "  Resolução: 1280x720\n"
	credits += "\n\n\n"
	credits += "> ASSETS DE TERCEIROS\n"
	credits += "-------------------------------------\n\n"
	credits += "Kenney (kenney.nl) — CC0\n"
	credits += "  · Tiny Town — tileset base\n"
	credits += "    (chão, casas, props)\n"
	credits += "  · Tiny Dungeon — referência\n"
	credits += "    inicial dos personagens\n\n"
	credits += "Fontes do sistema\n"
	credits += "  Consolas / Courier New\n"
	credits += "\n\n\n"
	credits += "> ARTE ORIGINAL\n"
	credits += "-------------------------------------\n\n"
	credits += "Pixel art própria no estilo\n"
	credits += "Kenney, gerada por scripts\n"
	credits += "Python (Pillow):\n\n"
	credits += "  · Castelo, casas, forja,\n"
	credits += "    templo e padaria\n"
	credits += "  · Árvores, arbustos, flores\n"
	credits += "    e animações de balanço\n"
	credits += "  · Estagiário, aldeões,\n"
	credits += "    NPCs principais\n"
	credits += "  · Figura Misteriosa,\n"
	credits += "    portais e agentes\n"
	credits += "  · HUD, painéis e ícones\n"
	credits += "\n\n\n"
	credits += "> AGRADECIMENTOS\n"
	credits += "-------------------------------------\n\n"
	credits += "CIMATEC — pela Game Jam\n"
	credits += "  e pela paciência com\n"
	credits += "  uma vila em revolta\n\n"
	credits += "Jurados — por rodarem o\n"
	credits += "  jogo até o final\n\n"
	credits += "Você — por chegar até aqui\n"
	credits += "\n\n\n"
	credits += "=====================================\n\n"
	credits += "  A AGÊNCIA PANÓPTICO\n"
	credits += "     NÃO EXISTE.\n\n"
	credits += "  Esta cinemática nunca\n"
	credits += "  aconteceu.\n\n"
	credits += "=====================================\n\n\n"
	credits += "> rm -rf /linha_do_tempo\n"
	credits += "> systemctl stop panoptico\n"
	credits += "> ...\n"
	credits += "> Anomalia removida.\n"
	credits += "> Estagiário reintegrado.\n\n\n"
	credits += "\n\n\n"
	var cl := _lbl(s, credits, 20, Color(0.75, 1.0, 0.85), Vector2(340, 720), 600.0)
	cl.size = Vector2(600, 2400)
	_btn(s, "[ VOLTAR ]", show_menu).position = Vector2(20, 660)
	var my := seq_id
	var tw := create_tween()
	# Rolagem mais lenta para dar tempo de ler o texto ampliado
	tw.tween_property(cl, "position:y", -2200.0, 62.0)
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
	box.add_theme_constant_override("separation", 20)
	s.add_child(box)
	_btn(box, "[ TENTAR NOVAMENTE ]", func():
		Game.reset()
		_flash()
		start_game(false))
	_btn(box, "[ MENU PRINCIPAL ]", show_menu)
	await get_tree().process_frame
	box.position = Vector2((1280 - box.size.x) * 0.5, 520)


func show_victory() -> void:
	var s := _new_screen()
	_bg(s, Color(1, 1, 1))
	_flash(1.0)
	var bg := s.get_child(0) as ColorRect
	create_tween().tween_property(bg, "color", Color.BLACK, 1.5)
	if not await _wait(2.0):
		return

	# --- Silêncio pós-flash de memória, depois a mensagem final aparece ---
	var y := Color(1.0, 0.85, 0.35)
	var cyan := Color(0.5, 1.0, 0.95)
	var red := Color(1.0, 0.5, 0.45)
	var white := Color(0.85, 0.92, 0.88)

	# Estática e glitch
	var glitch := _lbl(s, "", 14, Color(0.2, 0.7, 0.4, 0.5), Vector2(40, 30), 1200.0, false)
	var glitch_chars := "01ABCDEF{}[]<>=;:/#$%&*"
	var my_seq := seq_id
	# Glitch sutil nos cantos enquanto o texto principal rola
	var _glitch_task := func():
		while my_seq == seq_id:
			var t := ""
			for r in 3:
				for i in 30:
					t += glitch_chars[randi() % glitch_chars.length()]
				t += "\n"
			glitch.text = t
			glitch.modulate.a = randf_range(0.05, 0.2)
			await get_tree().create_timer(0.2).timeout
	_glitch_task.call()

	# Linha 1: estática
	Sfx.play("bip")
	var l := _lbl(s, "", 16, cyan, Vector2(190, 180), 900.0, false)
	_type(l, "> [SISTEMA PANÓPTICO — ENCERRAMENTO DE MISSÃO]", 35.0)
	if not await _wait(2.5):
		return

	# Linha 2: mensagem que o jogador "deveria" ver (memória apagada)
	var l2 := _lbl(s, "", 18, white, Vector2(190, 240), 900.0, false)
	_type(l2, "Operador %s,\n\nVocê não se lembra do que aconteceu nos últimos minutos.\nIsso é normal. O protocolo de contenção foi ativado." % Game.player_name, 38.0)
	if not await _wait(6.0):
		return

	# Linha 3: a verdade sutil
	var l3 := _lbl(s, "", 16, red, Vector2(190, 370), 900.0, false)
	Sfx.play("error")
	_flash(0.15)
	_type(l3, "[FRAGMENTO DE MEMÓRIA NÃO APAGADO]", 25.0)
	if not await _wait(2.5):
		return

	var l4 := _lbl(s, "", 17, Color(1.0, 0.75, 0.45), Vector2(190, 410), 900.0, false)
	_type(l4, "\"...a Agência está tirando o livre-arbítrio...\"", 30.0)
	if not await _wait(3.5):
		return

	# Flash final + mensagem do tema da jam
	_flash(0.3)
	l.visible = false
	l2.visible = false
	l3.visible = false
	l4.visible = false
	if not await _wait(1.0):
		return

	var final_msg := _lbl(s, "", 28, y, Vector2(140, 200), 1000.0)
	_type(final_msg, "A linha do tempo não está segura...", 20.0)
	if not await _wait(3.5):
		return
	var final_msg2 := _lbl(s, "", 22, cyan, Vector2(140, 300), 1000.0)
	_type(final_msg2, "O Efeito Borboleta foi implantado com sucesso.", 22.0)
	if not await _wait(4.0):
		return
	var final_msg3 := _lbl(s, "", 26, Color(1.0, 0.5, 0.3), Vector2(140, 380), 1000.0)
	Sfx.play("tension")
	_type(final_msg3, "Agora é com você... Estagiário.", 18.0)
	if not await _wait(5.0):
		return

	# Botões
	final_msg.visible = false
	final_msg2.visible = false
	final_msg3.visible = false
	glitch.visible = false
	_flash(0.3)

	# Linha decorativa superior
	var line_top := ColorRect.new()
	line_top.size = Vector2(500, 2)
	line_top.position = Vector2(390, 175)
	line_top.color = Color(1.0, 0.85, 0.35, 0.4)
	line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(line_top)

	var title := _lbl(s, "O  P A R A D O X O  D O  E S T A G I Á R I O", 32, y, Vector2(0, 190), 1280.0)
	var sub := _lbl(s, "Missão Concluída", 18, white, Vector2(0, 240), 1280.0)

	# Linha decorativa inferior
	var line_bot := ColorRect.new()
	line_bot.size = Vector2(300, 1)
	line_bot.position = Vector2(490, 270)
	line_bot.color = Color(0.5, 1.0, 0.95, 0.3)
	line_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(line_bot)

	# Subtítulo temático
	var theme_lbl := _lbl(s, "\"O Efeito Borboleta foi implantado com sucesso.\"", 13, Color(0.5, 1.0, 0.95, 0.5), Vector2(0, 290), 1280.0)

	if not await _wait(2.0):
		return

	# Container de botões centralizado
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.position = Vector2(640, 400)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	s.add_child(box)
	# Ajustar posição para centralizar de verdade
	await get_tree().process_frame
	box.position = Vector2((1280 - box.size.x) * 0.5, 370)
	_victory_btn(box, "[ JOGAR NOVAMENTE ]", Color(1.0, 0.85, 0.35), func():
		Game.reset()
		_flash()
		start_game(false))
	_victory_btn(box, "[ CRÉDITOS ]", Color(0.5, 1.0, 0.95), show_credits)
	_victory_btn(box, "[ MENU PRINCIPAL ]", Color(0.85, 0.92, 0.88), show_menu)
	await get_tree().process_frame
	box.position = Vector2((1280 - box.size.x) * 0.5, 370)

	# Rodapé
	_lbl(s, "Game Jam CIMATEC 2026.2  |  Tema: Efeito Borboleta", 11, Color(0.4, 0.55, 0.45, 0.4), Vector2(0, 680), 1280.0)

	# Shimmer sutil no título
	var my_t := seq_id
	var shimmer := 0.0
	while my_t == seq_id:
		shimmer += 0.03
		var pulse := 0.85 + 0.15 * sin(shimmer * 1.0)
		title.modulate = Color(pulse, pulse * 0.95, pulse * 0.85)
		if is_instance_valid(line_top):
			line_top.color.a = 0.25 + 0.15 * sin(shimmer * 0.7)
		if is_instance_valid(line_bot):
			line_bot.color.a = 0.2 + 0.1 * sin(shimmer * 0.9 + 1.0)
		await get_tree().create_timer(0.03).timeout
