class_name WorldObject
extends Node2D
## Objeto carregável do mapa.

var id := ""
var def: Dictionary = {}
var hovered := false
var held := false
var t := 0.0
var trail: Array = []
var attached_to = null


func setup(obj_id: String, d: Dictionary, pos: Vector2) -> void:
	id = obj_id
	def = d
	position = pos
	t = randf() * 6.0


func display_tags() -> Array:
	var out: Array = []
	for tg in def.tags:
		if def.get("hidden", false) and tg == "veneno":
			continue
		out.append(tg)
	return out


func drop_to(p: Vector2) -> void:
	held = false
	var tw := create_tween()
	tw.tween_property(self, "position", p, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	t += delta
	if held:
		trail.append(global_position)
		if trail.size() > 8:
			trail.pop_front()
	elif not trail.is_empty():
		trail.pop_front()
	if attached_to:
		position = attached_to.position + Vector2(10 * attached_to.facing, -18)
	queue_redraw()


func _draw() -> void:
	var c: Color = Game.tag_color(def.tags)
	var bob := sin(t * 3.0) * 3.0 if held else 0.0
	for i in trail.size():
		var p: Vector2 = to_local(trail[i]) + Vector2(0, bob)
		draw_circle(p, 1.0 + i * 0.25, Color(c, 0.08 + i * 0.05))
	if held:
		draw_circle(Vector2(0, bob), 16, Color(c, 0.18))
	elif hovered:
		draw_circle(Vector2.ZERO, 14, Color(c, 0.3))
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	draw_rect(Rect2(-6, -6 + bob, 12, 12), c)
	draw_rect(Rect2(-6, -6 + bob, 12, 12), Color(0, 0, 0, 0.7), false, 1.0)
	draw_rect(Rect2(-2, -4 + bob, 3, 3), Color(1, 1, 1, 0.4 + 0.3 * pulse))
