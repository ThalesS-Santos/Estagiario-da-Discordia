extends Node
## Modo BACKEND do cliente (sem chave no cliente) e reserva local. Sem rede real.
const DirectorScript := preload("res://scripts/gemini_director.gd")
var failures := 0
var assertions := 0
var results: Array[Dictionary] = []
var errors: Array[String] = []

class FakeBackendDirector extends DirectorScript:
	var sends := 0
	var last_url := ""
	var last_body := {}

	func _ready() -> void:
		super._ready()
		backend_url = "https://exemplo.workers.dev"

	func _send_request(url: String, payload: String) -> Error:
		sends += 1
		last_url = url
		last_body = JSON.parse_string(payload)
		return OK


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + message)


func _ready() -> void:
	var d := FakeBackendDirector.new()
	add_child(d)
	d.api_key = ""
	d.butterfly_effect_calculated.connect(func(data): results.append(data))
	d.ai_error.connect(func(m): errors.append(m))
	var states := {"npc_baker": {"fear": 30, "anger": 20}}
	d.evaluate_butterfly_effect("Colocou frasco no poço", "O rei envenenou a água", states, {"day": 2, "instability": 30, "rumors": 1})
	check(d.sends == 1 and d.last_url == "https://exemplo.workers.dev/simulate", "backend mode posts to /simulate")
	check(not d.last_url.contains("key") and not JSON.stringify(d.last_body).contains("api"), "no key travels from the client")
	check(d.last_body.context.day == 2 and d.last_body.gossip.contains("envenenou"), "context and gossip are sent")
	var reply := {"schema_version": 1, "instability_delta": 12, "npc_updates": [{"npc_id": "npc_baker", "dialogue_bubble": "Não bebam!",
		"new_state": "AFRAID", "target_node_to_move": "well", "fear_level": 60, "anger_level": 30, "loyalty_level": 30}]}
	d._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(reply).to_utf8_buffer())
	check(results.size() == 1 and results[0].instability_delta == 12 and not d.is_processing, "backend reply accepted")

	# transporte: 1 nova tentativa automática, depois erro
	d.evaluate_butterfly_effect("a", "b", states)
	var before := d.sends
	d._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(d.sends == before + 1 and d.is_processing, "transport failure retries once")
	d._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(not d.is_processing and errors.size() == 1, "second failure reports an error (world falls back to local)")

	d.evaluate_butterfly_effect("a", "b", states)
	d._on_request_completed(HTTPRequest.RESULT_SUCCESS, 502, PackedStringArray(), "{}".to_utf8_buffer())
	check(not d.is_processing and errors.size() == 2, "HTTP 502 from the backend becomes an error, no retry")

	# reserva local: mesmo contrato do Gemini para qualquer objeto/narrativa
	Game.persistence_enabled = false
	Game.reset()
	var live := {}
	for id in Game.NPC_DEFS:
		var def: Dictionary = Game.NPC_DEFS[id]
		live[id] = {"name": def.name, "fear": def.fear, "anger": def.anger, "loyalty": def.loyalty, "credulity": def.cred}
	var locations: Array = Game.LOCATIONS.keys()
	var validator := DirectorScript.new()
	add_child(validator)
	validator._npc_ids = live.keys()
	validator._location_ids = PackedStringArray(locations)
	for action in [
		{"narrative": "O rei mandou envenenar a água", "tags": ["veneno"], "object_id": "poison_vial", "object_name": "Frasco de veneno", "location": "well"},
		{"narrative": "", "tags": ["comida"], "object_id": "bread", "object_name": "Pão", "location": "bakery"},
		{"narrative": "Sussurro qualquer", "tags": [], "object_id": "", "object_name": "Sussurro", "location": "plaza"},
	]:
		var result := LocalDirector.ai_result({"actions": [action], "world_state": {"npcs": live}, "day": 1, "rumors": 0}, live, locations)
		check(not validator._validate_effect(result).is_empty(), "local fallback passes the Gemini contract: %s" % action.narrative)
		check(result.npc_updates.size() >= 1, "local fallback moves at least one NPC")
	print("AI BACKEND RESULT: %d assertions, %d failures" % [assertions, failures])
	get_tree().quit(1 if failures else 0)
