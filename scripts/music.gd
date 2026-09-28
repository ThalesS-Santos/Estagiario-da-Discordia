extends Node
## Trilha sonora dinâmica com crossfade suave entre faixas.
##
## API pública:
##   Music.play("menu")        — troca de faixa (com crossfade)
##   Music.set_day(n)          — atualiza música de jogo conforme o dia (1-3)
##   Music.trigger_revolt()    — toca a música dramática da revolta
##   Music.stop()              — fade out total
##   Music.set_volume(0..1)    — volume global
##   Music.set_menu_active(b)  — compatibilidade com código antigo

## Faixas disponíveis. Coloque os arquivos em assets/audio/.
## Se um arquivo não existir, a faixa fica silenciosa sem travar o jogo.
const TRACKS := {
	"menu":      "res://assets/audio/main_menu.mp3",
	"briefing":  "res://assets/audio/briefing.mp3",
	"day1":      "res://assets/audio/in_game_day1.mp3",
	"day2":      "res://assets/audio/in_game_day2.mp3",
	"day3":      "res://assets/audio/in_game_day3.mp3",
	"revolt":    "res://assets/audio/revolt.mp3",
	"defeat":    "res://assets/audio/defeat.wav",
	"cinematic": "res://assets/audio/cinematic_final.mp3",
	"credits":   "res://assets/audio/credits.mp3",
	"victory":   "res://assets/audio/victory_message.mp3",
}

## Fallbacks: se a faixa principal não existe, tenta essa no lugar.
const FALLBACKS := {
	"day1": "res://assets/audio/In-game.mp3",
	"day2": "res://assets/audio/In-game.mp3",
	"day3": "res://assets/audio/In-game.mp3",
	"briefing": "res://assets/audio/main_menu.mp3",
	"victory": "res://assets/audio/main_menu.mp3",
	"defeat": "",
	"revolt": "",
	"cinematic": "",
	"credits": "res://assets/audio/main_menu.mp3",
}

const FADE_NORMAL := 1.5
const FADE_FAST   := 0.6   # revolta: transição de impacto

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _current_id := ""
var _volume := 1.0
var _fade_tween: Tween
var _watchdog: Timer
var _revolt_playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = _make_player()
	_player_b = _make_player()
	_volume = float(Game.settings.music)
	_watchdog = Timer.new()
	_watchdog.wait_time = 2.5
	_watchdog.autostart = true
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.timeout.connect(_check_looping)
	add_child(_watchdog)
	play("menu")


# ------------------------------------------------------------ API pública

func play(id: String, fade_time := FADE_NORMAL) -> void:
	if _current_id == id:
		return
	var path := _resolve_path(id)
	_current_id = id
	if path.is_empty():
		# arquivo não encontrado: silencia sem travar
		_fade_out_all(fade_time * 0.5)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_fade_out_all(fade_time * 0.5)
		return
	# Só defeat não faz loop (jingle curto); o resto loopa enquanto a tela estiver aberta
	var NO_LOOP := ["defeat"]
	if id not in NO_LOOP:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	_crossfade(stream, fade_time)


func set_day(day: int) -> void:
	## Chamado por world.gd a cada início de dia. Só muda se estiver numa faixa de jogo.
	if _revolt_playing:
		return
	var target := "day%d" % clampi(day, 1, 3)
	if _current_id != target:
		play(target)


func trigger_revolt() -> void:
	## Música dramática da revolta — transição rápida para maior impacto.
	_revolt_playing = true
	play("revolt", FADE_FAST)


func stop(fade_time := FADE_NORMAL) -> void:
	_current_id = ""
	_revolt_playing = false
	_fade_out_all(fade_time)


func set_volume(value: float) -> void:
	_volume = maxf(value, 0.001)
	if _fade_tween and _fade_tween.is_running():
		return
	_set_both_volumes()


## Compatibilidade com o código legado em main.gd
func set_menu_active(active: bool) -> void:
	if active:
		_revolt_playing = false
		play("menu")


# ------------------------------------------------------------ interno

func _resolve_path(id: String) -> String:
	var primary: String = TRACKS.get(id, "")
	if not primary.is_empty() and ResourceLoader.exists(primary):
		return primary
	var fallback: String = FALLBACKS.get(id, "")
	if not fallback.is_empty() and ResourceLoader.exists(fallback):
		return fallback
	return ""


func _crossfade(stream: AudioStream, fade: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	var out_p := _active_player()
	var in_p  := _inactive_player()
	in_p.stream = stream
	in_p.volume_db = -80.0
	in_p.play()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(in_p,  "volume_db", linear_to_db(_volume), fade)
	_fade_tween.tween_property(out_p, "volume_db", -80.0, fade)
	_fade_tween.finished.connect(func():
		out_p.stop()
		out_p.volume_db = -80.0, CONNECT_ONE_SHOT)


func _fade_out_all(fade: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_player_a, "volume_db", -80.0, fade)
	_fade_tween.tween_property(_player_b, "volume_db", -80.0, fade)
	_fade_tween.finished.connect(func():
		_player_a.stop()
		_player_b.stop(), CONNECT_ONE_SHOT)


func _set_both_volumes() -> void:
	var db := linear_to_db(_volume)
	if _player_a.playing:
		_player_a.volume_db = db
	if _player_b.playing:
		_player_b.volume_db = db


func _active_player() -> AudioStreamPlayer:
	if _player_a.playing:
		return _player_a
	return _player_b


func _inactive_player() -> AudioStreamPlayer:
	if _player_a.playing:
		return _player_b
	return _player_a


func _check_looping() -> void:
	## Watchdog: se o driver de áudio do Windows reiniciou e parou a faixa, retoma.
	if _current_id.is_empty():
		return
	for p: AudioStreamPlayer in [_player_a, _player_b]:
		if p.stream != null and not p.playing and p.volume_db > -40.0:
			p.play()


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -80.0
	add_child(p)
	return p
