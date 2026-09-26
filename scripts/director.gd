extends Node
## Runtime client for our backend. Gemini credentials remain on the server.
signal ai_error(message: String)
signal butterfly_effect_calculated(data: Dictionary)
signal request_state_changed(waiting: bool)

const SYSTEM_PROMPT := AIContract.SYSTEM_PROMPT
const MAX_RESPONSE_BYTES := 65536
const BLOCKED := ["idiota", "merda", "porra", "caralho", "puta", "viado", "retardado"]
var base_url := ""
var last_source := "local"
var offline_until := 0
var busy := false
var _generation := 0
var _http: HTTPRequest

func _ready() -> void:
	base_url = str(ProjectSettings.get_setting("game/ai/backend_url", "")).trim_suffix("/")
	if OS.has_environment("PARADOXO_BACKEND_URL"):
		base_url = OS.get_environment("PARADOXO_BACKEND_URL").trim_suffix("/")

func is_offensive(text: String) -> bool:
	# UX filter only; moderation must also be enforced by the backend.
	for word in LocalDirector.norm(text).split(" "):
		if BLOCKED.has(word.strip_edges().trim_suffix("!").trim_suffix(".").trim_suffix(",")):
			return true
	return false

func cancel_pending() -> void:
	_generation += 1
	busy = false
	if is_instance_valid(_http):
		_http.cancel_request()
		# Cancellation otherwise leaves the awaiting coroutine suspended.
		_http.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
	request_state_changed.emit(false)

func evaluate_butterfly_effect(player_action: String, gossip: String, npcs_state: Dictionary) -> Dictionary:
	return await simulate({"actions": [{"player_action": player_action.left(500), "narrative": gossip.left(240)}],
		"world_state": {"npcs": npcs_state}, "day": Game.day,
		"instability": Game.instability, "rumors": Game.rumors})

func simulate(payload: Dictionary) -> Dictionary:
	if busy:
		ai_error.emit("Já existe uma simulação em andamento.")
		return {}
	if base_url == "" or Time.get_ticks_msec() < offline_until:
		return _local(payload)
	if not _valid_endpoint():
		return _fallback(payload, "Endereço do serviço de IA inválido. Usando simulação local.")
	busy = true
	_generation += 1
	var generation := _generation
	request_state_changed.emit(true)
	var body := payload.duplicate(true)
	body["schema_version"] = AIContract.VERSION
	body["locale"] = TranslationServer.get_locale()
	body["allowed_npcs"] = Game.NPC_DEFS.keys()
	body["allowed_locations"] = Game.LOCATIONS.keys()
	var request_id := Crypto.new().generate_random_bytes(16).hex_encode()
	body["request_id"] = request_id
	var http := HTTPRequest.new()
	_http = http
	http.timeout = 20.0
	http.body_size_limit = MAX_RESPONSE_BYTES
	http.max_redirects = 0
	add_child(http)
	var err := http.request(base_url + "/simulate", ["Content-Type: application/json", "Idempotency-Key: " + request_id], HTTPClient.METHOD_POST, JSON.stringify(body))
	var response: Array = []
	if err == OK:
		response = await http.request_completed
	if _http == http:
		_http = null
	http.queue_free()
	if generation != _generation:
		return {}
	busy = false
	request_state_changed.emit(false)
	if err != OK or response.is_empty() or response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return _fallback(payload, "Serviço de IA indisponível. Continuando com a simulação local.")
	var parsed = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var result := AIContract.validate(parsed, Game.NPC_DEFS.keys(), Game.LOCATIONS.keys())
	if result.is_empty():
		return _fallback(payload, "A IA retornou uma resposta inválida. Continuando com a simulação local.")
	last_source = "gemini"
	butterfly_effect_calculated.emit(result.duplicate(true))
	return AIContract.to_simulation(result)

func _valid_endpoint() -> bool:
	if base_url.begins_with("https://"):
		return true
	var loopback := RegEx.new()
	loopback.compile("^http://(127\\.0\\.0\\.1|localhost):[0-9]{1,5}(/[a-zA-Z0-9_/-]*)?$")
	return loopback.search(base_url) != null

func _fallback(payload: Dictionary, message: String) -> Dictionary:
	offline_until = Time.get_ticks_msec() + 60000
	ai_error.emit(message)
	return _local(payload)

func _local(payload: Dictionary) -> Dictionary:
	last_source = "local"
	return LocalDirector.generate(payload)
