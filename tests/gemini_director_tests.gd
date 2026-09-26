extends Node
## No external network or real key: the request boundary is replaced by a stub.
const DirectorScript := preload("res://scripts/gemini_director.gd")
var failures := 0
var assertions := 0
var results: Array[Dictionary] = []
var errors: Array[String] = []

class FakeDirector extends DirectorScript:
	var sends := 0
	var sent_body := {}
	var send_error: Error = OK

	func _send_request(_url: String, payload: String) -> Error:
		sends += 1
		sent_body = JSON.parse_string(payload)
		return send_error


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)


func effect() -> Dictionary:
	return {"instability_delta": 18, "npc_updates": [{"npc_id": "npc_baker",
		"dialogue_bubble": "Precisamos investigar o poço.", "new_state": "AFRAID",
		"target_node_to_move": "well", "fear_level": 60, "anger_level": 30, "loyalty_level": 40}]}


func begin(director: Node) -> void:
	director.evaluate_butterfly_effect("Mover frasco ao poço", "O rei mandou envenenar a água", {"npc_baker": {"fear": 30, "anger": 20}})


func complete(director: Node, data: Variant) -> void:
	var envelope := {"candidates": [{"finishReason": "STOP", "content": {"parts": [{"text": JSON.stringify(data)}]}}]}
	director._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())


func _ready() -> void:
	var director := FakeDirector.new()
	director.api_key = "test-placeholder-not-a-real-key"
	add_child(director)
	director.butterfly_effect_calculated.connect(func(data: Dictionary): results.append(data))
	director.ai_error.connect(func(message: String): errors.append(message))
	check(director.get_node("GeminiHTTPRequest") is HTTPRequest, "HTTP child created dynamically")
	begin(director)
	var first_id: int = director._request_id
	check(director.is_processing, "request enters processing state")
	check(director.sent_body.generationConfig.response_mime_type == "application/json", "JSON MIME configured")
	check(director.sent_body.has("system_instruction"), "system instruction separated from player input")
	var input_data: Dictionary = JSON.parse_string(director.sent_body.contents[0].parts[0].text)
	check(input_data.has_all(["player_action", "gossip", "npcs_state"]), "action gossip and states included")
	begin(director)
	check(director.sends == 1 and errors.is_empty(), "duplicate ignored without disturbing pending request")
	complete(director, effect())
	check(results.size() == 1 and results[0].instability_delta == 18, "nested response decoded")
	check(typeof(results[0].instability_delta) == TYPE_INT and not director.is_processing, "integer contract and idle state")
	complete(director, effect())
	check(results.size() == 1, "late completion ignored")
	begin(director)
	director._on_timeout(first_id)
	check(director.is_processing, "old timer cannot cancel a new request")
	director._on_timeout(director._request_id)
	check(not director.is_processing and errors.back().contains("15 segundos"), "timeout cancels and reports latency")
	for envelope in [{}, {"candidates": []}, {"candidates": [null]}, {"candidates": [{"content": {"parts": []}}]}, {"candidates": [{"finishReason": "SAFETY"}]}]:
		begin(director)
		var count := errors.size()
		director._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())
		check(errors.size() == count + 1 and not director.is_processing, "incomplete or blocked envelope rejected")
	for bad in [{"npc_updates": []}, {"instability_delta": 46, "npc_updates": []}, {"instability_delta": 0.5, "npc_updates": []}, {"instability_delta": true, "npc_updates": []}]:
		begin(director)
		var count := errors.size()
		complete(director, bad)
		check(errors.size() == count + 1 and not director.is_processing, "invalid effect rejected")
	for mutation in [{"target_node_to_move": "/root/Game"}, {"npc_id": "unknown"}, {"fear_level": 101}, {"new_state": "EXECUTE"}, {"dialogue_bubble": "x".repeat(241)}]:
		var data := effect()
		data.npc_updates[0].merge(mutation, true)
		begin(director)
		var count := errors.size()
		complete(director, data)
		check(errors.size() == count + 1, "unsafe NPC directive rejected")
	begin(director)
	director._on_request_completed(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), PackedByteArray())
	check(not director.is_processing and errors.back().contains("429"), "HTTP status reported")
	begin(director)
	director._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(not director.is_processing and errors.back().contains("transporte"), "transport failure handled")
	director.send_error = ERR_CANT_CONNECT
	begin(director)
	check(not director.is_processing, "immediate request failure clears state")
	director.send_error = OK
	director.api_key = ""
	begin(director)
	check(not director.is_processing and errors.back().contains("GEMINI_API_KEY"), "missing key handled locally")
	director.api_key = "test-placeholder-not-a-real-key"
	begin(director)
	var count := errors.size()
	var started := Time.get_ticks_msec()
	Engine.time_scale = 20.0
	await get_tree().create_timer(15.3, true, false, true).timeout
	Engine.time_scale = 1.0
	check(not director.is_processing and errors.size() == count + 1, "real timer expires exactly one request")
	check(Time.get_ticks_msec() - started >= 15000, "deadline uses real time despite game speed")
	director.queue_free()
	await get_tree().process_frame
	print("GEMINI RESULT: %d assertions, %d failures" % [assertions, failures])
	get_tree().quit(1 if failures else 0)
