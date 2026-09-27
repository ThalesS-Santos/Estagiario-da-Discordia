extends PanelContainer
## Painel de configurações reutilizável (menu principal e pausa).

signal closed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Game.ui_theme
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "// CONFIGURAÇÕES //"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	box.add_child(title)
	_slider(box, "VOLUME GERAL", "master", 0.0, 1.0, 0.05)
	_slider(box, "MÚSICA", "music", 0.0, 1.0, 0.05)
	_slider(box, "EFEITOS SONOROS", "sfx", 0.0, 1.0, 0.05)
	# resolução
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "RESOLUÇÃO"
	l.custom_minimum_size.x = 210
	row.add_child(l)
	var ob := OptionButton.new()
	ob.add_item("1280x720", 0)
	ob.add_item("1920x1080", 1)
	ob.add_item("Tela cheia", 2)
	ob.select(int(Game.settings.resolution))
	ob.item_selected.connect(func(i):
		Game.settings.resolution = i
		Game.apply_settings())
	row.add_child(ob)
	box.add_child(row)
	# velocidade
	var row2 := HBoxContainer.new()
	var l2 := Label.new()
	l2.text = "VELOCIDADE DA SIMULAÇÃO"
	l2.custom_minimum_size.x = 210
	row2.add_child(l2)
	var sp := OptionButton.new()
	sp.add_item("0.5x", 0)
	sp.add_item("1x", 1)
	sp.add_item("2x", 2)
	var cur := float(Game.settings.sim_speed)
	sp.select(0 if cur < 0.75 else (1 if cur < 1.5 else 2))
	sp.item_selected.connect(func(i): Game.settings.sim_speed = [0.5, 1.0, 2.0][i])
	row2.add_child(sp)
	box.add_child(row2)
	_toggle(box, "SUBTÍTULOS", "subtitles")
	var b := Button.new()
	b.text = "[ VOLTAR ]"
	b.pressed.connect(func():
		Game.save_settings()
		closed.emit())
	b.mouse_entered.connect(func(): Sfx.play("bip"))
	box.add_child(b)


func _slider(parent: Control, label: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 210
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(240, 22)
	s.value_changed.connect(func(v):
		Game.settings[key] = v
		Game.apply_settings())
	row.add_child(s)
	parent.add_child(row)


func _toggle(parent: Control, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = bool(Game.settings[key])
	c.toggled.connect(func(v): Game.settings[key] = v)
	parent.add_child(c)
