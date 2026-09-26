class_name WorldObject
extends Node2D
signal item_dropped(action_context: Dictionary)
## Objeto carregável do mapa, desenhado com o ícone pixel art de assets/gen/props/items.png.

const GEN := "res://assets/gen/"
static var _names: Array = []

var id := ""
var def: Dictionary = {}
var hovered := false
var held := false
var t := 0.0
var trail: Array = []
var attached_to = null

var icon: Sprite2D
var ring: AnimSprite
var shadow: Sprite2D
var drop_tween: Tween


func request_drop(p: Vector2) -> void:
	item_dropped.emit({"object_id": id, "position": p, "location": Game.nearest_location(p)})


func setup(obj_id: String, d: Dictionary, pos: Vector2) -> void:
	id = obj_id
	def = d
	add_to_group("grabbable")
	position = pos
	t = randf() * 6.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _names.is_empty():
		var f := FileAccess.open(GEN + "map.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(parsed) == TYPE_DICTIONARY:
			_names = parsed.meta["props/items"].names
	shadow = Sprite2D.new()
	shadow.texture = load(GEN + "chars/shadow.png")
	shadow.scale = Vector2(1.4, 1.6)
	shadow.modulate = Color(1, 1, 1, 0.8)
	add_child(shadow)
	ring = AnimSprite.new()
	ring.texture = load(GEN + "props/select_ring.png")
	ring.hframes = 4
	ring.fps = 8.0
	ring.scale = Vector2(2, 2)
	ring.visible = false
	add_child(ring)
	icon = Sprite2D.new()
	icon.texture = load(GEN + "props/items.png")
	icon.hframes = maxi(_names.size(), 1)
	var idx := _names.find(id)
	icon.frame = maxi(idx, 0)
	icon.centered = false
	icon.offset = Vector2(-8, -13)
	icon.scale = Vector2(2, 2)
	add_child(icon)


func display_tags() -> Array:
	var out: Array = []
	for tg in def.tags:
		if def.get("hidden", false) and tg == "veneno":
			continue
		out.append(tg)
	return out


func drop_to(p: Vector2) -> void:
	held = false
	if drop_tween:
		drop_tween.kill()
	drop_tween = create_tween()
	drop_tween.tween_property(self, "position", p, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


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
	var bob := sin(t * 3.0) * 3.0 if held else sin(t * 2.0) * 0.8
	icon.position = Vector2(0, bob - (10.0 if held else 0.0))
	icon.scale = Vector2(2.3, 2.3) if (held or hovered) else Vector2(2, 2)
	ring.visible = hovered or held
	ring.modulate = Game.tag_color(def.tags) if held else Color.WHITE
	shadow.visible = attached_to == null
	shadow.scale = Vector2(1.1, 1.3) if held else Vector2(1.4, 1.6)
	z_index = 4 if held else 0
	queue_redraw()


func _draw() -> void:
	if trail.is_empty():
		return
	var c: Color = Game.tag_color(def.tags)
	for i in trail.size():
		var p: Vector2 = to_local(trail[i]) + Vector2(0, -12)
		draw_rect(Rect2(p - Vector2(1, 1) * (1 + i * 0.3), Vector2(2, 2) * (1 + i * 0.3)), Color(c, 0.1 + i * 0.06))
