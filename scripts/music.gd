extends Node
## Música ambiente persistente entre as telas do jogo.

const MENU_MUSIC_PATH := "res://assets/audio/main_menu.mp3"
const GAME_MUSIC_PATH := "res://assets/audio/In-game.mp3"

var player: AudioStreamPlayer
var current_track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "BackgroundMusicPlayer"
	player.bus = "Master"
	add_child(player)
	_update_volume()
	_play_track(MENU_MUSIC_PATH)


func set_volume(value: float) -> void:
	if is_instance_valid(player):
		player.volume_db = linear_to_db(maxf(value, 0.001))


func set_menu_active(active: bool) -> void:
	if not is_instance_valid(player):
		return
	_play_track(MENU_MUSIC_PATH if active else GAME_MUSIC_PATH)


func stop() -> void:
	if is_instance_valid(player):
		player.stop()
		current_track = ""


func _play_track(path: String) -> void:
	if not is_instance_valid(player) or current_track == path and player.playing:
		return
	var track := load(path) as AudioStreamMP3
	if track == null:
		push_warning("Arquivo de música não encontrado ou inválido: %s" % path)
		player.stop()
		current_track = ""
		return
	track.loop = true
	player.stop()
	player.stream = track
	current_track = path
	player.play()


func _update_volume() -> void:
	set_volume(float(Game.settings.music))
