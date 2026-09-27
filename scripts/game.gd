extends Node
## Estado global do jogo (autoload "Game").

signal instability_changed(value: float)
signal ap_changed(value: int)
signal save_error(message: String)

const MAP_SIZE := Vector2(1280, 960)
const MAX_DAYS := 3
const AP_PER_DAY := 3
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5 ## gravação e leitura usam o mesmo número; ao subir, a leitura aceita as anteriores
const SETTINGS_PATH := "user://settings.cfg"

## Progressão de dificuldade por dia. Cada dia escala parâmetros do jogo.
const DIFFICULTY := {
	1: {
		"suspicion_rate": 0.7,
		"suspicion_decay": 1.3,
		"pursuit_speed": 0.85,
		"pursuit_duration": {12.0: 15.0},
		"evidence_weight": 0.8,
		"npc_memory_slots": 2,
		"patrol_enabled": false,
		"recognition_enabled": false,
	},
	2: {
		"suspicion_rate": 1.0,
		"suspicion_decay": 1.0,
		"pursuit_speed": 1.0,
		"pursuit_duration": {10.0: 15.0},
		"evidence_weight": 1.0,
		"npc_memory_slots": 3,
		"patrol_enabled": true,
		"recognition_enabled": false,
	},
	3: {
		"suspicion_rate": 1.4,
		"suspicion_decay": 0.7,
		"pursuit_speed": 1.15,
		"pursuit_duration": {12.0: 18.0},
		"evidence_weight": 1.3,
		"npc_memory_slots": 4,
		"patrol_enabled": true,
		"recognition_enabled": true,
	},
}


func get_difficulty() -> Dictionary:
	var d: int = clampi(day, 1, 3)
	return DIFFICULTY[d]

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

const EVIDENCE_TYPES := [
	"object_placed", "testimony", "footprint", "timing",
	"overheard", "carried_object", "break_in", "witness",
	"contradiction", "forged_letter",
]

var ACTION_DEFS := {
	"observe": {
		"name": "Observar",
		"cost": 0, "noise": 0.0, "suspicion": 0.0,
		"requires_npc": true, "requires_item": false,
		"duration": 3.0,
		"description": "Observa um NPC com atenção. Pode revelar pistas sobre seu comportamento.",
	},
	"listen": {
		"name": "Escutar",
		"cost": 0, "noise": 0.0, "suspicion": 5.0,
		"requires_npc": true, "requires_item": false,
		"duration": 4.0,
		"description": "Fica por perto para ouvir o que o NPC diz. Mais arriscado que observar.",
	},
	"gossip": {
		"name": "Sussurrar Boato",
		"cost": 1, "noise": 5.0, "suspicion": 10.0,
		"requires_npc": true, "requires_item": false,
		"duration": 0.0,
		"description": "Espalha um boato para um NPC. Abre o terminal de narrativa.",
	},
	"plant_object": {
		"name": "Plantar Objeto",
		"cost": 2, "noise": 10.0, "suspicion": 15.0,
		"requires_npc": false, "requires_item": true,
		"duration": 0.0,
		"description": "Coloca um objeto em um local estratégico com uma narrativa.",
	},
	"steal": {
		"name": "Roubar",
		"cost": 1, "noise": 15.0, "suspicion": 25.0,
		"requires_npc": false, "requires_item": false,
		"tags": ["furtivo"],
		"description": "Pega um objeto de um NPC ou local vigiado. Alto risco.",
	},
	"forge_letter": {
		"name": "Falsificar Carta",
		"cost": 1, "noise": 0.0, "suspicion": 5.0,
		"requires_npc": false, "requires_item": true,
		"required_items": ["sealed_letter"],
		"duration": 2.0,
		"description": "Adultera uma carta para incriminar alguém. Requer a carta lacrada.",
	},
	"follow": {
		"name": "Seguir",
		"cost": 0, "noise": 5.0, "suspicion": 15.0,
		"requires_npc": true, "requires_item": false,
		"duration": 5.0,
		"description": "Segue um NPC discretamente. Pode revelar segredos ou gerar testemunha.",
	},
	"confront": {
		"name": "Confrontar",
		"cost": 1, "noise": 30.0, "suspicion": 20.0,
		"requires_npc": true, "requires_item": false,
		"duration": 0.0,
		"description": "Confronta um NPC com evidências. Pode mudar opiniões — ou sair pela culatra.",
	},
	"incriminate": {
		"name": "Incriminar",
		"cost": 1, "noise": 10.0, "suspicion": 20.0,
		"requires_npc": true, "requires_item": true,
		"duration": 0.0,
		"description": "Usa um objeto para criar evidência falsa contra um NPC.",
	},
	"protect": {
		"name": "Proteger",
		"cost": 1, "noise": 5.0, "suspicion": 0.0,
		"requires_npc": true, "requires_item": false,
		"duration": 0.0,
		"description": "Defende um NPC de acusações. Ganha lealdade, mas gasta PA.",
	},
	"hide": {
		"name": "Esconder-se",
		"cost": 0, "noise": 0.0, "suspicion": -20.0,
		"requires_npc": false, "requires_item": false,
		"duration": 3.0,
		"description": "Se esconde num canto. Reduz suspeita de NPCs próximos.",
	},
	"ask_help": {
		"name": "Pedir Ajuda",
		"cost": 1, "noise": 10.0, "suspicion": 5.0,
		"requires_npc": true, "requires_item": false,
		"duration": 0.0,
		"description": "Pede ajuda a um NPC aliado. Funciona melhor com NPCs de baixa lealdade ao Rei.",
	},
	"destroy_evidence": {
		"name": "Destruir Pista",
		"cost": 1, "noise": 20.0, "suspicion": 30.0,
		"requires_npc": false, "requires_item": false,
		"duration": 2.0,
		"description": "Remove uma evidência do jogo. Muito arriscado se alguém estiver perto.",
	},
	"flee": {
		"name": "Fugir",
		"cost": 0, "noise": 25.0, "suspicion": -10.0,
		"requires_npc": false, "requires_item": false,
		"duration": 0.0,
		"description": "Corre para longe. Faz barulho, mas reduz confronto imediato.",
	},
}

enum EventState { LOCKED, AVAILABLE, ACTIVE, RESOLVED, FAILED, CANCELLED }

var EVENT_DEFS := {
	"weapon_found": {
		"title": "Arma Encontrada",
		# Unlock: um objeto marcado como arma foi colocado num local público.
		# Sucesso: há evidência contra alguém (não apenas o contador genérico).
		"description": "Uma arma foi encontrada num local inesperado — os moradores começam a cochichar.",
		"involved_npcs": ["npc_guard", "npc_smith"],
		"unlock": "evidence_type:object_placed:arma",
		"success": "evidence_against_king:1",
		"on_resolve": ["unlock:suspect_accused"],
		"duration": 15.0,
	},
	"suspect_accused": {
		"title": "Suspeito Acusado",
		# Sucesso: a lealdade do guarda caiu (ele não mais defende o rei cegamente)
		# e há evidência contra o rei — há um suspeito real.
		"description": "Os moradores apontam um culpado. O guarda começa a interrogar.",
		"involved_npcs": ["npc_guard", "npc_baker"],
		"unlock": "event_resolved:weapon_found",
		"success": "multi:evidence_against_king:1,npc_loyalty_below:npc_guard:70",
		"on_resolve": ["unlock:guard_interrogates"],
		"duration": 20.0,
	},
	"guard_interrogates": {
		"title": "Guarda Interroga",
		# Sucesso: o guarda está com raiva/suspeita elevada E a lealdade caiu ainda mais,
		# indicando que ele realmente investiga — não apenas patrulha.
		"description": "Bram abandona o portão para investigar o acusado na praça.",
		"involved_npcs": ["npc_guard"],
		"unlock": "event_resolved:suspect_accused",
		"success": "multi:npc_loyalty_below:npc_guard:55,npc_suspicion:npc_guard:35",
		"on_resolve": ["unlock:witness_appears", "set:guard_distracted"],
		"duration": 25.0,
	},
	"witness_appears": {
		"title": "Testemunha Aparece",
		# Sucesso: o jogador não está exposto (evidência contra ele abaixo de 40).
		# Falha: jogador virou o principal suspeito.
		"description": "Alguém afirma ter visto o verdadeiro culpado — ou o jogador. A pressão aumenta.",
		"involved_npcs": ["villager_elder", "npc_priestess"],
		"unlock": "event_resolved:guard_interrogates",
		"success": "evidence_against_player_below:40",
		"fail": "evidence_against_player:80",
		"on_resolve": ["unlock:diversion_needed"],
		"on_fail": ["unlock:player_exposed"],
		"duration": 20.0,
	},
	"diversion_needed": {
		"title": "Desviar a Investigação",
		# Sucesso: o guarda está distraído (flag setada pela IA ou pelo handler do boato)
		# — não um contador arbitrário de instabilidade.
		"description": "O jogador precisa criar uma distração ou plantar provas para desviar a suspeita.",
		"involved_npcs": [],
		"unlock": "event_resolved:witness_appears",
		"success": "flag:guard_distracted",
		"on_resolve": ["unlock:guard_leaves_post"],
		"duration": 30.0,
	},
	"guard_leaves_post": {
		"title": "Guarda Abandona o Portão",
		# Sucesso: o portão está de fato desguarnecido (flag setada pelo handler).
		"description": "A confusão é tanta que Bram não consegue ficar parado. O portão está desprotegido.",
		"involved_npcs": ["npc_guard"],
		"unlock": "event_resolved:diversion_needed",
		"success": "flag:gate_unguarded",
		"on_resolve": ["unlock:gate_passage", "set:gate_unguarded"],
		"duration": 15.0,
	},
	"gate_passage": {
		"title": "Atravessar o Portão",
		"description": "O caminho está aberto. Hora de cruzar antes que alguém perceba.",
		"involved_npcs": [],
		"unlock": "event_resolved:guard_leaves_post",
		"success": "flag:player_crossed_gate",
		"duration": 45.0,
	},
	"player_exposed": {
		"title": "Jogador Exposto",
		"description": "Provas demais apontam para o Estagiário. A missão fica muito mais difícil.",
		"involved_npcs": ["npc_guard", "npc_king"],
		"unlock": "event_failed:witness_appears",
		"success": "evidence_against_player_below:20",
		"on_resolve": ["unlock:diversion_needed"],
		"duration": 30.0,
	},
	"king_deposed": {
		"title": "Deposição do Rei",
		"description": "A instabilidade social chegou ao limite. O povo se revolta contra Aldemar I.",
		"involved_npcs": ["npc_king", "npc_guard", "npc_smith", "npc_baker"],
		"unlock": "multi:instability:80,npcs_turned:3,evidence_against_king:1,npc_loyalty_below:npc_guard:50",
		"success": "instability:100",
		"on_resolve": [],
		"duration": 0.0,
	},
}

var player_name := "ESTAGIARIO"
var day := 1
var ap := 3
var instability := 5.0
var rumors := 0
var npc_state := {}
var world_checkpoint := {}
var evidence_log: Array = []
var _evidence_counter := 0
var event_states: Dictionary = {}
var event_flags: Dictionary = {}
var active_events: Array = []
var _active_event_counter := 0
var persistence_enabled := true
var ui_theme: Theme
var settings := {"master": 1.0, "music": 0.8, "sfx": 0.8, "sim_speed": 1.0, "resolution": 0, "subtitles": true}

## Reputação por grupo: -100 (hostil) a +100 (aliado). Afeta reações, diálogos e acesso.
var reputation: Dictionary = {}
const REPUTATION_GROUPS := {
	"commons": {
		"name": "Plebeus",
		"members": ["npc_baker", "npc_orphan", "villager_farmer", "villager_woman", "villager_boy"],
	},
	"guards": {
		"name": "Guarda Real",
		"members": ["npc_guard"],
	},
	"clergy": {
		"name": "Clero",
		"members": ["npc_priestess", "villager_elder"],
	},
	"merchants": {
		"name": "Mercadores",
		"members": ["npc_merchant", "villager_lady"],
	},
	"royalty": {
		"name": "Realeza",
		"members": ["npc_king", "npc_smith"],
	},
}

var _npc_to_group: Dictionary = {}


func _init_reputation() -> void:
	reputation.clear()
	for gid in REPUTATION_GROUPS:
		reputation[gid] = 0
		for npc_id in REPUTATION_GROUPS[gid].members:
			_npc_to_group[npc_id] = gid


func npc_group(npc_id: String) -> String:
	return _npc_to_group.get(npc_id, "")


func change_reputation(group_id: String, delta: float) -> void:
	if not reputation.has(group_id):
		return
	reputation[group_id] = clampf(float(reputation[group_id]) + delta, -100.0, 100.0)


func change_reputation_for_npc(npc_id: String, delta: float) -> void:
	var gid := npc_group(npc_id)
	if gid != "":
		change_reputation(gid, delta)


func get_reputation(group_id: String) -> float:
	return float(reputation.get(group_id, 0))


func npc_reputation(npc_id: String) -> float:
	var gid := npc_group(npc_id)
	return float(reputation.get(gid, 0)) if gid != "" else 0.0


func reputation_modifier(npc_id: String) -> Dictionary:
	var rep := npc_reputation(npc_id)
	return {
		"suspicion_mult": 1.0 - rep * 0.005,
		"help_chance": clampf(0.3 + rep * 0.005, 0.0, 0.9),
		"denounce_chance": clampf(0.3 - rep * 0.005, 0.05, 0.8),
		"lie_for_player": rep > 30.0,
	}


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
	evidence_log.clear()
	_evidence_counter = 0
	event_states.clear()
	event_flags.clear()
	active_events.clear()
	_active_event_counter = 0
	_init_events()
	_init_reputation()
	for id in NPC_DEFS:
		var d: Dictionary = NPC_DEFS[id]
		npc_state[id] = {"fear": d.fear, "anger": d.anger, "loyalty": d.loyalty, "cred": d.cred, "suspicion": 0.0, "memories": []}
	for id in VILLAGER_DEFS:
		var d: Dictionary = VILLAGER_DEFS[id]
		npc_state[id] = {"fear": d.fear, "anger": d.anger, "loyalty": d.loyalty, "cred": d.cred, "suspicion": 0.0, "memories": []}


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


# ---------- eventos em cadeia ----------
signal event_state_changed(event_id: String, new_state: int)

func _init_events() -> void:
	for eid in EVENT_DEFS:
		if not event_states.has(eid):
			event_states[eid] = EventState.LOCKED


func get_event_state(eid: String) -> int:
	return int(event_states.get(eid, EventState.LOCKED))


func set_event_state(eid: String, new_state: int) -> void:
	var old: int = get_event_state(eid)
	if old == new_state:
		return
	event_states[eid] = new_state
	event_state_changed.emit(eid, new_state)
	if new_state == EventState.RESOLVED:
		var def: Dictionary = EVENT_DEFS.get(eid, {})
		for action in def.get("on_resolve", []):
			_exec_event_action(action)
	elif new_state == EventState.FAILED:
		var def: Dictionary = EVENT_DEFS.get(eid, {})
		for action in def.get("on_fail", []):
			_exec_event_action(action)


func _exec_event_action(action: String) -> void:
	if action.begins_with("unlock:"):
		var target := action.substr(7)
		if event_states.get(target, EventState.LOCKED) == EventState.LOCKED:
			set_event_state(target, EventState.AVAILABLE)
	elif action.begins_with("set:"):
		var flag := action.substr(4)
		event_flags[flag] = true


func evaluate_events() -> Array:
	var changed: Array = []
	for eid in EVENT_DEFS:
		var st: int = get_event_state(eid)
		var def: Dictionary = EVENT_DEFS[eid]
		if st == EventState.LOCKED:
			if _check_condition(def.get("unlock", "")):
				set_event_state(eid, EventState.AVAILABLE)
				changed.append({"id": eid, "state": "AVAILABLE", "title": def.title})
		elif st == EventState.AVAILABLE:
			set_event_state(eid, EventState.ACTIVE)
			changed.append({"id": eid, "state": "ACTIVE", "title": def.title})
		elif st == EventState.ACTIVE:
			if def.has("fail") and _check_condition(def.fail):
				set_event_state(eid, EventState.FAILED)
				changed.append({"id": eid, "state": "FAILED", "title": def.title})
			elif _check_condition(def.get("success", "")):
				set_event_state(eid, EventState.RESOLVED)
				changed.append({"id": eid, "state": "RESOLVED", "title": def.title})
	return changed


func _check_condition(cond: String) -> bool:
	if cond == "":
		return false
	if cond.begins_with("multi:"):
		var parts := cond.substr(6).split(",")
		for p in parts:
			if not _check_condition(p.strip_edges()):
				return false
		return true
	if cond.begins_with("event_resolved:"):
		return get_event_state(cond.substr(15)) == EventState.RESOLVED
	if cond.begins_with("event_failed:"):
		return get_event_state(cond.substr(13)) == EventState.FAILED
	if cond.begins_with("instability:"):
		return instability >= float(cond.substr(12))
	if cond.begins_with("evidence_type:"):
		var parts := cond.substr(14).split(":")
		var ev_type := parts[0]
		var tag := parts[1] if parts.size() > 1 else ""
		for ev in evidence_log:
			if ev.active and ev.type == ev_type:
				if tag == "" or _evidence_has_tag(ev, tag):
					return true
		return false
	if cond.begins_with("evidence_count:"):
		var needed := int(cond.substr(15))
		var count := 0
		for ev in evidence_log:
			if ev.active:
				count += 1
		return count >= needed
	if cond.begins_with("evidence_against_player:"):
		return evidence_against(player_name) >= float(cond.substr(23))
	if cond.begins_with("evidence_against_player_below:"):
		return evidence_against(player_name) < float(cond.substr(29))
	if cond.begins_with("evidence_against_king:"):
		var needed := int(cond.substr(22))
		var count := 0
		for ev in evidence_log:
			if ev.active and ev.suspect_id == "npc_king":
				count += 1
		return count >= needed
	if cond.begins_with("npc_loyalty_below:"):
		var parts := cond.substr(18).split(":")
		var nid := parts[0]
		var threshold := float(parts[1])
		if npc_state.has(nid):
			return float(npc_state[nid].get("loyalty", 100)) < threshold
		return false
	if cond.begins_with("npc_suspicion:"):
		var parts := cond.substr(14).split(":")
		if parts.size() != 2:
			return false
		var nid := parts[0]
		var threshold := float(parts[1])
		return npc_state.has(nid) and float(npc_state[nid].get("suspicion", 0.0)) >= threshold
	if cond.begins_with("npcs_turned:"):
		var needed := int(cond.substr(12))
		var count := 0
		for nid in NPC_DEFS:
			if nid == "npc_king":
				continue
			if npc_state.has(nid) and float(npc_state[nid].get("loyalty", 100)) < 40:
				count += 1
		return count >= needed
	if cond.begins_with("flag:"):
		return event_flags.get(cond.substr(5), false)
	return false


func _evidence_has_tag(ev: Dictionary, tag: String) -> bool:
	var obj_id: String = ev.get("object_id", "")
	if OBJECTS.has(obj_id):
		var tags: Array = OBJECTS[obj_id].get("tags", [])
		return tags.has(tag)
	return false


func get_active_events() -> Array:
	var result: Array = []
	for eid in EVENT_DEFS:
		var st: int = get_event_state(eid)
		if st == EventState.ACTIVE or st == EventState.AVAILABLE:
			var def: Dictionary = EVENT_DEFS[eid]
			result.append({"id": eid, "title": def.title, "description": def.description, "state": st})
	return result


func events_summary_for_ai() -> Array:
	var result: Array = []
	for eid in EVENT_DEFS:
		var st: int = get_event_state(eid)
		if st == EventState.ACTIVE or st == EventState.RESOLVED:
			var def: Dictionary = EVENT_DEFS[eid]
			var state_name := "ativo" if st == EventState.ACTIVE else "resolvido"
			result.append({"id": eid, "title": def.title, "state": state_name})
	return result


# ---------- confronto ----------
const CONFRONTATION_CHOICES := {
	"lie": {
		"label": "Mentir",
		"description": "\"Eu? Estava só passeando...\"",
		"icon": "...",
		"requires": {},
		"success_threshold": "suspicion_low",
	},
	"threaten": {
		"label": "Ameaçar",
		"description": "\"Você sabe quem eu conheço?\"",
		"icon": "!",
		"requires": {"min_instability": 30},
		"success_threshold": "reputation",
	},
	"bribe": {
		"label": "Subornar",
		"description": "\"E se eu facilitar sua vida?\"",
		"icon": "<3",
		"requires": {"has_item_tag": "valioso"},
		"success_threshold": "loyalty_high",
	},
	"accuse": {
		"label": "Acusar outro",
		"description": "\"Não fui eu, foi o [NPC]!\"",
		"icon": "!",
		"requires": {"has_evidence": true},
		"success_threshold": "evidence_strong",
	},
	"flee_confrontation": {
		"label": "Fugir",
		"description": "Tente escapar correndo!",
		"icon": "?",
		"requires": {},
		"success_threshold": "always",
	},
	"admit": {
		"label": "Admitir",
		"description": "\"Tudo bem, eu confesso...\"",
		"icon": "...",
		"requires": {},
		"success_threshold": "always",
	},
}


func get_available_confrontation_choices(npc_id: String, has_valuable: bool) -> Array:
	var result: Array = []
	for cid in CONFRONTATION_CHOICES:
		var choice: Dictionary = CONFRONTATION_CHOICES[cid]
		var reqs: Dictionary = choice.requires
		var available := true
		if reqs.has("min_instability") and instability < float(reqs.min_instability):
			available = false
		if reqs.get("has_item_tag") and not has_valuable:
			available = false
		if reqs.get("has_evidence") and get_active_evidence().is_empty():
			available = false
		result.append({"id": cid, "label": choice.label, "description": choice.description,
			"icon": choice.icon, "available": available})
	return result


func evaluate_confrontation(choice_id: String, npc_id: String) -> Dictionary:
	var npc_data: Dictionary = npc_state.get(npc_id, {})
	var susp := float(npc_data.get("suspicion", 50))
	var loyalty := float(npc_data.get("loyalty", 100))
	var anger := float(npc_data.get("anger", 0))
	var rep := npc_reputation(npc_id)
	var rep_bonus := rep * 0.003
	var result := {"success": false, "text": "", "instability_delta": 0.0,
		"npc_effects": {}, "flee": false, "suspicion_delta": 0.0, "reputation_delta": 0.0}
	match choice_id:
		"lie":
			var chance := 0.8 - susp / 200.0 - anger / 200.0 + rep_bonus
			result.success = randf() < chance
			if result.success:
				result.text = "O NPC acreditou na sua história."
				result.suspicion_delta = -20.0
				result.npc_effects = {"anger": -5.0}
				result.reputation_delta = 3.0
			else:
				result.text = "O NPC não engoliu a mentira!"
				result.suspicion_delta = 15.0
				result.npc_effects = {"anger": 15.0, "loyalty": 5.0}
				result.reputation_delta = -8.0
		"threaten":
			var chance := clampf(instability / 100.0 * 0.6 + 0.1 - loyalty / 200.0 + rep_bonus, 0.1, 0.8)
			result.success = randf() < chance
			if result.success:
				result.text = "O NPC recuou, intimidado."
				result.npc_effects = {"fear": 20.0, "loyalty": -15.0}
				result.instability_delta = 3.0
				result.reputation_delta = -15.0
			else:
				result.text = "O NPC ficou furioso com a ameaça!"
				result.npc_effects = {"anger": 25.0, "loyalty": 10.0}
				result.instability_delta = -5.0
				result.suspicion_delta = 20.0
				result.reputation_delta = -10.0
		"bribe":
			var chance := 0.6 - loyalty / 250.0 + anger / 500.0 + rep_bonus
			result.success = randf() < clampf(chance, 0.15, 0.85)
			if result.success:
				result.text = "O NPC aceitou o suborno e fez vista grossa."
				result.npc_effects = {"loyalty": -20.0, "anger": -10.0}
				result.suspicion_delta = -30.0
				result.reputation_delta = -5.0
			else:
				result.text = "O NPC recusou o suborno e ficou mais bravo!"
				result.npc_effects = {"anger": 20.0, "loyalty": 15.0}
				result.suspicion_delta = 10.0
				result.reputation_delta = -12.0
		"accuse":
			var evidence := get_active_evidence()
			var strength := 0.0
			for ev in evidence:
				strength = maxf(strength, float(ev.get("strength", 0)))
			var chance := clampf(strength / 100.0 + 0.1 + rep_bonus, 0.2, 0.9)
			result.success = randf() < chance
			if result.success:
				result.text = "O NPC ficou confuso e foi investigar outra pessoa."
				result.npc_effects = {"anger": -10.0}
				result.suspicion_delta = -25.0
				result.instability_delta = 5.0
			else:
				result.text = "O NPC não caiu na acusação falsa!"
				result.npc_effects = {"anger": 15.0}
				result.suspicion_delta = 15.0
		"flee_confrontation":
			result.success = true
			result.flee = true
			result.text = "Você foge correndo!"
			result.suspicion_delta = 25.0
			result.npc_effects = {"anger": 10.0}
			result.instability_delta = -3.0
		"admit":
			result.success = true
			result.text = "O NPC ficou surpreso com a confissão."
			result.suspicion_delta = -10.0
			result.npc_effects = {"anger": -5.0, "loyalty": -10.0}
			result.instability_delta = -5.0
	return result


# ---------- ações do jogador ----------
func can_do_action(action_id: String, has_item := false, has_npc := false, ignore_ap := false) -> Dictionary:
	if not ACTION_DEFS.has(action_id):
		return {"ok": false, "reason": "Ação desconhecida."}
	var def: Dictionary = ACTION_DEFS[action_id]
	if not ignore_ap and int(def.cost) > ap:
		return {"ok": false, "reason": "PA insuficiente (%d necessário)." % def.cost}
	if def.requires_npc and not has_npc:
		return {"ok": false, "reason": "Precisa de um NPC alvo."}
	if def.requires_item and not has_item:
		return {"ok": false, "reason": "Requer um objeto."}
	return {"ok": true, "reason": ""}


func get_action_cost(action_id: String) -> int:
	return int(ACTION_DEFS.get(action_id, {}).get("cost", 0))


func get_available_actions(has_item: bool, has_npc: bool, ignore_ap := false) -> Array:
	var result: Array = []
	for aid in ACTION_DEFS:
		var check := can_do_action(aid, has_item, has_npc, ignore_ap)
		if check.ok:
			var def: Dictionary = ACTION_DEFS[aid]
			result.append({"id": aid, "name": def.name, "cost": def.cost,
				"suspicion": def.suspicion, "noise": def.noise, "description": def.description})
	return result


# ---------- eventos ativos ----------
func create_active_event(p: Dictionary) -> Dictionary:
	_active_event_counter += 1
	var ev := {
		"id": "aev_%d" % _active_event_counter,
		"name": str(p.get("name", "Evento")),
		"objective": str(p.get("objective", "")),
		"duration": float(p.get("duration", 20.0)),
		"elapsed": 0.0,
		"risk": clampf(float(p.get("risk", 50.0)), 0.0, 100.0),
		"npc_ids": p.get("npc_ids", []) as Array,
		"hint": str(p.get("hint", "")),
		"consequences": str(p.get("consequences", "")),
		"location": str(p.get("location", "")),
		"success_action": str(p.get("success_action", "")),
		"fail_action": str(p.get("fail_action", "")),
		"success_actions": p.get("success_actions", []) as Array,
		"resolved": false,
		"succeeded": false,
	}
	active_events.append(ev)
	return ev


func resolve_active_event(ev_id: String, success: bool) -> void:
	for ev in active_events:
		if ev.id == ev_id and not ev.resolved:
			ev.resolved = true
			ev.succeeded = success
			break


func get_pending_active_events() -> Array:
	return active_events.filter(func(e): return not e.resolved)


func clear_active_events() -> void:
	active_events.clear()


# ---------- evidências ----------
func create_evidence(type: String, location_id: String, description: String,
		strength := 20.0, object_id := "", suspect_id := "",
		witness_id := "", created_by_player := true) -> Dictionary:
	_evidence_counter += 1
	var ev := {
		"id": "ev_%d" % _evidence_counter,
		"type": type,
		"location_id": location_id,
		"object_id": object_id,
		"suspect_id": suspect_id,
		"witness_id": witness_id,
		"created_by_player": created_by_player,
		"strength": clampf(strength, 0.0, 100.0),
		"description": description,
		"day": day,
		"active": true,
	}
	evidence_log.append(ev)
	return ev


func get_evidence_at(location_id: String) -> Array:
	return evidence_log.filter(func(e): return e.active and e.location_id == location_id)


func get_evidence_about(suspect_id: String) -> Array:
	return evidence_log.filter(func(e): return e.active and e.suspect_id == suspect_id)


func get_active_evidence() -> Array:
	return evidence_log.filter(func(e): return e.active)


func destroy_evidence(ev_id: String) -> bool:
	for ev in evidence_log:
		if ev.id == ev_id:
			ev.active = false
			return true
	return false


func transfer_evidence(ev_id: String, new_suspect: String) -> bool:
	for ev in evidence_log:
		if ev.id == ev_id and ev.active:
			ev.suspect_id = new_suspect
			ev.created_by_player = false
			return true
	return false


func evidence_strength_at(location_id: String) -> float:
	var total := 0.0
	for ev in evidence_log:
		if ev.active and ev.location_id == location_id:
			total += ev.strength
	return total


func evidence_against(suspect_id: String) -> float:
	var total := 0.0
	for ev in evidence_log:
		if ev.active and ev.suspect_id == suspect_id:
			total += ev.strength
	return total


func evidence_summary() -> Array:
	var active := get_active_evidence()
	var summaries: Array = []
	for ev in active:
		summaries.append({
			"id": ev.id, "type": ev.type,
			"location": loc_name(ev.location_id),
			"strength": ev.strength,
			"description": ev.description,
		})
	return summaries


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
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "name": player_name, "day": day,
		"instability": instability, "rumors": rumors, "npc": npc_state,
		"world": world_checkpoint, "evidence": evidence_log,
		"events": event_states, "event_flags": event_flags,
		"reputation": reputation}))
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
	var saved_evidence = d.get("evidence", [])
	if typeof(saved_evidence) == TYPE_ARRAY:
		for ev in saved_evidence:
			if typeof(ev) == TYPE_DICTIONARY and ev.has("id") and ev.has("type"):
				evidence_log.append(ev)
				_evidence_counter += 1
	var saved_events = d.get("events", {})
	if typeof(saved_events) == TYPE_DICTIONARY:
		for eid in saved_events:
			if EVENT_DEFS.has(eid):
				event_states[eid] = int(saved_events[eid])
	var saved_flags = d.get("event_flags", {})
	if typeof(saved_flags) == TYPE_DICTIONARY:
		event_flags = saved_flags.duplicate()
	var saved_rep = d.get("reputation", {})
	if typeof(saved_rep) == TYPE_DICTIONARY:
		for gid in saved_rep:
			if reputation.has(gid):
				reputation[gid] = clampf(float(saved_rep[gid]), -100.0, 100.0)
	return true


func _read_save(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f or f.get_length() > 262144:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var version = data.get("version", 1)
	if not AIContract.number_in(version, 1, SAVE_VERSION) or float(version) != floorf(float(version)):
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
