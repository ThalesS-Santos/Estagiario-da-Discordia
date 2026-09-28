extends Node
## Música ambiente persistente entre as telas do jogo.
##
## Tolerante a falhas do driver de áudio no Windows (WASAPI): se a faixa
## parar por erro do dispositivo, tentamos religar a cada 2 s enquanto o
## estado "ativo" estiver ligado.

const MUSIC_PATH := "res://assets/audio/main_menu.mp3"

var player: AudioStreamPlayer
var _should_play := true
var _watchdog: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "BackgroundMusicPlayer"
	var track := load(MUSIC_PATH) as AudioStreamMP3
	if track == null:
		push_warning("Music: falha ao carregar %s — modo silencioso." % MUSIC_PATH)
		add_child(player)
		return
	track.loop = true
	player.stream = track
	player.bus = "Master"
	# Reduz o custo de mudanças rápidas de volume no bus.
	player.finished.connect(_on_finished)
	add_child(player)
	_update_volume()
	player.play()
	# Watchdog contra invalidação do output_device (WASAPI GetBufferSize).
	_watchdog = Timer.new()
	_watchdog.wait_time = 2.0
	_watchdog.one_shot = false
	_watchdog.autostart = true
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.timeout.connect(_check_playing)
	add_child(_watchdog)


func _on_finished() -> void:
	# Loop está no stream, mas se o driver caiu o stream pode "finalizar";
	# nesse caso, tenta de novo silenciosamente.
	if _should_play and is_instance_valid(player) and player.stream:
		player.play()


func _check_playing() -> void:
	if not _should_play:
		return
	if not is_instance_valid(player) or player.stream == null:
		return
	if not player.playing:
		# Provavelmente o output_device foi reaberto pelo Godot — retomamos.
		player.play()


func set_volume(value: float) -> void:
	if is_instance_valid(player):
		player.volume_db = linear_to_db(maxf(value, 0.001))


func set_menu_active(active: bool) -> void:
	_should_play = active
	if not is_instance_valid(player) or player.stream == null:
		return
	if active and not player.playing:
		player.play()
	elif not active and player.playing:
		player.stop()


func _update_volume() -> void:
	set_volume(float(Game.settings.music))
