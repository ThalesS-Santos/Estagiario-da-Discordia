extends Node
## Estado global do jogo (autoload "Game").

signal instability_changed(value: float)
signal ap_changed(value: int)
signal save_error(message: String)

const MAP_SIZE := Vector2(1280, 960)
const MAX_DAYS := 3
const AP_PER_DAY := 3
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"

## posições batem com tools/gen/layout.py (mapa gerado)
var LOCATIONS := {
	"throne": {"name": "Sala do Trono", "pos": Vector2(640, 86)},
	"castle_gate": {"name": "Portão do Castelo", "pos": Vector2(640, 238)},
	"castle_yard": {"name": "Pátio do Castelo", "pos": Vector2(640, 284)},
	"fountain": {"name": "Fonte da Praça", "pos": Vector2(640, 404)},
	"plaza": {"name": "Praça", "pos": Vector2(604, 474)},
	"well": {"name": "Poço", "pos": Vector2(548, 392)},
	"notice_board": {"name": "Poste de Decretos", "pos": Vector2(732, 360)},
	"stall": {"name": "Banca do Mercador", "pos": Vector2(716, 464)},
	"bakery": {"name": "Padaria", "pos": Vector2(304, 440)},
	"residence": {"name": "Residências", "pos": Vector2(112, 440)},
	"forge": {"name": "Ferraria", "pos": Vector2(968, 440)},
	"temple": {"name": "Templo", "pos": Vector2(224, 728)},
	"lake": {"name": "Lago", "pos": Vector2(880, 694)},
	"forest": {"name": "Floresta", "pos": Vector2(1130, 170)},
	"road_south": {"name": "Estrada Sul", "pos": Vector2(640, 944)},
}

var NPC_DEFS := {
	"npc_king": {"name": "Aldemar I", "role": "Rei", "fear": 15, "anger": 60, "loyalty": 100, "cred": 20,
		"color": Color(0.42, 0.17, 0.57), "skin": Color(0.88, 0.7, 0.54), "hat": "crown", "size": Vector2(28, 44), "home": "throne"},
	"npc_baker": {"name": "João da Padaria", "role": "Padeiro", "fear": 30, "anger": 20, "loyalty": 40, "cred": 75,
		"color": Color(0.93, 0.93, 0.9), "skin": Color(0.9, 0.72, 0.58), "hat": "cap_blue", "size": Vector2(32, 44), "home": "bakery"},
	"npc_smith": {"name": "Gordo Marten", "role": "Ferreiro", "fear": 15, "anger": 55, "loyalty": 65, "cred": 40,
		"color": Color(0.45, 0.28, 0.16), "skin": Color(0.78, 0.58, 0.44), "hat": "hair_dark", "size": Vector2(34, 46), "home": "forge"},
	"npc_guard": {"name": "Bram", "role": "Guarda", "fear": 10, "anger": 30, "loyalty": 95, "cred": 35,
		"color": Color(0.5, 0.36, 0.22), "skin": Color(0.85, 0.66, 0.5), "hat": "helm", "size": Vector2(32, 46), "home": "castle_gate"},
	"npc_priestess": {"name": "Mira", "role": "Sacerdotisa", "fear": 25, "anger": 10, "loyalty": 50, "cred": 55,
		"color": Color(0.96, 0.96, 1.0), "skin": Color(0.92, 0.76, 0.62), "hat": "hair_bun", "size": Vector2(28, 48), "home": "temple"},
	"npc_merchant": {"name": "Valdo", "role": "Mercador", "fear": 20, "anger": 15, "loyalty": 10, "cred": 80,
		"color": Color(0.2, 0.5, 0.55), "skin": Color(0.72, 0.52, 0.38), "hat": "wide", "size": Vector2(30, 44), "home": "road_south"},
	"npc_orphan": {"name": "Lila", "role": "Órfã", "fear": 50, "anger": 5, "loyalty": 5, "cred": 95,
		"color": Color(0.6, 0.45, 0.4), "skin": Color(0.93, 0.76, 0.62), "hat": "hair_messy", "size": Vector2(22, 34), "home": "lake"},
}

var VILLAGER_DEFS := {
	"villager_farmer": {"name": "Tobias", "role": "Fazendeiro", "fear": 25, "anger": 20, "loyalty": 60, "cred": 60},
	"villager_woman": {"name": "Helga", "role": "Camponesa", "fear": 35, "anger": 15, "loyalty": 45, "cred": 65},
	"villager_elder": {"name": "Ancião Osric", "role": "Ancião", "fear": 20, "anger": 10, "loyalty": 70, "cred": 85},
	"villager_boy": {"name": "Pip", "role": "Menino", "fear": 55, "anger": 5, "loyalty": 30, "cred": 90},
	"villager_lady": {"name": "Dama Isolde", "role": "Nobre", "fear": 30, "anger": 35, "loyalty": 55, "cred": 50},
}

# tags: sagrado, veneno, real, comida, arma, escrito, pesado, pequeno
var OBJECTS := {
	"apple": {"name": "Maçã vermelha", "tags": ["comida"], "loc": "plaza", "off": Vector2(30, 25)},
	"poison_apple": {"name": "Maçã vermelha", "tags": ["comida", "veneno"], "loc": "bakery", "off": Vector2(20, 12), "hidden": true},
	"bread": {"name": "Pão", "tags": ["comida"], "loc": "bakery", "off": Vector2(-22, 12)},
	"gold_key": {"name": "Chave dourada", "tags": ["real"], "loc": "castle_gate", "off": Vector2(55, 10)},
	"royal_ring": {"name": "Anel com Brasão Real", "tags": ["real", "pequeno"], "loc": "castle_yard", "off": Vector2(-55, 0)},
	"sealed_letter": {"name": "Carta lacrada", "tags": ["escrito"], "loc": "notice_board", "off": Vector2(-22, 24)},
	"royal_coin": {"name": "Moeda com brasão real", "tags": ["real", "pequeno"], "loc": "fountain", "off": Vector2(28, 34)},
	"rusty_sword": {"name": "Espada enferrujada", "tags": ["arma"], "loc": "forge", "off": Vector2(-34, 30)},
	"king_dagger": {"name": "Adaga do Rei", "tags": ["arma", "real"], "loc": "throne", "off": Vector2(60, 12)},
	"poison_vial": {"name": "Frasco de veneno", "tags": ["veneno", "pequeno"], "loc": "bakery", "off": Vector2(-44, -8)},
	"blue_hat": {"name": "Touca azul do cozinheiro", "tags": ["pequeno"], "loc": "bakery", "off": Vector2(4, -22)},
	"flour": {"name": "Saco de farinha", "tags": ["comida", "pesado"], "loc": "bakery", "off": Vector2(44, -14)},
	"rites_book": {"name": "Livro de ritos", "tags": ["sagrado", "escrito"], "loc": "temple", "off": Vector2(-24, 10)},
	"relic": {"name": "Relíquia da Sacerdotisa", "tags": ["sagrado", "pequeno"], "loc": "temple", "off": Vector2(22, -12)},
	"hammer": {"name": "Martelo do Ferreiro", "tags": ["arma", "pesado"], "loc": "forge", "off": Vector2(34, -12)},
	"fake_coin": {"name": "Moeda falsa", "tags": ["pequeno"], "loc": "plaza", "off": Vector2(-34, 24)},
}

var TAG_COLORS := {
	"veneno": Color(0.45, 0.85, 0.3), "sagrado": Color(1.0, 0.85, 0.35), "real": Color(0.7, 0.4, 0.95),
	"arma": Color(0.7, 0.75, 0.8), "comida": Color(0.9, 0.35, 0.25), "escrito": Color(0.95, 0.93, 0.85),
	"pesado": Color(0.6, 0.4, 0.25), "pequeno": Color(0.4, 0.7, 0.95),
}

var player_name := "ESTAGIARIO"
var day := 1
var ap := 3
var instability := 5.0
var rumors := 0
var npc_state := {}
var world_checkpoint := {}
var persistence_enabled := true
var ui_theme: Theme
var settings := {"master": 1.0, "music": 0.8, "sfx": 0.8, "sim_speed": 1.0, "resolution": 0, "subtitles": true, "colorblind": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_theme = _make_theme()
	reset()


func reset() -> void:
	day = 1
	ap = AP_PER_DAY
	instability = 5.0
	rumors = 0
	npc_state.clear()
	world_checkpoint.clear()
	for id in NPC_DEFS:
		var d: Dictionary = NPC_DEFS[id]
		npc_state[id] = {"fear": d.fear, "anger": d.anger, "loyalty": d.loyalty, "cred": d.cred, "memories": []}
	for id in VILLAGER_DEFS:
		var d: Dictionary = VILLAGER_DEFS[id]
		npc_state[id] = {"fear": d.fear, "anger": d.anger, "loyalty": d.loyalty, "cred": d.cred, "memories": []}


func loc_pos(key: String) -> Vector2:
	return LOCATIONS[key].pos if LOCATIONS.has(key) else Vector2.ZERO


func nearest_location(p: Vector2, max_dist := 170.0) -> String:
	var best := "open_field"
	var bd := max_dist
	for k in LOCATIONS:
		var d: float = p.distance_to(LOCATIONS[k].pos)
		if d < bd:
			bd = d
			best = k
	return best


func loc_name(key: String) -> String:
	return LOCATIONS[key].name if LOCATIONS.has(key) else "Campo aberto"


func tag_color(tags: Array) -> Color:
	for t in ["sagrado", "veneno", "real", "arma", "escrito", "comida", "pesado", "pequeno"]:
		if tags.has(t):
			return TAG_COLORS[t]
	return Color.WHITE


func spend_ap(n: int) -> bool:
	if ap < n:
		return false
	ap -= n
	ap_changed.emit(ap)
	return true


func refund_ap(n: int) -> void:
	ap = mini(ap + n, AP_PER_DAY)
	ap_changed.emit(ap)


func reset_ap() -> void:
	ap = AP_PER_DAY
	ap_changed.emit(ap)


func add_instability(d: float) -> void:
	instability = clampf(instability + d, 0.0, 100.0)
	instability_changed.emit(instability)


func set_instability(v: float) -> void:
	instability = clampf(v, 0.0, 100.0)
	instability_changed.emit(instability)


func add_memory(npc_id: String, text: String) -> void:
	if not npc_state.has(npc_id) or text.strip_edges() == "":
		return
	var m: Array = npc_state[npc_id].memories
	m.append(text)
	while m.size() > 6:
		m.pop_front()


func bump(npc_id: String, stat: String, amount: float) -> void:
	if npc_state.has(npc_id):
		npc_state[npc_id][stat] = clampf(float(npc_state[npc_id][stat]) + amount, 0.0, 100.0)


# ---------- persistência ----------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak")


func save_game(path := SAVE_PATH) -> bool:
	if not persistence_enabled:
		return true
	var temp := path + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if not f:
		save_error.emit("Não foi possível salvar o progresso.")
		return false
	f.store_string(JSON.stringify({"version": 2, "name": player_name, "day": day,
		"instability": instability, "rumors": rumors, "npc": npc_state, "world": world_checkpoint}))
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		save_error.emit("Não foi possível gravar o progresso.")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(absolute + ".bak")
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK:
			save_error.emit("Não foi possível preservar o salvamento anterior.")
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(absolute + ".bak", absolute)
		save_error.emit("Não foi possível concluir o salvamento.")
		return false
	return true


func load_game(path := SAVE_PATH) -> bool:
	var d := _read_save(path)
	if d.is_empty():
		d = _read_save(path + ".bak")
	if d.is_empty():
		save_error.emit("Salvamento inválido ou indisponível.")
		return false
	reset()
	player_name = str(d.get("name", player_name))
	day = int(d.get("day", 1))
	instability = float(d.get("instability", 5.0))
	rumors = int(d.get("rumors", 0))
	var n = d.get("npc", {})
	if typeof(n) == TYPE_DICTIONARY:
		for id in n:
			if npc_state.has(id):
				npc_state[id] = n[id]
	world_checkpoint = d.get("world", {}).duplicate(true)
	return true


func _read_save(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f or f.get_length() > 262144:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var version = data.get("version", 1)
	if not AIContract.number_in(version, 1, 2) or float(version) != floorf(float(version)):
		return {}
	if typeof(data.get("name")) != TYPE_STRING or data.name.length() > 12:
		return {}
	for field in [["day", 1, MAX_DAYS], ["instability", 0, 100], ["rumors", 0, 10000]]:
		if not AIContract.number_in(data.get(field[0]), field[1], field[2]):
			return {}
	if float(data.day) != floorf(float(data.day)) or float(data.rumors) != floorf(float(data.rumors)):
		return {}
	if typeof(data.get("npc")) != TYPE_DICTIONARY:
		return {}
	for id in data.npc:
		var state = data.npc[id]
		if not NPC_DEFS.has(id) and not VILLAGER_DEFS.has(id):
			return {}
		if typeof(state) != TYPE_DICTIONARY:
			return {}
		for stat in ["fear", "anger", "loyalty", "cred"]:
			if not AIContract.number_in(state.get(stat), 0, 100):
				return {}
		if typeof(state.get("memories")) != TYPE_ARRAY or state.memories.size() > 6:
			return {}
		for memory in state.memories:
			if typeof(memory) != TYPE_STRING or memory.length() > 500:
				return {}
	var checkpoint = data.get("world", {})
	if typeof(checkpoint) != TYPE_DICTIONARY:
		return {}
	if not checkpoint.is_empty() and not _valid_checkpoint(checkpoint):
		return {}
	return data


func _valid_checkpoint(checkpoint: Dictionary) -> bool:
	for key in ["poisoned", "fish_dead", "torch_on"]:
		if typeof(checkpoint.get(key)) != TYPE_BOOL:
			return false
	for field in [["castle_damage", 0, 3], ["gate_open", 0, 1], ["flag_drop", 0, 1]]:
		if not AIContract.number_in(checkpoint.get(field[0]), field[1], field[2]):
			return false
	if typeof(checkpoint.get("water")) != TYPE_STRING or not Color.html_is_valid(checkpoint.water):
		return false
	if typeof(checkpoint.get("objects")) != TYPE_DICTIONARY or checkpoint.objects.size() != OBJECTS.size():
		return false
	for id in checkpoint.objects:
		var obj = checkpoint.objects[id]
		if not OBJECTS.has(id) or typeof(obj) != TYPE_DICTIONARY:
			return false
		if not AIContract.number_in(obj.get("x"), 0, MAP_SIZE.x) or not AIContract.number_in(obj.get("y"), 0, MAP_SIZE.y):
			return false
		if typeof(obj.get("carrier")) != TYPE_STRING or (obj.carrier != "" and not NPC_DEFS.has(obj.carrier)):
			return false
	return true


func apply_npc_updates(updates: Array) -> void:
	for update in updates:
		if npc_state.has(update.npc_id):
			npc_state[update.npc_id].fear = update.fear_level
			npc_state[update.npc_id].anger = update.anger_level
			npc_state[update.npc_id].loyalty = update.loyalty_level


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = c.get_value("s", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in settings:
		c.set_value("s", k, settings[k])
	c.save(SETTINGS_PATH)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.master), 0.001)))
	if is_instance_valid(get_node_or_null("/root/Music")):
		get_node("/root/Music").set_volume(float(settings.music))
	match int(settings.resolution):
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------- tema de UI (terminal retrô) ----------
func box(bg: Color, border: Color, bw := 2, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	t.default_font = f
	t.default_font_size = 16
	var green := Color(0.7, 1.0, 0.8)
	var border := Color(0.35, 0.9, 0.55)
	var bg := Color(0.04, 0.06, 0.09, 0.92)
	t.set_stylebox("normal", "Button", box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0), 0, 10))
	t.set_stylebox("hover", "Button", box(Color(0.1, 0.2, 0.15, 0.85), Color(1.0, 0.85, 0.35), 2, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.35, 0.25, 0.9), Color(1, 1, 1), 2, 10))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0.35, 0.9, 0.55, 0.6), 1, 10))
	t.set_stylebox("disabled", "Button", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10))
	t.set_color("font_color", "Button", green)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.85, 0.35))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.5, 0.45))
	t.set_color("font_color", "Label", green)
	t.set_color("font_color", "CheckButton", green)
	t.set_color("font_color", "OptionButton", green)
	t.set_stylebox("panel", "PanelContainer", box(bg, border, 2, 14))
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.5), Color(0.2, 0.5, 0.3), 1, 6))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.6), border, 2, 6))
	t.set_color("font_color", "LineEdit", green)
	t.set_color("caret_color", "LineEdit", Color(1.0, 0.85, 0.35))
	return t
