class_name VillageNavigation
extends NavigationRegion2D
## Explicit ground footprints, not sprite transparency or tree canopies.
## Built from the same placement metadata as Village; shared with physics.

var obstacles: Array[PackedVector2Array] = []
var navigation_ready := false


func build(village: Village) -> void:
	name = "VillageNavigation"
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect(Rect2(8, 8, 1264, 944)))
	for item in village.data.get("placed", []):
		var key: String = item.get("s", "")
		var pos := Vector2(float(item.p[0]), float(item.p[1]))
		if key.begins_with("buildings/"):
			var texture := village.tex(key)
			var width := float(texture.get_width()) * Village.PX
			# Feet baseline is p.y; roof overhang is not solid ground.
			var depth := 128.0 if key.ends_with("temple") or key.ends_with("4x2") else 96.0
			_add_obstacle(_rect(Rect2(pos - Vector2(0, depth), Vector2(width, depth))), source)
		elif key.begins_with("env/tree_"):
			_add_obstacle(_rect(Rect2(pos - Vector2(7, 10), Vector2(14, 12))), source)
	# Castle has a walkable interior and central entrance; never block the throne.
	for rect in [Rect2(448, 0, 24, 224), Rect2(808, 0, 24, 224), Rect2(448, 0, 384, 24), Rect2(448, 200, 160, 24), Rect2(672, 200, 160, 24)]:
		_add_obstacle(_rect(rect), source)
	var lake: Dictionary = village.data.get("lake", {})
	if not lake.is_empty():
		var outline := PackedVector2Array()
		for i in 48:
			var angle := TAU * float(i) / 48.0
			outline.append(Vector2(float(lake.center[0]) + cos(angle) * float(lake.rx), float(lake.center[1]) + sin(angle) * float(lake.ry)))
		_add_obstacle(outline, source)
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = 7.0
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	navigation_polygon = polygon


func _physics_process(_delta: float) -> void:
	# Region and map publication are asynchronous and may need several frames.
	# Do not discard movement orders while the initial map is still empty.
	if NavigationServer2D.region_get_iteration_id(get_rid()) == 0:
		return
	if NavigationServer2D.map_get_closest_point_owner(get_navigation_map(), Vector2(640, 474)) != get_rid():
		return
	navigation_ready = true
	set_physics_process(false)


func _add_obstacle(outline: PackedVector2Array, source: NavigationMeshSourceGeometryData2D) -> void:
	obstacles.append(outline)
	source.add_obstruction_outline(outline)
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	solid.add_child(shape)
	add_child(solid)


static func _rect(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
