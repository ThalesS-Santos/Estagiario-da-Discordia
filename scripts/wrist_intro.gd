class_name WristIntro
extends Control
## Abertura em primeira pessoa: o estagiário ergue o braço, liga o visor de pulso e a Central
## Panóptico passa a missão num holograma. Cada toque (Espaço/Enter/clique) responde na hora:
## completa o texto que está sendo digitado ou passa para a próxima mensagem. ESC pula tudo.

signal finished

const DIR := "res://assets/gen/intro/"
const PX := 4.0
const PANEL := Rect2(36, 6, 248, 94)           # em pixels da arte (320x180)
const CHARS_PER_SEC := 70.0
const CYAN := Color("7ff6ff")

enum Step { BOOT, TYPING, WAITING, CLOSING, DONE }

var step := Step.BOOT
var _pages: Array[Dictionary] = []
var _page := -1
var _chars := 0.0
var _clack_acc := 0.0
var _t := 0.0
var _bay_frame := 0
var _nudge := 0.0

var _bay: TextureRect
var _beam: TextureRect
var _holo: Control
var _arm_root: Control
var _screen: TextureRect
var _hand: TextureRect
var _header: Label
var _counter: Label
var _body: RichTextLabel
var _prompt: Label
var _fade: ColorRect
var _hand_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pages = _build_pages()
	_bay = _layer(_atlas("bay.png", 0), self)
	_beam = _layer(_atlas("holo_beam.png", 0), self)
	_beam.modulate.a = 0.0
	_build_holo()
	_arm_root = Control.new()
	_arm_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arm_root)
	_layer(load(DIR + "arm_left.png"), _arm_root)
	_screen = _layer(_atlas("device_screen.png", 0), _arm_root)
	_hand = _layer(load(DIR + "hand_right.png"), self)
	_hand.position = _hand_rest()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


## Inicia a abertura. Quem chama espera o sinal `finished` (tela fica branca no salto);
## depois chama reveal_world() para dissolver o branco sobre a vila.
func play() -> void:
	_arm_root.position.y = 720.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	await tw.finished
	# ergue o braço para olhar o visor
	Sfx.play("whoosh")
	tw = create_tween()
	tw.tween_property(_arm_root, "position:y", 0.0, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if step != Step.BOOT:
		return
	# toque para ligar: chiado na telinha e o olho da Agência
	_tap()
	await get_tree().create_timer(0.12).timeout
	Sfx.play("bip")
	for i in 6:
		_set_screen(1 if i % 2 == 0 else 0)
		await get_tree().create_timer(0.06).timeout
	_set_screen(2)
	Sfx.play("portal_open")
	# feixe e holograma sobem da lente
	tw = create_tween()
	tw.tween_property(_beam, "modulate:a", 1.0, 0.18)
	tw.tween_property(_holo, "scale:y", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_holo, "modulate:a", 1.0, 0.2)
	await tw.finished
	if step != Step.BOOT:
		return
	_next_page()


func reveal_world() -> void:
	for c in get_children():
		if c != _fade:
			c.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.7)
	await tw.finished
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	# plataforma pulsando e feixe tremulando
	var bf := int(_t * 7.0) % 4
	if bf != _bay_frame:
		_bay_frame = bf
		(_bay.texture as AtlasTexture).region.position.x = bf * 320
		(_beam.texture as AtlasTexture).region.position.x = (int(_t * 11.0) % 3) * 320
	# respiração do braço em degraus de 1 pixel da arte (+ afundada rápida quando o dedo toca)
	_nudge = move_toward(_nudge, 0.0, delta * 30.0)
	if step == Step.TYPING or step == Step.WAITING:
		_arm_root.position.y = (roundf(sin(_t * 1.7)) + roundf(_nudge)) * PX
		_holo.modulate.a = 0.92 + 0.08 * sin(_t * 23.0) * sin(_t * 3.1)
	if step == Step.TYPING:
		_chars += delta * CHARS_PER_SEC
		_body.visible_characters = int(_chars)
		_clack_acc += delta
		if _clack_acc > 0.07:
			_clack_acc = 0.0
			Sfx.play("clack")
		if _chars >= _body.get_total_character_count():
			_finish_typing()
		_set_screen(2 + (int(_t * 8.0) % 2))
	elif step == Step.WAITING:
		_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)


func _input(event: InputEvent) -> void:
	if step == Step.DONE:
		return
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close()
			return
		advance = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventScreenTouch and event.pressed:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	match step:
		Step.TYPING:
			_tap()
			_finish_typing()
		Step.WAITING:
			_tap()
			_next_page()


# ------------------------------------------------------------------ páginas
func _build_pages() -> Array[Dictionary]:
	var nm := str(Game.player_name)
	var y := "[color=#ffd76a]"
	var r := "[color=#ff7a7a]"
	var c := "[color=#7ff6ff]"
	var e := "[/color]"
	var pages: Array[Dictionary] = [
		{"title": "CONEXÃO", "text":
			"%s> CANAL SEGURO ABERTO.%s\n\nOperador %s, aqui é a Central Panóptico.\nPrimeiro dia de estágio... e você já vai a campo.\n\nDestino: a vila do %sRei Aldemar I%s.\nLinha temporal Alfa-3, coordenada 14.7-F." % [c, e, nm, y, e]},
		{"title": "O PROBLEMA", "text":
			"Nossas projeções não deixam dúvida:\nem 30 dias Aldemar declara guerra aos reinos vizinhos.\n\n%sA região inteira será destruída.%s\n\nVocê vai mudar esse futuro. Tem %s3 dias%s no local." % [r, e, y, e]},
		{"title": "AS REGRAS", "text":
			"Tire o rei do trono %ssem violência%s e sem se revelar.\nVocê não luta: você %smove objetos%s e %splanta boatos%s.\n\nCada boato mexe com o medo, a raiva e a lealdade dos moradores.\nQuando a %sInstabilidade Social%s chegar a 100%%,\no próprio povo derruba o rei." % [r, e, c, e, c, e, c, e]},
		{"title": "PRIMEIRO PASSO", "text":
			"O castelo fica ao norte. O portão é vigiado por %sBram, o guarda%s.\n\n%s1.%s Descubra a fraqueza de Bram: ouça os moradores, junte pistas.\n%s2.%s Crie uma distração que o tire do posto.\n%s3.%s Com o portão livre, cruze-o. O povo fará o resto.\n\n%sCuidado:%s o Ancião Osric vigia o portão de longe." % [y, e, c, e, c, e, c, e, r, e]},
		{"title": "FERRAMENTAS", "text":
			"%s[CLIQUE]%s pegar um objeto e levá-lo para outro lugar.\n         Ao soltar, escreva o boato que ele vai espalhar.\n%s[E]%s      sussurrar um boato, chegando por trás de alguém.\n\nCada ação gasta %s1 PA%s. Você tem %s3 PA por dia%s.\nSe alguém desconfiar demais... %scorra%s.\n\n%s> Salto dimensional pronto. Boa sorte, estagiário.%s" % [c, e, c, e, y, e, y, e, r, e, c, e]},
	]
	return pages


func _next_page() -> void:
	_page += 1
	if _page >= _pages.size():
		_close()
		return
	Sfx.play("bip")
	_glitch()
	var p: Dictionary = _pages[_page]
	_header.text = "PANÓPTICO // %s" % p.title
	_counter.text = "%02d/%02d" % [_page + 1, _pages.size()]
	_body.text = p.text
	_body.visible_characters = 0
	_chars = 0.0
	_prompt.modulate.a = 0.0
	step = Step.TYPING


func _finish_typing() -> void:
	_body.visible_characters = -1
	_set_screen(2)
	_prompt.text = "ESPAÇO / CLIQUE  ▸  começar a missão" if _page == _pages.size() - 1 else "ESPAÇO / CLIQUE  ▸  próxima"
	step = Step.WAITING


func _close() -> void:
	if step == Step.CLOSING or step == Step.DONE:
		return
	step = Step.CLOSING
	Sfx.play("confirm")
	var tw := create_tween()
	tw.tween_property(_holo, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_beam, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_set_screen.bind(0))
	tw.tween_property(_arm_root, "position:y", 720.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# a plataforma dispara: clarão e salto
	tw.tween_callback(func(): Sfx.play("whoosh"))
	tw.tween_property(_bay, "modulate", Color(2.2, 2.6, 2.8), 0.35)
	tw.parallel().tween_property(_fade, "color", Color(1, 1, 1, 1), 0.35)
	await tw.finished
	step = Step.DONE
	finished.emit()


# ------------------------------------------------------------------ animação
func _tap() -> void:
	if _hand_tween:
		_hand_tween.kill()
	_hand.position = _hand_rest()
	_hand_tween = create_tween()
	_hand_tween.tween_property(_hand, "position", Vector2.ZERO, 0.08).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_callback(func():
		_set_screen(3)
		_nudge = 2.0)
	_hand_tween.tween_interval(0.05)
	_hand_tween.tween_property(_hand, "position", _hand_rest(), 0.16).set_ease(Tween.EASE_IN)


func _hand_rest() -> Vector2:
	return Vector2(80, 80) * PX


func _glitch() -> void:
	var tw := create_tween()
	tw.tween_property(_holo, "position:x", 2.0 * PX, 0.03)
	tw.tween_property(_holo, "modulate:a", 0.45, 0.03)
	tw.tween_property(_holo, "position:x", -1.0 * PX, 0.03)
	tw.tween_property(_holo, "position:x", 0.0, 0.03)
	tw.tween_property(_holo, "modulate:a", 1.0, 0.05)


func _set_screen(f: int) -> void:
	(_screen.texture as AtlasTexture).region.position.x = f * 320


# ------------------------------------------------------------------ construção
func _atlas(file: String, f: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(DIR + file)
	a.region = Rect2(f * 320, 0, 320, 180)
	return a


func _layer(tex: Texture2D, parent: Node) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size = Vector2(320, 180)
	t.scale = Vector2(PX, PX)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _build_holo() -> void:
	_holo = Control.new()
	_holo.size = Vector2(1280, 720)
	_holo.pivot_offset = Vector2(640, PANEL.end.y * PX)
	_holo.scale.y = 0.0
	_holo.modulate.a = 0.0
	_holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holo)
	_layer(load(DIR + "holo_panel.png"), _holo)
	var font: Font = Game.ui_theme.default_font if Game.ui_theme else null
	var x0 := PANEL.position.x * PX
	var y0 := PANEL.position.y * PX
	var w := PANEL.size.x * PX
	var h := PANEL.size.y * PX
	_header = _text_label(font, 15, CYAN)
	_header.position = Vector2(x0 + 60, y0 + 10)
	_holo.add_child(_header)
	_counter = _text_label(font, 15, CYAN)
	_counter.position = Vector2(x0 + w - 130, y0 + 10)
	_holo.add_child(_counter)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.fit_content = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.position = Vector2(x0 + 44, y0 + 72)
	_body.size = Vector2(w - 88, h - 124)
	if font:
		_body.add_theme_font_override("normal_font", font)
	_body.add_theme_font_size_override("normal_font_size", 19)
	_body.add_theme_color_override("default_color", Color("d8fbff"))
	_body.add_theme_color_override("font_outline_color", Color(0.17, 0.9, 0.96, 0.22))
	_body.add_theme_constant_override("outline_size", 4)
	_body.add_theme_constant_override("line_separation", 5)
	_holo.add_child(_body)
	_prompt = _text_label(font, 14, CYAN)
	_prompt.position = Vector2(x0 + w - 440, y0 + h - 40)
	_prompt.size = Vector2(400, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.modulate.a = 0.0
	_holo.add_child(_prompt)
	var skip := _text_label(font, 12, Color(0.5, 0.85, 0.9, 0.6))
	skip.text = "ESC  ▸  pular"
	skip.position = Vector2(x0 + 44, y0 + h - 38)
	_holo.add_child(skip)


func _text_label(font: Font, sz: int, col: Color) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.17, 0.9, 0.96, 0.25))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
