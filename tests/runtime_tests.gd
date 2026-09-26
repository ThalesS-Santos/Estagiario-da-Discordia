extends Node
## Run this scene headless; saves are isolated under the ignored .godot directory.
var failures := 0
var assertions := 0
var server := TCPServer.new()
var peer: StreamPeerTCP
var http_buffer := ""
var mock_body := ""
var mock_status := 200
var hold_response := false


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)


func packet() -> Dictionary:
	return {"schema_version": 1, "instability_delta": 18, "npc_updates": [{
		"npc_id": "npc_baker", "dialogue_bubble": "Vamos investigar o poço.",
		"new_state": "WALK", "target_node_to_move": "well",
		"fear_level": 65, "anger_level": 35, "loyalty_level": 30}]}


func valid(data) -> bool:
	return not AIContract.validate(data, Game.NPC_DEFS.keys(), Game.LOCATIONS.keys()).is_empty()


func _ready() -> void:
	Game.persistence_enabled = false
	Director.base_url = ""
	_test_contract()
	_test_local()
	await _test_network()
	await _test_world()
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	get_tree().quit(1 if failures else 0)


func _test_contract() -> void:
	check(valid(packet()), "valid Gemini response accepted")
	for value in [null, [], "```json", {"schema_version": 5}, {"events": []}]:
		check(not valid(value), "invalid root rejected")
	for value in ["18", true, INF, NAN, 46, -21, {}, []]:
		var data := packet()
		data.instability_delta = value
		check(not valid(data), "invalid delta rejected")
	for mutation in [{"npc_id": "../../root"}, {"new_state": "EXECUTE"}, {"target_node_to_move": "/root/Game"}, {"fear_level": "50"}, {"fear_level": 101}, {"anger_level": 2.5}, {"dialogue_bubble": "a".repeat(241)}]:
		var data := packet()
		data.npc_updates[0].merge(mutation, true)
		check(not valid(data), "invalid directive rejected")
	var duplicate := packet()
	duplicate.npc_updates.append(duplicate.npc_updates[0].duplicate())
	check(not valid(duplicate), "duplicate NPC rejected")
	check(valid({"schema_version": 1, "instability_delta": 0, "npc_updates": []}), "no-op accepted")


func _test_local() -> void:
	var action := {"object_id": "bread", "object_name": "Pão da Padaria", "tags": ["comida"], "location": "bakery", "narrative": "xyzxyzxyzxyz"}
	var unrelated := LocalDirector._action(action, 1, 0)
	check(unrelated.delta == 2.0, "object name cannot validate unrelated gossip")
	action.narrative = "O Rei mandou roubar o pão da padaria"
	var calm := LocalDirector._action(action, 1, 0, {"npc_baker": {"credulity": 20, "fear": 0, "anger": 0, "loyalty": 100}})
	var angry := LocalDirector._action(action, 1, 0, {"npc_baker": {"credulity": 90, "fear": 90, "anger": 90, "loyalty": 0}})
	check(angry.delta > calm.delta, "local director reacts to current social state")


func _test_network() -> void:
	var listen_error := server.listen(18769, "127.0.0.1")
	check(listen_error == OK, "mock HTTP server starts")
	if listen_error != OK:
		return
	Director.base_url = "http://127.0.0.1:18769"
	mock_body = JSON.stringify(packet())
	var result: Dictionary = await Director.simulate({"actions": []})
	check(Director.last_source == "gemini" and result.npc_updates.size() == 1, "HTTP valid output adapted")
	check(not Director.busy, "busy cleared after success")
	mock_body = "not json"
	result = await Director.simulate({"actions": []})
	check(Director.last_source == "local" and result.has("events"), "malformed HTTP body falls back")
	Director.offline_until = 0
	mock_status = 429
	result = await Director.simulate({"actions": []})
	check(Director.last_source == "local" and Director.offline_until > Time.get_ticks_msec(), "rate limit opens cooldown")
	Director.offline_until = 0
	mock_status = 200
	hold_response = true
	get_tree().create_timer(0.1).timeout.connect(Director.cancel_pending)
	result = await Director.simulate({"actions": []})
	check(result.is_empty() and not Director.busy, "cancel does not apply a late result")
	if peer:
		peer.disconnect_from_host()
	peer = null
	server.stop()
	Director.base_url = ""
	Director.offline_until = 0


func _process(_delta: float) -> void:
	if server.is_connection_available():
		peer = server.take_connection()
		http_buffer = ""
	if peer == null:
		return
	peer.poll()
	if peer.get_available_bytes() > 0:
		http_buffer += peer.get_utf8_string(peer.get_available_bytes())
	if http_buffer.contains("\r\n\r\n") and not hold_response:
		var bytes := mock_body.to_utf8_buffer()
		var headers := "HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [mock_status, bytes.size()]
		peer.put_data(headers.to_utf8_buffer())
		peer.put_data(bytes)
		peer = null


func _test_world() -> void:
	Game.reset()
	var world = load("res://scripts/world.gd").new()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.1).timeout
	for frame in 180:
		if world.village.navigation.navigation_ready:
			break
		await get_tree().physics_frame
	check(world.village.navigation.navigation_ready, "navigation publishes within three seconds")
	check(world.village.navigation.navigation_polygon.get_polygon_count() > 0, "navigation mesh baked")
	var map: RID = world.get_world_2d().navigation_map
	var route := NavigationServer2D.map_get_path(map, Vector2(190, 360), Vector2(405, 360), true)
	check(route.size() > 2, "route detours around bakery")
	for point in route:
		check(not Rect2(224, 320, 160, 96).has_point(point), "route excludes bakery footprint")
	var npc: NPC = world.npcs.npc_baker
	npc.position = Vector2(190, 440)
	npc.ambient = false
	npc.walk_to(Vector2(205, 440))
	await get_tree().create_timer(0.4).timeout
	check(npc.position.x > 195 and npc.position.distance_to(Vector2(205, 440)) < 8, "agent physically follows route")
	npc.apply_ai_directive(packet().npc_updates[0])
	check(npc.fear == 65 and npc.bubble_label.visible, "directive updates NPC and speech")
	world._try_pick(world.objects.bread)
	world._open_drop_terminal(Vector2(600, 450))
	var before := npc.position
	await get_tree().create_timer(0.1).timeout
	check(npc.position == before and world.hud.terminal.visible, "terminal freezes NPC movement")
	if OS.get_cmdline_user_args().has("--capture"):
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/terminal_review.png")
	world.hud._on_term_submit("O Rei mandou roubar o pão")
	world.hud._on_term_submit("O Rei mandou roubar o pão")
	check(world.actions_today.size() == 1 and Game.ap == 1, "double submit cannot spend twice")
	world.restart_day()
	world.poisoned = true
	world.fish_dead = true
	world.castle_damage = 2
	world.objects.bread.position = Vector2(600, 450)
	Game.world_checkpoint = world._checkpoint()
	var save_path := "res://.godot/test_save_%d.json" % Time.get_ticks_usec()
	Game.persistence_enabled = true
	check(Game.save_game(save_path), "atomic save succeeds")
	Game.reset()
	check(Game.load_game(save_path), "versioned save loads")
	check(Game.world_checkpoint.get("poisoned", false) and Game.world_checkpoint.get("objects", {}).get("bread", {}).get("x", 0) == 600, "world state round trips")
	Game.day = 2
	check(Game.save_game(save_path), "second save preserves backup")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(Game.load_game(save_path) and Game.day == 1, "corrupt save recovers backup")
	Game.persistence_enabled = false
	# Verify the day boundary commits exactly once and checks victory first.
	Game.reset()
	world.sim_events.clear()
	world.sim_idx = 0
	world.sim_end = 100000.0
	world.phase = world.Phase.SIM
	world.sim_running = true
	world.sim_delta = 10
	world.sim_updates = packet().npc_updates
	Engine.time_scale = 20.0
	await world._finish_sim()
	check(Game.day == 2 and Game.instability == 15, "round advances exactly one day")
	check(Game.npc_state.npc_baker.fear == 65, "authoritative NPC update committed")
	await world._finish_sim()
	check(Game.instability == 15 and Game.day == 2, "duplicate finish is ignored")
	var endings := {"victory": 0, "defeat": 0}
	world.victory.connect(func(): endings.victory += 1)
	world.defeat.connect(func(): endings.defeat += 1)
	Game.day = Game.MAX_DAYS
	Game.instability = 90
	world.phase = world.Phase.SIM
	world.sim_running = true
	world.sim_delta = 10
	await world._finish_sim()
	check(endings.victory == 1 and endings.defeat == 0, "100 instability wins on final day")
	check(world.crisis and not npc.is_physics_processing(), "victory disables agents after cutscene")
	world.crisis = false
	Game.instability = 20
	world.phase = world.Phase.SIM
	world.sim_running = true
	world.sim_delta = 0
	await world._finish_sim()
	check(endings.defeat == 1 and Game.day == 3, "final day below 100 loses without day overflow")
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	for player in Sfx.players:
		player.stop()
	await get_tree().create_timer(0.1).timeout
