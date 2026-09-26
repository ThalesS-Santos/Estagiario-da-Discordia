extends Node
## Cliente do backend FastAPI (autoload "Director").
## POST {base_url}/simulate -> roteiro de eventos. Se o backend estiver fora do ar,
## usa o LocalDirector (modo offline, o jogo continua funcionando).

var base_url := "http://127.0.0.1:8000"
var last_source := "local"
var offline_until := 0

const BLOCKED := ["idiota", "merda", "porra", "caralho", "puta", "viado", "retardado"]


func is_offensive(text: String) -> bool:
	var t := LocalDirector.norm(text)
	for w in BLOCKED:
		if t.contains(w):
			return true
	return false


func simulate(payload: Dictionary) -> Dictionary:
	# backend caiu há pouco: não fica esperando de novo, usa o modo offline direto
	if Time.get_ticks_msec() < offline_until:
		return _local(payload)
	var http := HTTPRequest.new()
	http.timeout = 4.0
	add_child(http)
	var err := http.request(base_url + "/simulate", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return _local(payload)
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		offline_until = Time.get_ticks_msec() + 60000
		return _local(payload)
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var v := _validate(parsed)
	if v.is_empty():
		last_source = "fallback"
		return _generic_fallback()
	last_source = "ia"
	return v


func _local(payload: Dictionary) -> Dictionary:
	last_source = "local"
	return LocalDirector.generate(payload)


func _generic_fallback() -> Dictionary:
	return {
		"events": [{"t": 1.0, "npc_id": "npc_baker", "action": "shout", "target": "", "dialogue": "Os deuses estão com raiva!", "particles": ["exclamation"], "sound": "shout"}],
		"instability_delta": 5.0,
		"world_changes": {},
	}


func _validate(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("events")) != TYPE_ARRAY:
		return {}
	var out: Array = []
	for e in d.events:
		if typeof(e) != TYPE_DICTIONARY or typeof(e.get("action")) != TYPE_STRING:
			continue
		out.append({
			"t": float(e.get("t", 0.0)),
			"npc_id": str(e.get("npc_id", "")),
			"action": e.action,
			"target": str(e.get("target", "")),
			"dialogue": str(e.get("dialogue", "")),
			"particles": e.get("particles", []) if typeof(e.get("particles", [])) == TYPE_ARRAY else [],
			"sound": str(e.get("sound", "")),
		})
		if out.size() >= 12:
			break
	if out.is_empty():
		return {}
	var wc = d.get("world_changes", {})
	return {
		"events": out,
		"instability_delta": clampf(float(d.get("instability_delta", 0.0)), -20.0, 45.0),
		"world_changes": wc if typeof(wc) == TYPE_DICTIONARY else {},
	}
