extends Node
## Missão "O Portão Fechado" — estado, pistas, suspeita da testemunha e resolução.
class_name MissionPortao

signal clue_found(clue_id: String, label: String, description: String)
signal suspicion_changed(value: float)
signal gate_opened(seconds_total: float)
signal gate_closed()
signal caught_by_guard(count: int, max_count: int)
signal mission_success()
signal mission_fail(reason: String)

const GATE_POS         := Vector2(640, 238)
const GATE_Y_CROSS     := 212.0   # jogador passa pelo portão quando y < isto
const GATE_OPEN_DUR    := 22.0    # segundos até Bram voltar
const BRAM_AWAY_DIST   := 170.0   # dist mínima de Bram para o portão abrir
const OSRIC_SIGHT      := 108.0   # raio de visão do Osric
const SUSPICION_RATE   := 20.0    # suspeita por segundo (Osric vendo jogador perto do portão)
const SUSPICION_DECAY  := 7.0     # decaimento por segundo
const GATE_NEAR_DIST   := 96.0    # distância do jogador ao portão para Osric suspeitar
const MAX_CATCHES      := 3

enum MPhase { BRIEFING, EXPLORING, PLOTTING, TENSE, ENDED }

var phase         := MPhase.BRIEFING
var clues_found  : Array[String] = []
var suspicion     := 0.0
var gate_is_open  := false
var gate_timer    := 0.0
var gate_prompt_visible := false
var revolt_mode   := false  # true quando a revolta (instabilidade 100%) abriu o portão — sem timer, sem Osric
var catch_count   := 0
var mission_ended := false
var player_crossed := false

# timers de observação para pistas passivas
var _bram_watch_t  := 0.0
var _osric_watch_t := 0.0

# referências (atribuídas em setup)
var _world  = null
var _hud    = null
var _bram   : NPC  = null
var _osric  : NPC  = null
var _player        = null
var _gate_blocker: StaticBody2D = null

# ---- mapa de pistas --------------------------------------------------------
const CLUE_DATA := {
	"carta_convocacao": {
		"label": "Convocação Ignorada",
		"desc": "Há uma ordem de comparecimento que Bram está ignorando. Pressão pública pode forçá-lo a deixar o posto.",
	},
	"joao_rancor": {
		"label": "Rancor do Padeiro",
		"desc": "João da Padaria está furioso com Bram por uma dívida não paga. Uma faísca pode fazer essa briga explodir na praça.",
	},
	"bram_padrao": {
		"label": "Ponto Fraco do Guarda",
		"desc": "Bram abandona o posto quando há tumulto sério na praça ou na ferraria. Ele não consegue ignorar barulho.",
	},
	"osric_vigia": {
		"label": "O Olho do Ancião",
		"desc": "Ancião Osric vigia o portão de longe. Se te ver cruzando sem o guarda, vai denunciá-lo.",
	},
	"moeda_real": {
		"label": "Moeda com Brasão",
		"desc": "Uma moeda do Rei perdida pode desencadear uma investigação — se alguém a 'encontrar' no lugar errado.",
	},
}

# ============================================================================
func setup(p_world, p_hud) -> void:
	_world  = p_world
	_hud    = p_hud
	_bram   = p_world.npcs.get("npc_guard")
	_player = p_world.player
	for v in p_world.villagers:
		var nv := v as NPC
		if nv and nv.id == "villager_elder":
			_osric = nv
			break
	_create_gate_blocker()
	call_deferred("_show_briefing")


func _create_gate_blocker() -> void:
	_gate_blocker = StaticBody2D.new()
	_gate_blocker.name = "MissionGateBlocker"
	_gate_blocker.collision_layer = 1
	_gate_blocker.collision_mask  = 0
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(88, 12)
	shape.shape = rect
	_gate_blocker.add_child(shape)
	_gate_blocker.position = Vector2(640, 222)
	_gate_blocker.process_mode = Node.PROCESS_MODE_ALWAYS
	_world.add_child(_gate_blocker)


# Objetivo exibido em cada fase de progresso
const OBJECTIVES := {
	"exploring": "Descubra como afastar o guarda do portão.",
	"has_weakness": "Você sabe que Bram abandona o posto com tumulto.\nCrie uma distração na praça ou na ferraria.",
	"has_diversion": "A distração está pronta.\nLeve Bram para longe e passe pelo portão.",
	"gate_open": "PORTÃO ABERTO! Cruze agora antes que ele volte.",
}

# Pistas exibidas no painel desde o início (○ = não encontrada, ✓ = encontrada)
const CLUE_LIST := [
	{"id": "bram_padrao",     "label": "Fraqueza de Bram"},
	{"id": "joao_rancor",     "label": "Rancor do Padeiro"},
	{"id": "carta_convocacao","label": "Convocação ignorada"},
	{"id": "moeda_real",      "label": "Moeda do Rei"},
	{"id": "osric_vigia",     "label": "Olho do Ancião"},
]

# Mensagens de feedback causal por ação do jogador (heurísticas simples)
const _FEEDBACK_BY_CLUE := {
	"bram_padrao": "Bram não resiste a tumultos sérios na praça. Falta criar a faísca.",
	"joao_rancor": "João da Padaria pode causar um escândalo com Bram. Tente provocar uma briga.",
	"carta_convocacao": "Pressão pública pode forçar Bram a deixar o posto. Espalhe a convocação.",
	"moeda_real": "Uma moeda suspeita no lugar errado pode iniciar uma investigação.",
	"osric_vigia": "Atenção: Osric vigia o portão. Passe quando ele não puder te ver.",
}


func _show_briefing() -> void:
	phase = MPhase.EXPLORING
	if _hud and _hud.has_method("show_mission_briefing"):
		_hud.show_mission_briefing()
	_push_clue_list()
	_update_objective()

# ============================================================================
func tick(delta: float) -> void:
	if mission_ended:
		return
	_tick_gate(delta)
	_tick_osric_suspicion(delta)
	_tick_passive_clues(delta)
	_tick_crossing()


func _tick_gate(delta: float) -> void:
	if revolt_mode:
		# A revolta já tirou Bram do portão de vez — o portão fica aberto até o jogador cruzar,
		# sem timer e sem risco do guarda voltar.
		return
	if not is_instance_valid(_bram):
		return
	var dist: float = _bram.global_position.distance_to(GATE_POS)
	# Bram pode se afastar por sua rotina ou pela IA. O portão só abre se a
	# cadeia da missão realmente o deixou desguarnecido.
	var bram_away: bool = dist > BRAM_AWAY_DIST and bool(Game.event_flags.get("gate_unguarded", false))

	if bram_away and not gate_is_open:
		_open_gate()
	elif not bram_away and gate_is_open:
		_close_gate(false)

	if gate_is_open:
		gate_timer -= delta
		if _hud and _hud.has_method("update_opportunity"):
			_hud.update_opportunity(gate_timer)
		if gate_timer <= 0.0:
			_close_gate(true)


## Chamado por world.gd quando a instabilidade chega a 100%: a revolta tira Bram do
## portão para sempre. O portão abre e fica aberto até o jogador cruzar.
func force_gate_open_from_revolt() -> void:
	revolt_mode = true
	Game.event_flags["gate_unguarded"] = true
	if not gate_is_open:
		_open_gate()


func _open_gate() -> void:
	gate_is_open = true
	gate_timer   = GATE_OPEN_DUR
	if is_instance_valid(_gate_blocker):
		_gate_blocker.set_collision_layer_value(1, false)
	_world.gate_open = 1.0
	gate_opened.emit(GATE_OPEN_DUR)
	if _hud and _hud.has_method("show_opportunity"):
		_hud.show_opportunity(GATE_OPEN_DUR)
	Sfx.play("confirm")
	_update_objective()


func _close_gate(timed_out: bool) -> void:
	if not gate_is_open or revolt_mode:
		return
	gate_is_open = false
	Game.event_flags["gate_unguarded"] = false
	if is_instance_valid(_gate_blocker):
		_gate_blocker.set_collision_layer_value(1, true)
	_world.gate_open = 0.0
	gate_closed.emit()
	if _hud and _hud.has_method("hide_opportunity"):
		_hud.hide_opportunity()
	if not player_crossed:
		if timed_out:
			_hud.toast("O guarda retornou ao posto.", 3.5)
			call_deferred("_trigger_fail", "O portão foi fechado antes da travessia. Missão fracassada.")
		else:
			_hud.toast("O guarda voltou antes de você atravessar!", 3.0)
		_update_objective()


func _tick_osric_suspicion(delta: float) -> void:
	if revolt_mode:
		if _hud and _hud.has_method("set_suspicion_visible"):
			_hud.set_suspicion_visible(false)
		return
	if not is_instance_valid(_osric) or not is_instance_valid(_player):
		return

	var player_dist_gate: float   = _player.global_position.distance_to(GATE_POS)
	var osric_dist_player: float  = _player.global_position.distance_to(_osric.global_position)
	var osric_sees: bool          = osric_dist_player < OSRIC_SIGHT

	# Suspeita sobe só quando Osric vê jogador perto do portão enquanto ele está aberto
	if osric_sees and gate_is_open and player_dist_gate < GATE_NEAR_DIST:
		suspicion = minf(suspicion + SUSPICION_RATE * delta, 100.0)
		if _hud and _hud.has_method("set_suspicion"):
			_hud.set_suspicion(suspicion)
			_hud.set_suspicion_visible(true)
		suspicion_changed.emit(suspicion)
		if suspicion >= 100.0 and not mission_ended:
			_osric_catches_player()
	elif osric_sees:
		# Osric vê jogador mas não está perto do portão — pista passiva
		if _hud and _hud.has_method("set_suspicion_visible"):
			_hud.set_suspicion_visible(true)
		suspicion = maxf(suspicion - SUSPICION_DECAY * 0.3 * delta, 0.0)
		if _hud and _hud.has_method("set_suspicion"):
			_hud.set_suspicion(suspicion)
	else:
		# Osric não vê jogador — suspeita decai
		suspicion = maxf(suspicion - SUSPICION_DECAY * delta, 0.0)
		if suspicion <= 0.01 and _hud and _hud.has_method("set_suspicion_visible"):
			_hud.set_suspicion_visible(false)
		elif _hud and _hud.has_method("set_suspicion"):
			_hud.set_suspicion(suspicion)


func _tick_passive_clues(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	# Pista: observar Bram de perto por 5 segundos
	if is_instance_valid(_bram):
		var d_bram: float = _player.global_position.distance_to(_bram.global_position)
		if d_bram < 72.0:
			_bram_watch_t += delta
			if _bram_watch_t >= 5.0:
				_discover_clue("bram_padrao")
		else:
			_bram_watch_t = 0.0

	# Pista: ficar perto do Ancião Osric por 4 segundos
	if is_instance_valid(_osric):
		var d_osric: float = _player.global_position.distance_to(_osric.global_position)
		if d_osric < 80.0:
			_osric_watch_t += delta
			if _osric_watch_t >= 4.0:
				_discover_clue("osric_vigia")
		else:
			_osric_watch_t = 0.0


func _tick_crossing() -> void:
	if player_crossed or mission_ended or not is_instance_valid(_player):
		if gate_prompt_visible:
			gate_prompt_visible = false
			if _hud:
				_hud.hide_gate_prompt()
		return
	var pp: Vector2 = _player.global_position
	var near_gate := gate_is_open and pp.distance_to(GATE_POS) < GATE_NEAR_DIST
	if near_gate and not gate_prompt_visible:
		gate_prompt_visible = true
		if _hud:
			_hud.show_gate_prompt()
	elif not near_gate and gate_prompt_visible:
		gate_prompt_visible = false
		if _hud:
			_hud.hide_gate_prompt()


func try_open_gate() -> bool:
	if not gate_is_open or player_crossed or mission_ended:
		return false
	if not is_instance_valid(_player):
		return false
	if _player.global_position.distance_to(GATE_POS) > GATE_NEAR_DIST:
		if _hud:
			_hud.toast("Chegue mais perto do portão.", 2.0)
		return false
	player_crossed = true
	mission_ended = true
	phase = MPhase.ENDED
	gate_prompt_visible = false
	if _hud:
		_hud.hide_gate_prompt()
	Game.event_flags["player_crossed_gate"] = true
	mission_success.emit()
	return true


func _osric_catches_player() -> void:
	suspicion   = 0.0
	catch_count += 1
	if _hud and _hud.has_method("set_suspicion_visible"):
		_hud.set_suspicion_visible(false)
	if _hud and _hud.has_method("flash_danger"):
		_hud.flash_danger()

	if is_instance_valid(_osric):
		_osric.say("Ei! O que você está fazendo aí, rapaz?!", 4.0)
	if is_instance_valid(_bram):
		_bram.walk_to(GATE_POS, true)
		_bram.say("Quem se aproxima do portão?!", 3.5)
		get_tree().create_timer(0.8).timeout.connect(func(): _close_gate(false))

	caught_by_guard.emit(catch_count, MAX_CATCHES)

	if catch_count >= MAX_CATCHES:
		call_deferred("_trigger_fail", "Você foi flagrado %d vezes pelo Ancião Osric. Missão fracassada." % MAX_CATCHES)
	else:
		if _hud:
			_hud.toast("Ancião Osric alertou o guarda! (%d/%d flagrantes)" % [catch_count, MAX_CATCHES], 4.5)
		phase = MPhase.TENSE

# ============================================================================
# API pública — world.gd chama estes métodos nos momentos certos
# ============================================================================
func notify_object_picked(obj_id: String) -> void:
	match obj_id:
		"sealed_letter", "rites_book":
			_discover_clue("carta_convocacao")
		"royal_coin", "royal_ring":
			_discover_clue("moeda_real")


func notify_npc_whispered(npc_id: String) -> void:
	match npc_id:
		"npc_baker":
			_discover_clue("joao_rancor")
		"npc_guard":
			_discover_clue("bram_padrao")


func notify_gossip_sent(gossip_text: String) -> void:
	## Feedback causal quando o jogador planta um boato no terminal.
	if mission_ended or not _hud:
		return
	var txt := gossip_text.to_lower()
	# heurísticas simples para orientar sem spoilar
	if ("bram" in txt or "guarda" in txt) and not clues_found.has("bram_padrao"):
		_hud.add_event_log("Interessante... Bram reagiu ao boato. Observe o que o move.")
	elif "padeiro" in txt or "joão" in txt or "dívida" in txt:
		if not clues_found.has("joao_rancor"):
			_discover_clue("joao_rancor")
		else:
			_hud.add_event_log("A briga entre João e Bram pode ser o gatilho que você precisa.")
	elif "rei" in txt or "moeda" in txt or "prova" in txt:
		_hud.add_event_log("Uma acusação precisa de evidência. Encontre um objeto comprometedor.")
	elif clues_found.size() == 0:
		_hud.add_event_log("O boato circulou, mas o guarda não saiu. Tente algo mais específico.")
	_update_objective()


func _discover_clue(clue_id: String) -> void:
	if clues_found.has(clue_id):
		return
	clues_found.append(clue_id)
	var data: Dictionary = CLUE_DATA.get(clue_id, {})
	var lbl  := str(data.get("label", clue_id))
	var desc := str(data.get("desc", ""))
	clue_found.emit(clue_id, lbl, desc)
	if _hud and _hud.has_method("show_clue_popup"):
		_hud.show_clue_popup(lbl, desc)
	if _hud:
		_hud.toast("Pista descoberta: %s" % lbl, 2.5)
	# atualiza o ícone da pista no painel e mostra feedback causal
	if _hud and _hud.has_method("mark_clue_found"):
		_hud.mark_clue_found(clue_id)
	var feedback: String = _FEEDBACK_BY_CLUE.get(clue_id, "")
	if feedback != "" and _hud:
		_hud.add_event_log(feedback)
	_update_objective()


func _push_clue_list() -> void:
	if not _hud or not _hud.has_method("set_mission_clues"):
		return
	var list: Array = []
	for entry in CLUE_LIST:
		list.append({"id": entry.id, "label": entry.label, "found": clues_found.has(entry.id)})
	_hud.set_mission_clues(list)


func _update_objective() -> void:
	if not _hud or not _hud.has_method("set_mission_objective"):
		return
	var obj: String
	if gate_is_open:
		obj = OBJECTIVES["gate_open"]
	elif bool(Game.event_flags.get("guard_distracted", false)) or bool(Game.event_flags.get("gate_unguarded", false)):
		obj = OBJECTIVES["has_diversion"]
	elif clues_found.has("bram_padrao") or clues_found.has("joao_rancor") or clues_found.has("carta_convocacao"):
		obj = OBJECTIVES["has_weakness"]
	else:
		obj = OBJECTIVES["exploring"]
	_hud.set_mission_objective(obj)


func _trigger_fail(reason: String) -> void:
	mission_ended = true
	phase = MPhase.ENDED
	mission_fail.emit(reason)
