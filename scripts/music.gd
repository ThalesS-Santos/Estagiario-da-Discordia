extends Node
## Música ambiente persistente entre as telas do jogo.

const MUSIC_PATH := "res://assets/audio/main_song.mp3"

var player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "BackgroundMusicPlayer"
	var track := load(MUSIC_PATH) as AudioStreamMP3
	track.loop = true
	player.stream = track
	player.bus = "Master"
	add_child(player)
	_update_volume()
	player.play()


func set_volume(value: float) -> void:
	if is_instance_valid(player):
		player.volume_db = linear_to_db(maxf(value, 0.001))


func _update_volume() -> void:
	set_volume(float(Game.settings.music))
