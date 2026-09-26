extends CanvasLayer
## HUD do gameplay: relógio, PA, barra de Instabilidade, card de NPC, terminal de narrativa,
## tutorial, painel de status (TAB), pausa.

var world
var ui: Control
var lbl_day: Label
var ap_icons: APIcons
var bar: InstabBar
var card: PanelContainer
var card_label: Label
var card_bars: Control
var held_panel: PanelContainer
var held_label: Label
var end_btn: Button
var terminal: PanelContainer
var term_input: LineEdit
var term_count: Label
var term_err: Label
var term_sub: Label
var subtitle_label: Label
var toast_label: Label
var banner: Label
var tooltip: Label
var status_panel: PanelContainer
var status_label: Label
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


class APIcons extends Control:
	var ap := 3

	func _init() -> void:
		custom_minimum_size = Vector2(120, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 3:
			var c := Vector2(16 + i * 34, 15)
			var col := Color(1.0, 0.82, 0.25) if i < ap else Color(0.25, 0.25, 0.28)
			var flap := 1.0 + (0.15 * sin(Time.get_ticks_msec() * 0.008 + i) if i < ap else 0.0)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(-13 * flap, -10), c + Vector2(-11 * flap, 8)]), col)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(13 * flap, -10), c + Vector2(11 * flap, 8)]), col)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 8), col.darkened(0.5), 2.0)

	func _process(_d: float) -> void:
		queue_redraw()


class InstabBar extends Control:
	var value := 5.0
	var shown := 5.0
	var colorblind := false

	func _init() -> void:
		custom_minimum_size = Vector2(320, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _col(t: float) -> Color:
		if colorblind:
			return Color(0.27, 0.0, 0.33).lerp(Color(0.13, 0.57, 0.55), clampf(t * 2.0, 0, 1)).lerp(Color(0.99, 0.9, 0.14), clampf(t * 2.0 - 1.0, 0, 1))
		if t < 0.33:
			return Color(0.2, 0.8, 0.3).lerp(Color(0.95, 0.85, 0.2), t / 0.33)
		if t < 0.66:
			return Color(0.95, 0.85, 0.2).lerp(Color(0.95, 0.5, 0.15), (t - 0.33) / 0.33)
		return Color(0.95, 0.5, 0.15).lerp(Color(0.9, 0.1, 0.1), (t - 0.66) / 0.34)

	func _process(d: float) -> void:
		shown = lerpf(shown, value, minf(d * 3.0, 1.0))
		colorblind = bool(Game.settings.colorblind)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * (3.0 + shown / 8.0))
		var n := 40
		var full := int(n * shown / 100.0)
		var seg := (size.x - 6.0) / n
		for i in full:
			var c := _col(float(i) / n)
			draw_rect(Rect2(3 + i * seg, 3, seg - 1.0, size.y - 6), Color(c.r * pulse, c.g * pulse, c.b * pulse))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.9, 0.8, 0.8), false, 1.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y - 8), "%d%%" % int(round(shown)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1))


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Game.ui_theme
	add_child(ui)

	# ---- topo esquerdo
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 12)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tl)
	lbl_day = _label("", 20, Color(1.0, 0.85, 0.35))
	tl.add_child(lbl_day)
	ap_icons = APIcons.new()
	tl.add_child(ap_icons)
	var ap_l := _label("PONTOS DE AÇÃO", 11, Color(0.6, 0.8, 0.7))
	tl.add_child(ap_l)

	# ---- topo direito
	var top_right := VBoxContainer.new()
	top_right.position = Vector2(1280 - 346, 12)
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top_right)
	top_right.add_child(_label("INSTABILIDADE SOCIAL", 12, Color(0.8, 0.95, 0.85)))
	bar = InstabBar.new()
	top_right.add_child(bar)
	Game.instability_changed.connect(func(v): bar.value = v)
	Game.ap_changed.connect(func(v): ap_icons.ap = v)
	bar.value = Game.instability
	bar.shown = Game.instability
	ap_icons.ap = Game.ap

	# ---- card de NPC
	card = PanelContainer.new()
	card.position = Vector2(16, 720 - 190)
	card.custom_minimum_size = Vector2(300, 170)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(card)
	card_label = _label("", 13, Color(0.85, 1.0, 0.9))
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label.custom_minimum_size.x = 272
	card.add_child(card_label)

	# ---- objeto em mãos
	held_panel = PanelContainer.new()
	held_panel.position = Vector2(1280 - 340, 720 - 100)
	held_panel.visible = false
	held_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_label = _label("", 13, Color(0.85, 1.0, 0.9))
	held_panel.add_child(held_label)
	ui.add_child(held_panel)

	# ---- encerrar dia
	end_btn = Button.new()
	end_btn.text = "[ ENCERRAR DIA ]"
	end_btn.position = Vector2(560, 720 - 52)
	end_btn.custom_minimum_size = Vector2(160, 36)
	end_btn.pressed.connect(func(): world.end_day_requested())
	end_btn.mouse_entered.connect(func(): Sfx.play("bip"))
	ui.add_child(end_btn)

	# ---- tooltip de objeto
	tooltip = _label("", 12, Color(1, 1, 1))
	tooltip.add_theme_stylebox_override("normal", Game.box(Color(0, 0, 0, 0.8), Color(0.35, 0.9, 0.55), 1, 4))
	tooltip.visible = false
	ui.add_child(tooltip)

	# ---- legendas / toast / banner
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


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------ terminal de narrativa
func _build_terminal() -> void:
	terminal = PanelContainer.new()
	terminal.visible = false
	terminal.position = Vector2(290, 250)
	terminal.custom_minimum_size = Vector2(700, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	terminal.add_child(v)
	v.add_child(_label("// INSERINDO NARRATIVA NA LINHA DO TEMPO //", 18, Color(0.5, 1.0, 0.7)))
	term_sub = _label("O que os moradores saberão sobre este objeto aqui?", 14, Color(0.7, 1.0, 0.8))
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
	v.add_child(_label("[ENTER] confirmar    [ESC] cancelar (não gasta PA)", 12, Color(0.6, 0.8, 0.7)))
	ui.add_child(terminal)
	terminal.modulate = Color(1, 1, 1, 0.94)


func open_terminal(obj_name: String, loc_name: String) -> void:
	term_sub.text = "%s deixado em: %s.  O que os moradores saberão sobre isto?" % [obj_name, loc_name]
	term_input.text = ""
	term_err.text = ""
	term_count.text = "80 restantes"
	terminal.visible = true
	term_input.call_deferred("grab_focus")


func close_terminal() -> void:
	terminal.visible = false
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
		term_err.text = "A Agência não autoriza este tipo de boato. Tente de novo."
		Sfx.play("error")
		return
	close_terminal()
	world.terminal_submit(t)


# ------------------------------------------------------------ status (TAB) / pausa
func _build_status() -> void:
	status_panel = PanelContainer.new()
	status_panel.position = Vector2(340, 110)
	status_panel.visible = false
	status_label = _label("", 13, Color(0.85, 1.0, 0.9))
	status_panel.add_child(status_label)
	ui.add_child(status_panel)


func toggle_status() -> void:
	status_panel.visible = not status_panel.visible
	if status_panel.visible:
		var s := "// STATUS DOS MORADORES //\n\n%-16s %5s %6s %8s %6s\n" % ["NOME", "MEDO", "RAIVA", "LEALDADE", "CRED."]
		for id in Game.NPC_DEFS:
			var st: Dictionary = Game.npc_state[id]
			s += "%-16s %5d %6d %8d %6d\n" % [Game.NPC_DEFS[id].name, st.fear, st.anger, st.loyalty, st.cred]
		status_label.text = s


func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	pause_panel.add_child(dim)
	var pc := PanelContainer.new()
	pc.name = "Menu"
	pc.position = Vector2(500, 200)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(_label("// PAUSA //", 22, Color(1.0, 0.85, 0.35)))
	for item in [["[ CONTINUAR ]", "resume"], ["[ REINICIAR DIA ]", "restart"], ["[ CONFIGURAÇÕES ]", "settings"], ["[ MENU PRINCIPAL ]", "menu"], ["[ SAIR ]", "quit"]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(_pause_action.bind(item[1]))
		b.mouse_entered.connect(func(): Sfx.play("bip"))
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
		["MOVA", "Leve o objeto para outro local e clique para soltá-lo. (Clique direito solta sem boato.)", Vector2(400, 240)],
		["NARRATIVA", "Digite o boato que conecta o objeto ao caos. ENTER confirma (1 PA), ESC cancela.", Vector2(290, 150)],
		["OBSERVE", "A IA fará o resto. Você é apenas o catalisador.", Vector2(400, 240)],
		["INSTABILIDADE", "Quando a barra chegar a 100%, o Rei cai. Você tem 3 dias.  [Z] desfaz  [TAB] status  [WASD] câmera", Vector2(330, 120)],
	]
	var s: Array = steps[tut_step]
	var pc := PanelContainer.new()
	pc.position = s[2]
	pc.custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(_label("PASSO %d/%d — %s" % [tut_step + 1, steps.size(), s[0]], 18, Color(1.0, 0.85, 0.35)))
	var t := _label(s[1], 15, Color(0.85, 1.0, 0.9))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 530
	v.add_child(t)
	var b := Button.new()
	b.text = "[ PRÓXIMO ]" if tut_step < steps.size() - 1 else "[ ENTENDIDO — INICIAR ]"
	b.pressed.connect(func():
		Sfx.play("confirm")
		tut_step += 1
		if tut_step >= steps.size():
			tutorial_panel.queue_free()
		else:
			_tut_render())
	b.mouse_entered.connect(func(): Sfx.play("bip"))
	v.add_child(b)
	tutorial_panel.add_child(pc)


# ------------------------------------------------------------ api para o mundo
func new_day() -> void:
	var period := "MANHÃ"
	lbl_day.text = "DIA %d/%d — %s" % [Game.day, Game.MAX_DAYS, period]
	banner.text = "DIA %d" % Game.day
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 2.5).set_delay(0.8)
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
		var mem: Array = st.memories
		var lines := "%s — %s\n" % [show_n.def.name, show_n.def.role]
		lines += "Medo      %s %d\n" % [_meter(st.fear), st.fear]
		lines += "Raiva     %s %d\n" % [_meter(st.anger), st.anger]
		lines += "Lealdade  %s %d\n" % [_meter(st.loyalty), st.loyalty]
		lines += "Credulid. %s %d\n" % [_meter(st.cred), st.cred]
		lines += "Memórias:\n"
		if mem.is_empty():
			lines += "  (nenhuma)"
		else:
			for m in mem.slice(maxi(mem.size() - 2, 0)):
				lines += "  · " + str(m).substr(0, 44) + "\n"
		card_label.text = lines
	else:
		card.visible = false
	if o:
		tooltip.visible = true
		tooltip.text = "%s  [%s]" % [o.def.name, ", ".join(o.display_tags())]
		tooltip.position = get_viewport().get_mouse_position() + Vector2(14, -30)
	else:
		tooltip.visible = false
	var held = world.held
	held_panel.visible = held != null
	if held:
		held_label.text = "[OBJETO ATUAL]: %s\nCLIQUE ESQUERDO para soltar\nCLIQUE DIREITO para cancelar" % held.def.name


func _meter(v) -> String:
	var n := int(round(float(v) / 10.0))
	return "[" + "#".repeat(n) + ".".repeat(10 - n) + "]"


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
			var period := "MANHÃ"
			lbl_day.text = "DIA %d/%d — %s" % [Game.day, Game.MAX_DAYS, period]
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
