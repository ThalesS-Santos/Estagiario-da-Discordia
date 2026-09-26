extends Node
## Gerenciador de telas: abertura → menu → registro → briefing → jogo → fim.

const WorldScript := preload("res://scripts/world.gd")
const SettingsScript := preload("res://scripts/settings_panel.gd")

var ui_layer: CanvasLayer
var screen: Control
var world: Node2D
var flash_rect: ColorRect
var seq_id := 0


class Backdrop extends Control:
	var t := 0.0
	var stars: Array = []
	var clouds: Array = []
	var trees: Array = []
	var walkers: Array = []
	var fireflies: Array = []
	var smoke_t: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 160:
			stars.append({p = Vector2(randf() * 1280, randf() * 400), ph = randf() * TAU, sz = randf() * 2.8 + 0.4, ct = randf()})
		for i in 6:
			clouds.append({x = randf() * 1600.0 - 200.0, y = 60.0 + randf() * 180.0, w = 100.0 + randf() * 160.0, sp = 3.0 + randf() * 7.0, a = 0.025 + randf() * 0.035})
		for i in 14:
			var tx := float(i) * 92.0 + randf() * 40.0
			if tx > 780.0 and tx < 1150.0:
				tx = 60.0 + randf() * 120.0
			trees.append({x = tx, y = 558.0 + randf() * 22.0, h = 35.0 + randf() * 50.0, ph = randf() * TAU, lw = 18.0 + randf() * 16.0})
		for i in 4:
			walkers.append({x = randf() * 1280.0, y = 568.0 + randf() * 16.0, sp = 12.0 + randf() * 22.0, dir = [-1.0, 1.0][randi() % 2], h = 16.0 + randf() * 7.0, ph = randf() * TAU})
		for i in 20:
			fireflies.append({x = randf() * 1280.0, y = 380.0 + randf() * 220.0, ph = randf() * TAU, sp = randf() * 0.5 + 0.25, r = randf() * 28.0 + 8.0})
		for i in 8:
			smoke_t.append(randf() * TAU)

	func _process(d: float) -> void:
		t += d
		for w in walkers:
			w.x += w.sp * w.dir * d
			if w.x > 1350.0: w.x = -40.0; w.dir = 1.0
			elif w.x < -50.0: w.x = 1350.0; w.dir = -1.0
		queue_redraw()

	func _draw() -> void:
		_draw_sky()
		_draw_stars()
		_draw_moon()
		_draw_clouds()
		_draw_mountains()
		_draw_castle()
		_draw_village()
		for tree_d in trees:
			_draw_tree(tree_d)
		for w in walkers:
			_draw_walker(w)
		_draw_ground()
		_draw_fireflies()

	func _draw_sky() -> void:
		var c0 := [Color(0.01,0.01,0.06), Color(0.03,0.03,0.12), Color(0.06,0.07,0.2), Color(0.09,0.12,0.3), Color(0.12,0.17,0.38), Color(0.14,0.2,0.42)]
		for i in 36:
			var k := float(i) / 36.0
			var idx := int(k * (c0.size() - 1))
			var nxt := mini(idx + 1, c0.size() - 1)
			var lt := fmod(k * (c0.size() - 1), 1.0)
			draw_rect(Rect2(0, i * 20, 1280, 21), c0[idx].lerp(c0[nxt], lt))

	func _draw_stars() -> void:
		for s in stars:
			var sz := float(s.sz)
			var ph := float(s.ph)
			var ct := float(s.ct)
			var a := 0.25 + 0.75 * absf(sin(t * (0.4 + sz * 0.3) + ph))
			var col := Color(1, 1, 0.9).lerp(Color(0.7, 0.85, 1.0), ct)
			col.a = a
			var p: Vector2 = s.p
			if sz > 2.2:
				draw_rect(Rect2(p.x - 1, p.y, 3, 1), col)
				draw_rect(Rect2(p.x, p.y - 1, 1, 3), col)
			else:
				draw_rect(Rect2(p, Vector2(sz, sz)), col)

	func _draw_moon() -> void:
		var mp := Vector2(160, 100 + sin(t * 0.06) * 4)
		for i in range(5, 0, -1):
			draw_circle(mp, 40.0 + float(i) * 9.0, Color(0.95, 0.9, 0.65, 0.012 * float(i)))
		draw_circle(mp, 40, Color(0.96, 0.94, 0.84))
		draw_circle(mp + Vector2(14, -9), 36, Color(0.03, 0.03, 0.1))
		draw_circle(mp + Vector2(-12, 6), 5, Color(0.88, 0.86, 0.76))
		draw_circle(mp + Vector2(-20, -3), 3.5, Color(0.9, 0.87, 0.78))
		draw_circle(mp + Vector2(-6, 18), 2.5, Color(0.89, 0.86, 0.77))
		draw_circle(mp + Vector2(-16, 12), 2, Color(0.87, 0.84, 0.75))

	func _draw_clouds() -> void:
		for c in clouds:
			var cx := fmod(float(c.x) + t * float(c.sp), 1500.0) - 200.0
			var cy := float(c.y)
			var cw := float(c.w)
			var col := Color(0.4, 0.45, 0.6, float(c.a))
			for j in 5:
				var ox := float(j) * cw * 0.22 - cw * 0.2
				var oy := sin(float(j) * 1.8) * 8.0
				var r := cw * (0.15 + 0.08 * sin(float(j) * 2.3))
				draw_circle(Vector2(cx + ox, cy + oy), r, col)

	func _draw_mountains() -> void:
		var pts := PackedVector2Array()
		pts.append(Vector2(0, 720))
		pts.append(Vector2(0, 470))
		for i in range(1, 25):
			pts.append(Vector2(float(i) * 54.0, 440.0 + sin(float(i) * 0.65 + 1.2) * 50.0 + sin(float(i) * 1.4) * 25.0))
		pts.append(Vector2(1280, 460))
		pts.append(Vector2(1280, 720))
		draw_colored_polygon(pts, Color(0.035, 0.04, 0.09))
		var h2 := PackedVector2Array()
		h2.append(Vector2(0, 720))
		h2.append(Vector2(0, 545))
		for i in range(1, 17):
			h2.append(Vector2(float(i) * 80.0, 525.0 + sin(float(i) * 0.85 + 0.3) * 25.0 + cos(float(i) * 1.6) * 12.0))
		h2.append(Vector2(1280, 535))
		h2.append(Vector2(1280, 720))
		draw_colored_polygon(h2, Color(0.025, 0.035, 0.075))

	func _draw_castle() -> void:
		var bx := 870.0
		var by := 340.0
		var dark := Color(0.02, 0.025, 0.06)
		var dark2 := Color(0.03, 0.035, 0.07)
		draw_rect(Rect2(bx, by, 240, 220), dark)
		draw_rect(Rect2(bx - 30, by - 80, 55, 300), dark)
		draw_rect(Rect2(bx + 215, by - 80, 55, 300), dark)
		draw_rect(Rect2(bx + 85, by - 60, 60, 60), dark)
		for i in 4:
			draw_rect(Rect2(bx - 30 + float(i) * 14, by - 90, 8, 12), dark)
		for i in 4:
			draw_rect(Rect2(bx + 215 + float(i) * 14, by - 90, 8, 12), dark)
		for i in 3:
			draw_rect(Rect2(bx + 88 + float(i) * 16, by - 68, 8, 10), dark)
		for i in 8:
			draw_rect(Rect2(bx + float(i) * 30, by - 4, 16, 10), dark2)
		var pole_x := bx + 115.0
		draw_line(Vector2(pole_x, by - 60), Vector2(pole_x, by - 120), dark, 3.0)
		var fw := sin(t * 3.5) * 6.0
		var flag_col := Color(0.6, 0.15, 0.15, 0.85)
		draw_colored_polygon(PackedVector2Array([Vector2(pole_x + 2, by - 120), Vector2(pole_x + 35 + fw, by - 114), Vector2(pole_x + 30 - fw, by - 102), Vector2(pole_x + 2, by - 96)]), flag_col)
		_draw_tower_roof(Vector2(bx - 3, by - 80), 55.0, 40.0)
		_draw_tower_roof(Vector2(bx + 242, by - 80), 55.0, 40.0)
		_draw_tower_roof(Vector2(bx + 96, by - 60), 48.0, 35.0)
		draw_rect(Rect2(bx + 90, by + 150, 50, 70), Color(0.01, 0.015, 0.04))
		draw_colored_polygon(PackedVector2Array([Vector2(bx + 90, by + 150), Vector2(bx + 115, by + 130), Vector2(bx + 140, by + 150)]), Color(0.01, 0.015, 0.04))
		for j in 3:
			var gx := bx + 94.0 + float(j) * 16.0
			draw_rect(Rect2(gx, by + 155, 4, 65), Color(0.04, 0.05, 0.1))
		for wy in [0, 1]:
			for wx in [0, 1, 2]:
				var wnd_x := bx + 20.0 + float(wx) * 80.0
				var wnd_y := by + 40.0 + float(wy) * 70.0
				var flicker := 0.5 + 0.3 * sin(t * 2.5 + float(wx + wy * 3) * 1.7)
				draw_rect(Rect2(wnd_x, wnd_y, 12, 16), Color(1.0, 0.7, 0.25, flicker))
				draw_rect(Rect2(wnd_x + 5, wnd_y, 2, 16), Color(0.02, 0.025, 0.06, 0.5))
				draw_rect(Rect2(wnd_x, wnd_y + 7, 12, 2), Color(0.02, 0.025, 0.06, 0.5))
		for ti in 2:
			var torch_x := bx + 80.0 + float(ti) * 68.0
			var torch_y := by + 140.0
			draw_rect(Rect2(torch_x, torch_y, 3, 12), Color(0.3, 0.2, 0.1))
			var fsize := 4.0 + sin(t * 6.0 + float(ti) * 2.0) * 1.5
			draw_circle(Vector2(torch_x + 1.5, torch_y - 2), fsize, Color(1.0, 0.6, 0.15, 0.7))
			draw_circle(Vector2(torch_x + 1.5, torch_y - 2), fsize + 4, Color(1.0, 0.5, 0.1, 0.12))

	func _draw_tower_roof(base: Vector2, w: float, h: float) -> void:
		var col := Color(0.04, 0.03, 0.06)
		draw_colored_polygon(PackedVector2Array([Vector2(base.x - 4, base.y), Vector2(base.x + w / 2.0, base.y - h), Vector2(base.x + w + 4, base.y)]), col)

	func _draw_village() -> void:
		var dark := Color(0.02, 0.025, 0.06)
		var houses := [
			{x = 40, y = 556, w = 55, h = 42, roof_h = 24, chimney = true, windows = [0.3]},
			{x = 130, y = 550, w = 65, h = 50, roof_h = 28, chimney = false, windows = [0.25, 0.65]},
			{x = 230, y = 558, w = 50, h = 38, roof_h = 22, chimney = true, windows = [0.4]},
			{x = 320, y = 548, w = 70, h = 52, roof_h = 30, chimney = true, windows = [0.2, 0.6]},
			{x = 430, y = 555, w = 55, h = 44, roof_h = 25, chimney = false, windows = [0.35]},
			{x = 520, y = 552, w = 60, h = 46, roof_h = 26, chimney = true, windows = [0.3, 0.7]},
			{x = 620, y = 560, w = 48, h = 38, roof_h = 22, chimney = false, windows = [0.4]},
			{x = 710, y = 550, w = 58, h = 48, roof_h = 27, chimney = true, windows = [0.25, 0.65]},
		]
		for i in houses.size():
			var hs: Dictionary = houses[i]
			var hx: float = hs.x
			var hy: float = hs.y
			var hw: float = hs.w
			var hh: float = hs.h
			var rh: float = hs.roof_h
			draw_rect(Rect2(hx, hy, hw, hh), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 5, hy), Vector2(hx + hw / 2.0, hy - rh), Vector2(hx + hw + 5, hy)]), dark)
			draw_rect(Rect2(hx + hw * 0.4, hy + hh - 18, 10, 18), Color(0.04, 0.03, 0.05))
			for wf in hs.windows:
				var wff := float(wf)
				var wx2 := hx + hw * wff
				var wy2 := hy + hh * 0.3
				var fl := 0.45 + 0.25 * sin(t * 2.0 + float(i) * 2.1 + wff * 3.0)
				draw_rect(Rect2(wx2 - 4, wy2, 8, 10), Color(1.0, 0.72, 0.28, fl))
			if hs.chimney:
				var cx2 := hx + hw * 0.75
				var cy2 := hy - rh * 0.3
				draw_rect(Rect2(cx2, cy2 - 16, 8, 16 + rh * 0.3), dark)
				var si := i % smoke_t.size()
				var st_val := float(smoke_t[si])
				for sp2 in 4:
					var sage := fmod(t * 0.6 + st_val + float(sp2) * 0.5, 2.5)
					var sx := cx2 + 4.0 + sin(t * 0.8 + float(sp2) + st_val) * (sage * 6.0)
					var sy := cy2 - 16.0 - sage * 18.0
					var sa := maxf(0.0, 0.2 - sage * 0.08)
					draw_circle(Vector2(sx, sy), 3.0 + sage * 2.5, Color(0.5, 0.5, 0.6, sa))

	func _draw_tree(tr: Dictionary) -> void:
		var tx := float(tr.x)
		var ty := float(tr.y)
		var th := float(tr.h)
		var lw := float(tr.lw)
		var tph := float(tr.ph)
		var sway := sin(t * 1.2 + tph) * 3.0
		var trunk_col := Color(0.03, 0.04, 0.06)
		draw_line(Vector2(tx, ty), Vector2(tx + sway * 0.3, ty - th * 0.6), trunk_col, 4.0)
		var crown_y := ty - th * 0.6
		var canopy := PackedVector2Array()
		for a in 12:
			var angle := float(a) / 12.0 * TAU
			var r := lw * (0.8 + 0.2 * sin(angle * 3.0 + tph))
			canopy.append(Vector2(tx + sway + cos(angle) * r, crown_y - th * 0.3 + sin(angle) * r * 0.7))
		draw_colored_polygon(canopy, Color(0.02, 0.06, 0.03, 0.9))
		var canopy2 := PackedVector2Array()
		for a in 10:
			var angle := float(a) / 10.0 * TAU
			var r := lw * 0.65
			canopy2.append(Vector2(tx + sway * 1.1 + cos(angle) * r, crown_y - th * 0.35 + sin(angle) * r * 0.6))
		draw_colored_polygon(canopy2, Color(0.025, 0.07, 0.035, 0.85))

	func _draw_walker(w: Dictionary) -> void:
		var wx := float(w.x)
		var wy := float(w.y)
		var wh := float(w.h)
		var col := Color(0.015, 0.02, 0.05)
		var stride := sin(t * 3.5 + float(w.ph)) * 4.0
		draw_circle(Vector2(wx, wy - wh), wh * 0.22, col)
		draw_line(Vector2(wx, wy - wh * 0.8), Vector2(wx, wy - wh * 0.3), col, 3.0)
		draw_line(Vector2(wx, wy - wh * 0.3), Vector2(wx - stride, wy), col, 2.5)
		draw_line(Vector2(wx, wy - wh * 0.3), Vector2(wx + stride, wy), col, 2.5)
		draw_line(Vector2(wx, wy - wh * 0.65), Vector2(wx + stride * 0.6, wy - wh * 0.4), col, 2.0)
		draw_line(Vector2(wx, wy - wh * 0.65), Vector2(wx - stride * 0.6, wy - wh * 0.4), col, 2.0)

	func _draw_ground() -> void:
		draw_rect(Rect2(0, 598, 1280, 122), Color(0.015, 0.025, 0.05))
		var path_col := Color(0.025, 0.035, 0.065)
		draw_rect(Rect2(0, 600, 850, 14), path_col)
		draw_rect(Rect2(850, 600, 180, 14), path_col.lerp(Color(0.015, 0.025, 0.05), 0.5))
		for i in 50:
			var gx := fmod(float(i) * 27.3 + 5.0, 1280.0)
			var gy := 596.0 + fmod(float(i) * 7.1, 18.0)
			var sw := sin(t * 1.3 + float(i) * 0.7) * 2.0
			var gh := 5.0 + fmod(float(i) * 3.7, 5.0)
			draw_line(Vector2(gx, gy), Vector2(gx + sw, gy - gh), Color(0.04, 0.1, 0.04, 0.45), 1.5)

	func _draw_fireflies() -> void:
		for f in fireflies:
			var fx := float(f.x) + sin(t * float(f.sp) + float(f.ph)) * float(f.r)
			var fy := float(f.y) + cos(t * float(f.sp) * 0.7 + float(f.ph)) * float(f.r) * 0.5
			var fa := 0.2 + 0.8 * maxf(0.0, sin(t * 1.8 + float(f.ph)))
			if fa > 0.1:
				draw_circle(Vector2(fx, fy), 1.5, Color(1.0, 0.92, 0.35, fa * 0.9))
				draw_circle(Vector2(fx, fy), 5.0, Color(1.0, 0.9, 0.3, fa * 0.12))


class Logo extends Control:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var flap := 0.5 + 0.5 * absf(sin(t * 2.8))
		var col := Color(1.0, 0.82, 0.25)
		var glow_a := 0.15 + 0.1 * sin(t * 2.0)
		draw_circle(c, 55, Color(1.0, 0.85, 0.3, glow_a))
		for s in [-1.0, 1.0]:
			var wing_top := PackedVector2Array([c, c + Vector2(s * 55 * flap, -48), c + Vector2(s * 42 * flap, -20), c + Vector2(s * 65 * flap, 0)])
			draw_colored_polygon(wing_top, col)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(s * 45 * flap, 5), c + Vector2(s * 30 * flap, 42)]), col.darkened(0.2))
			draw_line(c, c + Vector2(s * 50 * flap, -40), col.darkened(0.3), 1.5)
			draw_line(c, c + Vector2(s * 55 * flap, -10), col.darkened(0.3), 1.0)
		draw_rect(Rect2(c.x - 2, c.y - 26, 4, 52), Color(0.35, 0.22, 0.1))
		var ant_sway := sin(t * 4.0) * 3.0
		draw_line(Vector2(c.x, c.y - 26), Vector2(c.x - 8 + ant_sway, c.y - 40), Color(0.35, 0.22, 0.1), 1.5)
		draw_line(Vector2(c.x, c.y - 26), Vector2(c.x + 8 - ant_sway, c.y - 40), Color(0.35, 0.22, 0.1), 1.5)
		draw_circle(Vector2(c.x - 8 + ant_sway, c.y - 40), 2, col)
		draw_circle(Vector2(c.x + 8 - ant_sway, c.y - 40), 2, col)
		var h := c + Vector2(0, 80)
		draw_colored_polygon(PackedVector2Array([h + Vector2(-18, -18), h + Vector2(18, -18), h + Vector2(3, -1), h + Vector2(-3, -1)]), Color(0.6, 0.85, 1.0, 0.75))
		var sand := fmod(t * 0.3, 1.0)
		draw_colored_polygon(PackedVector2Array([h + Vector2(-3, 1), h + Vector2(3, 1), h + Vector2(int(18 * sand), 18), h + Vector2(-int(18 * sand), 18)]), Color(0.6, 0.85, 1.0, 0.75))
		draw_line(h + Vector2(0, -2), h + Vector2(0, 2), Color(0.85, 0.95, 1.0, 0.6), 1.5)


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


# ---------------------------------------------------------------- telas
func show_loading() -> void:
	var s := _new_screen()
	_bg(s)
	var logo := Logo.new()
	logo.position = Vector2(540, 150)
	logo.size = Vector2(200, 200)
	s.add_child(logo)
	var title := _lbl(s, "O PARADOXO DO ESTAGIÁRIO", 30, Color(1.0, 0.85, 0.35), Vector2(0, 380))
	var code := _lbl(s, "", 12, Color(0.3, 0.8, 0.5, 0.7), Vector2(240, 440), 800.0, false)
	var bar := ProgressBar.new()
	bar.position = Vector2(390, 560)
	bar.size = Vector2(500, 18)
	bar.show_percentage = false
	s.add_child(bar)
	var my := seq_id
	var tw := create_tween()
	tw.tween_property(bar, "value", 100.0, 3.6).from(0.0)
	var chars := "01ABCDEF{}[]<>=;:/#$%"
	var timer := 0.0
	while tw.is_running() and my == seq_id:
		var line := ""
		for r in 3:
			for i in 70:
				line += chars[randi() % chars.length()]
			line += "\n"
		code.text = line
		title.modulate.a = 0.6 + 0.4 * (1.0 if int(timer * 4.0) % 2 == 0 else 0.4)
		timer += 0.08
		await get_tree().create_timer(0.08).timeout
	if my == seq_id:
		_flash()
		show_menu()


func show_menu() -> void:
	var s := _new_screen()
	var bd := Backdrop.new()
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(bd)
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
			show_briefing())


func show_briefing() -> void:
	var s := _new_screen()
	_bg(s)
	var l := _lbl(s, "", 20, Color(0.7, 1.0, 0.85), Vector2(220, 150), 840.0, false)
	_lbl(s, "[ ESPAÇO / CLIQUE para pular ]", 12, Color(0.4, 0.6, 0.5), Vector2(0, 660))
	var txt := "[ESTÁTICA DE RÁDIO]\n\nOperador %s. Primeiro dia na Agência Panóptico.\n\nSeu briefing: uma aldeia medieval. Coordenadas 14.7-F, Linha Alfa-3. Uma anomalia: o Rei Aldemar I.\n\nProjeção: se este rei permanecer no trono por mais 30 dias, iniciará uma guerra que destruirá a região.\n\nSua missão: removê-lo do trono sem intervenção direta. Sem violência. Sem comunicação com os habitantes. Apenas... o ambiente. Em 3 dias.\n\nBoa sorte, Estagiário." % Game.player_name
	var my := seq_id
	var skip := [false]
	var inp := Control.new()
	inp.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(inp)
	inp.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed):
			skip[0] = true)
	inp.focus_mode = Control.FOCUS_ALL
	inp.grab_focus()
	l.text = txt
	l.visible_characters = 0
	var total := txt.length()
	var i := 0.0
	while i < total and not skip[0] and my == seq_id:
		i += 1.4
		l.visible_characters = int(i)
		if int(i) % 3 == 0:
			Sfx.play("clack")
		await get_tree().create_timer(0.03).timeout
	if my != seq_id:
		return
	l.visible_characters = -1
	if not skip[0]:
		skip[0] = false
		var w := 0.0
		while w < 6.0 and not skip[0] and my == seq_id:
			w += 0.05
			await get_tree().create_timer(0.05).timeout
	else:
		skip[0] = false
		var w2 := 0.0
		while w2 < 4.0 and not skip[0] and my == seq_id:
			w2 += 0.05
			await get_tree().create_timer(0.05).timeout
	if my == seq_id:
		_flash()
		Game.reset()
		start_game(true)


func start_game(new_game: bool) -> void:
	_new_screen()
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
	var credits := "O PARADOXO DO ESTAGIÁRIO\nGame Jam CIMATEC 2026.2 — Tema: Efeito Borboleta\n\n\nDESENVOLVIDO POR\nThales — Backend / IA / Integração\nEduardo — Engine / Gameplay\nDanilo — UI / Assets\n\n\nMOTOR IA\nClaude (Anthropic)\n\n\nENGINE\nGodot 4.x\n\n\nASSETS\nArte procedural gerada por código.\n[listar aqui os assets do itch.io usados, com links]\n\n\nAGRADECIMENTOS\nCIMATEC · Game Jam 2026.2\n\n\n> rm -rf /linha_do_tempo\n> ...\n> Anomalia removida."
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
	_type(l, "Estagiário %s. Você foi demitido.\nA anomalia persiste.\n\n\nMISSÃO FRACASSADA\nA aldeia permanece estável.\nO Rei permanece no trono.\nVocê perdeu seu emprego." % Game.player_name, 40.0)
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
