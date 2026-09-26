extends Node
## Exercises the real HUD -> World -> Gemini HTTP boundary -> NPC/HUD route.
const WorldScript := preload("res://scripts/world.gd")
const GeminiScript := preload("res://scripts/gemini_director.gd")
var failures := 0
var assertions := 0

class FakeGemini extends GeminiScript:
	var sends := 0
	var input_data := {}
	var spinner_at_send := false

	func _ready() -> void:
		api_key = "test-only-placeholder"
		super._ready()

	func _send_request(_url: String, payload: String) -> Error:
		sends += 1
		var body: Dictionary = JSON.parse_string(payload)
		input_data = JSON.parse_string(body.contents[0].parts[0].text)
		spinner_at_send = get_parent().hud.loading_panel.visible
		return OK

	func respond(data: Dictionary) -> void:
		var body := {"candidates": [{"finishReason": "STOP", "content": {"parts": [{"text": JSON.stringify(data)}]}}]}
		_on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(body).to_utf8_buffer())

class TestWorld extends WorldScript:
	func _create_gemini_director() -> GeminiDirector:
		return FakeGemini.new()


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)


func update(id: String, destination: String, state := "RUN") -> Dictionary:
	return {"npc_id": id, "dialogue_bubble": "Precisamos investigar!", "new_state": state,
		"target_node_to_move": destination, "fear_level": 70, "anger_level": 45, "loyalty_level": 20}


func _ready() -> void:
	Game.persistence_enabled = false
	Game.reset()
	var world := TestWorld.new()
	world.ai_fallback_enabled = false
	add_child(world)
	var gemini := world.gemini_director as FakeGemini
	check(world.get_node("GeminiDirector") == gemini, "world owns the Gemini node")
	var baker: NPC = world.npcs.npc_baker
	baker.fear = 86
	baker.anger = 64
	var original_position := baker.global_position
	world._try_pick(world.objects.poison_apple)
	world._open_drop_terminal(Game.loc_pos("well"))
	world.hud.term_input.text_submitted.emit("O rei mandou envenenar a água")
	check(gemini.sends == 1 and gemini.spinner_at_send, "Enter starts HTTP with spinner already visible")
	check(world.ai_waiting and world.phase == world.Phase.SIM and not world.player.input_enabled, "waiting locks player input")
	check(gemini.input_data.player_action.contains("poison_apple") and gemini.input_data.player_action.contains("well"), "physical action includes object and destination")
	check(gemini.input_data.gossip == "O rei mandou envenenar a água", "gossip reaches Gemini unchanged")
	check(gemini.input_data.npcs_state.npc_baker.fear == 86 and gemini.input_data.npcs_state.npc_baker.anger == 64, "payload reads live scene stats")
	check(gemini.input_data.npcs_state.npc_baker.position.x == original_position.x, "payload reads global scene position")
	check(gemini.input_data.npcs_state.has("villager_farmer"), "ordinary villagers are included")
	check(Game.ap == 2 and world.actions_today.is_empty(), "confirmation AP not spent while waiting")
	world.hud.term_input.text_submitted.emit("Enviar de novo")
	world.end_day_requested()
	check(gemini.sends == 1 and Game.day == 1, "double Enter and end-day cannot race pending request")
	await get_tree().create_timer(0.1).timeout
	check(baker.global_position == original_position, "NPC frozen during HTTP wait")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/gemini_waiting.png")
	var data := {"instability_delta": 20, "npc_updates": [update("npc_baker", "well"), update("villager_farmer", "npc_guard")]}
	gemini.respond(data)
	check(not world.ai_waiting and not world.hud.loading_panel.visible, "valid response hides spinner")
	check(Game.ap == 1 and world.held == null and world.actions_today.size() == 1, "action committed exactly once")
	check(baker.bubble_label.visible and baker.bubble_label.text == "Precisamos investigar!", "NPC bubble updated")
	check(baker.navigation_agent.target_position == world.location_nodes.well.global_position and baker.running, "location global position sent to navigation agent")
	var farmer: NPC = world._ai_actors().villager_farmer
	check(farmer.navigation_agent.target_position == world.npcs.npc_guard.global_position, "NPC destination works for villagers")
	check(baker.fear == 70 and Game.npc_state.npc_baker.fear == 70, "scene and persistent stats agree")
	check(Game.instability == 25 and Game.rumors == 1, "delta and rumor applied once")
	world._on_caos_gerado(data)
	check(Game.instability == 25 and Game.rumors == 1, "duplicate result ignored")
	await get_tree().create_timer(1.6).timeout
	check(absf(world.hud.bar.value - 25) < 0.1, "instability bar animates to authoritative value")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/gemini_result.png")
	await world._finish_sim()
	check(Game.day == 1 and Game.instability == 25 and world.phase == world.Phase.ACTION, "reaction finishes without advancing day or reapplying delta")
	world.undo()
	check(Game.ap == 1 and world.actions_today.size() == 1, "resolved action cannot refund AP without undoing consequences")
	world._on_player_gossip(baker)
	world.hud.term_input.text_submitted.emit("O rei esconde um segredo")
	check(gemini.input_data.player_action.contains("Sussurrou") and gemini.sends == 2, "direct whisper also reaches Gemini")
	gemini._on_request_completed(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), PackedByteArray())
	check(not world.hud.loading_panel.visible and world.hud.terminal.visible, "error restores terminal and hides spinner")
	check(world.hud.term_input.text == "O rei esconde um segredo" and Game.ap == 1, "retry preserves text and AP")
	world.hud.term_input.text_submitted.emit(world.hud.term_input.text)
	gemini.respond({"instability_delta": 0, "npc_updates": []})
	await world._finish_sim()
	check(Game.ap == 0 and Game.day == 1 and Game.instability == 25, "retry success charges whisper once")
	world.end_day_requested()
	world.end_day_requested()
	await world._finish_sim()
	check(Game.day == 2 and gemini.sends == 3 and Game.instability == 25, "end-day advances once without second inference")
	world._on_player_gossip(baker)
	gemini.api_key = ""
	world.hud.term_input.text_submitted.emit("O rei esconde outro segredo")
	check(world.hud.terminal.visible and not world.ai_waiting and not world.hud.loading_panel.visible, "synchronous missing-key error restores UI")
	check(Game.ap == Game.AP_PER_DAY, "missing-key error does not consume AP")
	gemini.api_key = "test-only-placeholder"
	world.hud.term_input.text_submitted.emit(world.hud.term_input.text)
	gemini._on_timeout(gemini._request_id)
	check(world.hud.terminal.visible and not world.ai_waiting and Game.ap == Game.AP_PER_DAY, "timeout allows retry without charge")
	world.hud.term_input.text_submitted.emit(world.hud.term_input.text)
	world.queue_free()
	await get_tree().process_frame
	for player in Sfx.players:
		player.stop()
	await get_tree().create_timer(0.1).timeout
	print("GEMINI WORLD RESULT: %d assertions, %d failures" % [assertions, failures])
	get_tree().quit(1 if failures else 0)
