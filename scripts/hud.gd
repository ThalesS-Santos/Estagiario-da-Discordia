extends CanvasLayer
## HUD do gameplay: relógio, PA, barra de Instabilidade, card de NPC, terminal de narrativa,
## tutorial, painel de status (TAB), pausa. Versão pixel-art com animações fluidas.

const GEN := "res://assets/gen/"

var world
var ui: Control
var lbl_day: Label
var ap_gems: Array = []
var bar: InstabBar
var card: NinePatchRect
var card_vbox: VBoxContainer
var card_title: Label
var card_role: Label
var stat_rows: Array = []
var memory_box: VBoxContainer
var held_panel: NinePatchRect
var held_label: Label
var end_btn: Button
var terminal: NinePatchRect
var term_input: LineEdit
var term_count: Label
var term_err: Label
var term_sub: Label
var subtitle_label: Label
var toast_label: Label
var banner: Label
var tooltip: NinePatchRect
var tooltip_label: Label
var status_panel: NinePatchRect
var status_vbox: VBoxContainer
var pause_panel: Control
var tutorial_panel: Control
var flash_rect: ColorRect
var alarm_rect: ColorRect
var pinned = null
var pin_t := 0.0
var toast_t := 0.0
var sub_t := 0.0
var alarm_t := 0.0
var card_npc = null
var tut_step := 0
var _tex_cache: Dictionary = {}

# ---- texturas pré-carregadas
var tex_panel: Texture2D
var tex_tooltip: Texture2D
var tex_gem: Texture2D
var tex_stat_icons: Texture2D
var tex_stat_fill: Texture2D
var tex_stat_bg: Texture2D
var tex_instab_frame: Texture2D
var tex_instab_fill: Texture2D
var tex_separator: Texture2D
var tex_button: Texture2D
var tex_day_banner: Texture2D
var tex_memory: Texture2D


func _tex(key: String) -> Texture2D:
	if not _tex_cache.has(key):
		_tex_cache[key] = load(GEN + key + ".png")
	return _tex_cache[key]


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	tex_panel = _tex("ui/panel")
	tex_tooltip = _tex("ui/tooltip")
	tex_gem = _tex("ui/ap_gem")
	tex_stat_icons = _tex("ui/stat_icons")
	tex_stat_fill = _tex("ui/stat_bar_fill")
	tex_stat_bg = _tex("ui/stat_bar_bg")
	tex_instab_frame = _tex("ui/instab_frame")
	tex_instab_fill = _tex("ui/instab_fill")
	tex_separator = _tex("ui/separator")
	tex_button = _tex("ui/button")
	tex_day_banner = _tex("ui/day_banner")
	tex_memory = _tex("ui/memory_icon")

	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Game.ui_theme
	add_child(ui)

	_build_top_left()
	_build_top_right()
	_build_card()
	_build_held()
	_build_end_btn()
	_build_tooltip()
	_build_subtitles()
	_build_terminal()
	_build_status()
	_build_pause()

	alarm_rect = ColorRect.new()
	alarm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	alarm_rect.color = Color(1, 0, 0, 0)
	alarm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(alarm_rect)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)


# ------------------------------------------------------------------ builders
func _9patch(tex: Texture2D, margins: Array, sz: Vector2) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = tex
	np.patch_margin_left = margins[0] * 2
	np.patch_margin_top = margins[1] * 2
	np.patch_margin_right = margins[2] * 2
	np.patch_margin_bottom = margins[3] * 2
	np.custom_minimum_size = sz
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var back := ColorRect.new()
	back.color = Color(0.04, 0.06, 0.08, 0.9)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 5
	back.offset_top = 5
	back.offset_right = -5
	back.offset_bottom = -5
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.add_child(back)
	return np


func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_top_left() -> void:
	var panel := _9patch(tex_day_banner, [6, 4, 6, 4], Vector2(220, 80))
	panel.position = Vector2(10, 8)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner)
	lbl_day = _label("", 17, Color(1.0, 0.85, 0.35))
	inner.add_child(lbl_day)
	var gem_row := HBoxContainer.new()
	gem_row.add_theme_constant_override("separation", 4)
	gem_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gem_row)
	for i in 3:
		var tr := TextureRect.new()
		tr.texture = tex_gem
		tr.custom_minimum_size = Vector2(24, 28)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem_row.add_child(tr)
		ap_gems.append(tr)
	var ap_l := _label("AÇÃO", 10, Color(0.6, 0.8, 0.7))
	gem_row.add_child(ap_l)
	_update_gems(Game.ap)
	Game.ap_changed.connect(_update_gems)


func _update_gems(ap_val: int) -> void:
	var gem_w: int = tex_gem.get_width() / 2
	var gem_h: int = tex_gem.get_height()
	for i in ap_gems.size():
		var tr: TextureRect = ap_gems[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = tex_gem
		atlas.region = Rect2(0 if i < ap_val else gem_w, 0, gem_w, gem_h)
		tr.texture = atlas


func _build_top_right() -> void:
	var panel := _9patch(tex_panel, [4, 4, 4, 4], Vector2(340, 60))
	panel.position = Vector2(1280 - 350, 8)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner)
	inner.add_child(_label("INSTABILIDADE SOCIAL", 11, Color(0.8, 0.95, 0.85)))
	bar = InstabBar.new()
	bar.tex_frame = tex_instab_frame
	bar.tex_fill = tex_instab_fill
	inner.add_child(bar)
	Game.instability_changed.connect(func(v2): bar.value = v2)
	bar.value = Game.instability
	bar.shown = Game.instability


func _build_card() -> void:
	card = _9patch(tex_panel, [4, 4, 4, 4], Vector2(300, 0))
	card.position = Vector2(12, 720 - 240)
	card.visible = false
	ui.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(card_vbox)
	card_title = _label("", 16, Color(1.0, 0.85, 0.35))
	card_vbox.add_child(card_title)
	card_role = _label("", 12, Color(0.7, 0.9, 0.8))
	card_vbox.add_child(card_role)
	# separator
	var sep := TextureRect.new()
	sep.texture = tex_separator
	sep.custom_minimum_size = Vector2(260, 6)
	sep.stretch_mode = TextureRect.STRETCH_TILE
	sep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(sep)
	# stat rows
	var stat_names := ["Medo", "Raiva", "Lealdade", "Cred."]
	var stat_colors := [Color(0.42, 0.68, 0.92), Color(0.92, 0.38, 0.28), Color(0.95, 0.78, 0.28), Color(0.35, 0.72, 0.65)]
	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# icon
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = tex_stat_icons
		atlas.region = Rect2(i * 10, 0, 10, 10)
		icon.texture = atlas
		icon.custom_minimum_size = Vector2(20, 20)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_l := _label(stat_names[i], 12, stat_colors[i])
		name_l.custom_minimum_size.x = 62
		row.add_child(name_l)
		var bar_holder := StatBar.new()
		bar_holder.stat_index = i
		bar_holder.tex_fill = tex_stat_fill
		bar_holder.tex_bg = tex_stat_bg
		row.add_child(bar_holder)
		var val_l := _label("0", 12, Color(0.85, 0.9, 0.95))
		val_l.custom_minimum_size.x = 28
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		card_vbox.add_child(row)
		stat_rows.append({"bar": bar_holder, "val": val_l})
	# separator 2
	var sep2 := TextureRect.new()
	sep2.texture = tex_separator
	sep2.custom_minimum_size = Vector2(260, 6)
	sep2.stretch_mode = TextureRect.STRETCH_TILE
	sep2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(sep2)
	# memory section
	var mem_title := _label("Memórias:", 11, Color(0.6, 0.75, 0.7))
	card_vbox.add_child(mem_title)
	memory_box = VBoxContainer.new()
	memory_box.add_theme_constant_override("separation", 2)
	memory_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(memory_box)


func _build_held() -> void:
	held_panel = _9patch(tex_panel, [4, 4, 4, 4], Vector2(280, 60))
	held_panel.position = Vector2(1280 - 294, 720 - 80)
	held_panel.visible = false
	ui.add_child(held_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_panel.add_child(margin)
	held_label = _label("", 13, Color(0.85, 1.0, 0.9))
	held_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	held_label.custom_minimum_size.x = 248
	margin.add_child(held_label)


func _build_end_btn() -> void:
	end_btn = Button.new()
	end_btn.text = "ENCERRAR DIA"
	end_btn.position = Vector2(540, 720 - 52)
	end_btn.custom_minimum_size = Vector2(200, 38)
	end_btn.pressed.connect(func(): world.end_day_requested())
	end_btn.mouse_entered.connect(func(): Sfx.play("bip"))
	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = tex_button
	sb_normal.region_rect = Rect2(0, 0, 32, 14)
	_set_9slice_margins(sb_normal, 4)
	var sb_hover := StyleBoxTexture.new()
	sb_hover.texture = tex_button
	sb_hover.region_rect = Rect2(0, 14, 32, 14)
	_set_9slice_margins(sb_hover, 4)
	var sb_pressed := StyleBoxTexture.new()
	sb_pressed.texture = tex_button
	sb_pressed.region_rect = Rect2(0, 28, 32, 14)
	_set_9slice_margins(sb_pressed, 4)
	end_btn.add_theme_stylebox_override("normal", sb_normal)
	end_btn.add_theme_stylebox_override("hover", sb_hover)
	end_btn.add_theme_stylebox_override("pressed", sb_pressed)
	end_btn.add_theme_stylebox_override("focus", sb_normal)
	end_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	end_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.35))
	end_btn.add_theme_font_size_override("font_size", 15)
	ui.add_child(end_btn)


func _set_9slice_margins(sb: StyleBoxTexture, m: int) -> void:
	sb.texture_margin_left = m * 2.0
	sb.texture_margin_top = m * 2.0
	sb.texture_margin_right = m * 2.0
	sb.texture_margin_bottom = m * 2.0


func _build_tooltip() -> void:
	tooltip = _9patch(tex_tooltip, [3, 3, 3, 3], Vector2(0, 0))
	tooltip.visible = false
	ui.add_child(tooltip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(margin)
	tooltip_label = _label("", 13, Color(1, 1, 1))
	margin.add_child(tooltip_label)


func _build_subtitles() -> void:
	subtitle_label = _label("", 15, Color(1, 1, 0.9))
	subtitle_label.position = Vector2(0, 720 - 96)
	subtitle_label.size = Vector2(1280, 30)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(subtitle_label)
	toast_label = _label("", 16, Color(1.0, 0.85, 0.35))
	toast_label.position = Vector2(0, 80)
	toast_label.size = Vector2(1280, 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(toast_label)
	banner = _label("", 40, Color(1.0, 0.85, 0.35))
	banner.position = Vector2(0, 250)
	banner.size = Vector2(1280, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	ui.add_child(banner)


# ------------------------------------------------------------ terminal de narrativa
func _build_terminal() -> void:
	terminal = _9patch(tex_panel, [4, 4, 4, 4], Vector2(700, 0))
	terminal.visible = false
	terminal.position = Vector2(290, 250)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	terminal.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	v.add_child(_label("INSERINDO NARRATIVA", 18, Color(1.0, 0.85, 0.35)))
	term_sub = _label("O que os moradores saberão sobre este objeto aqui?", 14, Color(0.7, 1.0, 0.8))
	term_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	term_sub.custom_minimum_size.x = 660
	v.add_child(term_sub)
	term_input = LineEdit.new()
	term_input.max_length = 80
	term_input.placeholder_text = "> digite o boato..."
	term_input.text_changed.connect(_on_term_changed)
	term_input.text_submitted.connect(_on_term_submit)
	v.add_child(term_input)
	term_count = _label("80 restantes", 12, Color(0.6, 0.8, 0.7))
	v.add_child(term_count)
	term_err = _label("", 13, Color(1.0, 0.4, 0.35))
	v.add_child(term_err)
	v.add_child(_label("[ENTER] confirmar    [ESC] cancelar", 12, Color(0.6, 0.8, 0.7)))
	ui.add_child(terminal)


func open_terminal(obj_name: String, loc_name: String) -> void:
	term_sub.text = "%s deixado em: %s.  O que os moradores saberão?" % [obj_name, loc_name]
	term_input.text = ""
	term_err.text = ""
	term_count.text = "80 restantes"
	terminal.visible = true
	terminal.modulate.a = 0.0
	create_tween().tween_property(terminal, "modulate:a", 1.0, 0.2)
	term_input.call_deferred("grab_focus")


func close_terminal() -> void:
	var tw := create_tween()
	tw.tween_property(terminal, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): terminal.visible = false)
	term_input.release_focus()


func _on_term_changed(t: String) -> void:
	Sfx.play("clack")
	term_count.text = "%d restantes" % (80 - t.length())
	term_err.text = ""


func _on_term_submit(t: String) -> void:
	if t.strip_edges() == "":
		term_err.text = "Digite algo, ou pressione ESC para cancelar."
		return
	if Director.is_offensive(t):
		term_err.text = "A Agência não autoriza este tipo de boato."
		Sfx.play("error")
		return
	close_terminal()
	world.terminal_submit(t)


# ------------------------------------------------------------ status (TAB) / pausa
func _build_status() -> void:
	status_panel = _9patch(tex_panel, [4, 4, 4, 4], Vector2(600, 0))
	status_panel.position = Vector2(340, 100)
	status_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(margin)
	status_vbox = VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 6)
	status_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(status_vbox)
	ui.add_child(status_panel)


func toggle_status() -> void:
	status_panel.visible = not status_panel.visible
	if status_panel.visible:
		_refresh_status()
		status_panel.modulate.a = 0.0
		create_tween().tween_property(status_panel, "modulate:a", 1.0, 0.2)


func _refresh_status() -> void:
	for c in status_vbox.get_children():
		c.queue_free()
	status_vbox.add_child(_label("STATUS DOS MORADORES", 18, Color(1.0, 0.85, 0.35)))
	var sep := TextureRect.new()
	sep.texture = tex_separator
	sep.custom_minimum_size = Vector2(560, 6)
	sep.stretch_mode = TextureRect.STRETCH_TILE
	sep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_vbox.add_child(sep)
	# header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col_name := _label("Nome", 13, Color(0.7, 0.85, 0.8))
	col_name.custom_minimum_size.x = 140
	hdr.add_child(col_name)
	for sn in ["Medo", "Raiva", "Lealdade", "Cred."]:
		var sl := _label(sn, 12, Color(0.6, 0.8, 0.7))
		sl.custom_minimum_size.x = 80
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_child(sl)
	status_vbox.add_child(hdr)
	# rows
	for id in Game.NPC_DEFS:
		var st: Dictionary = Game.npc_state[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl := _label(Game.NPC_DEFS[id].name, 13, Color(0.9, 0.95, 1.0))
		nl.custom_minimum_size.x = 140
		row.add_child(nl)
		var stats := [st.fear, st.anger, st.loyalty, st.cred]
		var colors := [Color(0.42, 0.68, 0.92), Color(0.92, 0.38, 0.28), Color(0.95, 0.78, 0.28), Color(0.35, 0.72, 0.65)]
		for si in 4:
			var sb := StatusStatBar.new()
			sb.stat_color = colors[si]
			sb.value = float(stats[si])
			sb.custom_minimum_size = Vector2(80, 16)
			row.add_child(sb)
		status_vbox.add_child(row)


func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	pause_panel.add_child(dim)
	var pc := _9patch(tex_panel, [4, 4, 4, 4], Vector2(280, 0))
	pc.name = "Menu"
	pc.position = Vector2(500, 200)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	pc.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)
	v.add_child(_label("PAUSA", 22, Color(1.0, 0.85, 0.35)))
	for item in [["CONTINUAR", "resume"], ["REINICIAR DIA", "restart"], ["CONFIGURAÇÕES", "settings"], ["MENU PRINCIPAL", "menu"], ["SAIR", "quit"]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(_pause_action.bind(item[1]))
		b.mouse_entered.connect(func(): Sfx.play("bip"))
		var sb_n := StyleBoxTexture.new()
		sb_n.texture = tex_button
		sb_n.region_rect = Rect2(0, 0, 32, 14)
		_set_9slice_margins(sb_n, 4)
		var sb_h := StyleBoxTexture.new()
		sb_h.texture = tex_button
		sb_h.region_rect = Rect2(0, 14, 32, 14)
		_set_9slice_margins(sb_h, 4)
		var sb_p := StyleBoxTexture.new()
		sb_p.texture = tex_button
		sb_p.region_rect = Rect2(0, 28, 32, 14)
		_set_9slice_margins(sb_p, 4)
		b.add_theme_stylebox_override("normal", sb_n)
		b.add_theme_stylebox_override("hover", sb_h)
		b.add_theme_stylebox_override("pressed", sb_p)
		b.add_theme_stylebox_override("focus", sb_n)
		b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.35))
		v.add_child(b)
	pause_panel.add_child(pc)
	ui.add_child(pause_panel)


func toggle_pause() -> void:
	if world.phase == 3:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	pause_panel.get_node("Menu").visible = true
	var sp = pause_panel.get_node_or_null("Settings")
	if sp:
		sp.queue_free()


func _pause_action(a: String) -> void:
	match a:
		"resume":
			toggle_pause()
		"restart":
			toggle_pause()
			world.restart_day()
		"settings":
			pause_panel.get_node("Menu").visible = false
			var sp := preload("res://scripts/settings_panel.gd").new()
			sp.name = "Settings"
			sp.position = Vector2(400, 150)
			sp.closed.connect(func():
				sp.queue_free()
				pause_panel.get_node("Menu").visible = true)
			pause_panel.add_child(sp)
		"menu":
			get_tree().paused = false
			world.quit_to_menu.emit()
		"quit":
			get_tree().quit()


# ------------------------------------------------------------ tutorial
func show_tutorial() -> void:
	tut_step = 0
	tutorial_panel = Control.new()
	tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(tutorial_panel)
	_tut_render()


func _tut_render() -> void:
	for c in tutorial_panel.get_children():
		c.queue_free()
	var steps := [
		["OBSERVAÇÃO", "Passe o mouse sobre os NPCs para ver seus atributos.", Vector2(330, 500)],
		["OBJETO", "Clique em um objeto (pontos coloridos) para pegá-lo. Custa 1 PA.", Vector2(400, 240)],
		["MOVA", "Leve o objeto para outro local e clique para soltá-lo.", Vector2(400, 240)],
		["NARRATIVA", "Digite o boato que conecta o objeto ao caos. ENTER confirma, ESC cancela.", Vector2(290, 150)],
		["OBSERVE", "A IA fará o resto. Você é apenas o catalisador.", Vector2(400, 240)],
		["INSTABILIDADE", "Quando a barra chegar a 100%, o Rei cai. Você tem 3 dias.  [Z] desfaz  [TAB] status", Vector2(330, 120)],
	]
	var s: Array = steps[tut_step]
	var pc := _9patch(tex_panel, [4, 4, 4, 4], Vector2(560, 0))
	pc.position = s[2]
	pc.modulate.a = 0.0
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	v.add_child(_label("PASSO %d/%d — %s" % [tut_step + 1, steps.size(), s[0]], 18, Color(1.0, 0.85, 0.35)))
	var t := _label(s[1], 15, Color(0.85, 1.0, 0.9))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 520
	v.add_child(t)
	var b := Button.new()
	b.text = "PRÓXIMO" if tut_step < steps.size() - 1 else "ENTENDIDO — INICIAR"
	b.pressed.connect(func():
		Sfx.play("confirm")
		tut_step += 1
		if tut_step >= steps.size():
			tutorial_panel.queue_free()
		else:
			_tut_render())
	b.mouse_entered.connect(func(): Sfx.play("bip"))
	var sb_n := StyleBoxTexture.new()
	sb_n.texture = tex_button
	sb_n.region_rect = Rect2(0, 0, 32, 14)
	_set_9slice_margins(sb_n, 4)
	var sb_h := StyleBoxTexture.new()
	sb_h.texture = tex_button
	sb_h.region_rect = Rect2(0, 14, 32, 14)
	_set_9slice_margins(sb_h, 4)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.35))
	v.add_child(b)
	tutorial_panel.add_child(pc)
	create_tween().tween_property(pc, "modulate:a", 1.0, 0.3)


# ------------------------------------------------------------ api para o mundo
func new_day() -> void:
	var period := "MANHÃ"
	lbl_day.text = "DIA %d/%d — %s" % [Game.day, Game.MAX_DAYS, period]
	banner.text = "DIA %d" % Game.day
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 0.0, 2.5).set_delay(0.8)
	banner.position.y = 260
	create_tween().tween_property(banner, "position:y", 250.0, 1.0).set_trans(Tween.TRANS_BACK)
	end_btn.visible = true


func set_sim(on: bool) -> void:
	end_btn.visible = not on
	if on:
		lbl_day.text = "DIA %d/%d — SIMULAÇÃO" % [Game.day, Game.MAX_DAYS]


func set_ui_visible(v: bool) -> void:
	for c in ui.get_children():
		if c != flash_rect and c != alarm_rect and c != banner:
			c.visible = v and c != terminal and c != pause_panel and c != status_panel and c != tooltip


func toast(t: String, dur := 2.2) -> void:
	toast_label.text = t
	toast_t = dur
	toast_label.position.y = 86
	create_tween().tween_property(toast_label, "position:y", 80.0, 0.3).set_trans(Tween.TRANS_BACK)


func subtitle(who: String, text: String) -> void:
	if not bool(Game.settings.subtitles):
		return
	subtitle_label.text = "%s: %s" % [who, text]
	sub_t = 4.0


func flash() -> void:
	flash_rect.color = Color(1, 1, 1, 1)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 1.0)


func alarm() -> void:
	alarm_t = 3.0


func show_npc(n: NPC, pin := false) -> void:
	if pin:
		pinned = n
		pin_t = 4.0


func set_hover(o, n) -> void:
	var show_n = n if n else (pinned if pin_t > 0.0 else null)
	if show_n:
		card_npc = show_n
		card.visible = true
		var st: Dictionary = Game.npc_state[show_n.id]
		card_title.text = show_n.def.name
		card_role.text = show_n.def.get("role", "")
		var stats_arr := [st.fear, st.anger, st.loyalty, st.cred]
		for i in 4:
			stat_rows[i].bar.target = float(stats_arr[i])
			stat_rows[i].val.text = str(int(round(float(stats_arr[i]))))
		# memories
		for c in memory_box.get_children():
			c.queue_free()
		var mem: Array = st.memories
		if mem.is_empty():
			memory_box.add_child(_label("(nenhuma)", 11, Color(0.5, 0.6, 0.55)))
		else:
			for m in mem.slice(maxi(mem.size() - 3, 0)):
				var ml := _label("· " + str(m).substr(0, 50), 11, Color(0.75, 0.85, 0.8))
				ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ml.custom_minimum_size.x = 260
				memory_box.add_child(ml)
		var content: Control = card.get_child(1)
		card.size = Vector2(300, maxf(content.get_combined_minimum_size().y, 60.0))
		card.position = Vector2(12, 720 - 64 - card.size.y)
	else:
		card.visible = false
	if o:
		tooltip.visible = true
		tooltip_label.text = "%s  [%s]" % [o.def.name, ", ".join(o.display_tags())]
		tooltip.position = get_viewport().get_mouse_position() + Vector2(14, -30)
		var tc: Control = tooltip.get_child(1)
		tooltip.size = tc.get_combined_minimum_size()
	else:
		tooltip.visible = false
	var held = world.held
	held_panel.visible = held != null
	if held:
		held_label.text = "Segurando: %s\nClique para soltar | Direito = cancelar" % held.def.name


func _process(delta: float) -> void:
	pin_t = maxf(pin_t - delta, 0.0)
	toast_t = maxf(toast_t - delta, 0.0)
	sub_t = maxf(sub_t - delta, 0.0)
	toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
	subtitle_label.modulate.a = clampf(sub_t, 0.0, 1.0)
	if alarm_t > 0.0:
		alarm_t -= delta
		alarm_rect.color.a = 0.25 * (0.5 + 0.5 * sin(alarm_t * 12.0))
	else:
		alarm_rect.color.a = 0.0
	if world.phase != 3:
		if not world.sim_running and world.phase == 0:
			lbl_day.text = "DIA %d/%d — %s" % [Game.day, Game.MAX_DAYS, "MANHÃ"]
		elif world.sim_running:
			var c: float = world.clock
			lbl_day.text = "DIA %d/%d — %s" % [Game.day, Game.MAX_DAYS, "MANHÃ" if c < 12.0 else ("TARDE" if c < 18.0 else "NOITE")]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if terminal.visible:
				close_terminal()
				world.terminal_cancel()
			elif tutorial_panel and is_instance_valid(tutorial_panel) and not tutorial_panel.is_queued_for_deletion():
				pass
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and not terminal.visible:
			toggle_status()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------ inner classes
class InstabBar extends Control:
	var value := 5.0
	var shown := 5.0
	var tex_frame: Texture2D
	var tex_fill: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(320, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		shown = lerpf(shown, value, minf(d * 3.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		if tex_frame:
			draw_texture_rect(tex_frame, Rect2(Vector2.ZERO, size), false)
		if tex_fill:
			var fill_w: float = (size.x - 8.0) * clampf(shown / 100.0, 0.0, 1.0)
			var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * (3.0 + shown / 8.0))
			var src_w := float(tex_fill.get_width()) * clampf(shown / 100.0, 0.0, 1.0)
			draw_texture_rect_region(tex_fill, Rect2(4, 4, fill_w, size.y - 8), Rect2(0, 0, src_w, tex_fill.get_height()), Color(pulse, pulse, pulse))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y - 6), "%d%%" % int(round(shown)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 1, 1))


class StatBar extends Control:
	var stat_index := 0
	var target := 0.0
	var shown := 0.0
	var tex_fill: Texture2D
	var tex_bg: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(100, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		shown = lerpf(shown, target, minf(d * 5.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		if tex_bg:
			draw_texture_rect(tex_bg, Rect2(Vector2.ZERO, size), false)
		if tex_fill:
			var fill_w: float = size.x * clampf(shown / 100.0, 0.0, 1.0)
			var fh := float(tex_fill.get_height())
			var frame_w := float(tex_fill.get_width()) / 4.0
			var src_w := frame_w * clampf(shown / 100.0, 0.0, 1.0)
			var src_x := float(stat_index) * frame_w
			draw_texture_rect_region(tex_fill, Rect2(0, 0, fill_w, size.y), Rect2(src_x, 0, src_w, fh))


class StatusStatBar extends Control:
	var stat_color := Color.WHITE
	var value := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.18))
		var fill_w := size.x * clampf(value / 100.0, 0.0, 1.0)
		draw_rect(Rect2(0, 1, fill_w, size.y - 2), stat_color)
		draw_rect(Rect2(0, 1, fill_w, 2), stat_color.lightened(0.3))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(2, size.y - 4), "%d" % int(round(value)), HORIZONTAL_ALIGNMENT_LEFT, size.x, 11, Color(1, 1, 1))
