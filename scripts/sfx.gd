extends Node
## Sintetizador de efeitos sonoros procedurais (autoload "Sfx"). Sem assets externos.

const RATE := 22050
# id: [freq_ini, freq_fim, duração, mistura_ruído, volume]
const RECIPES := {
	"clack": [1800, 900, 0.03, 0.6, 0.5],
	"bip": [880, 880, 0.07, 0.0, 0.35],
	"confirm": [660, 990, 0.16, 0.0, 0.4],
	"whoosh": [300, 1200, 0.25, 0.7, 0.35],
	"plop": [320, 90, 0.16, 0.0, 0.6],
	"gasp": [500, 720, 0.2, 0.5, 0.3],
	"murmur": [140, 120, 0.5, 0.9, 0.25],
	"thud": [90, 40, 0.28, 0.5, 0.8],
	"shout": [420, 620, 0.3, 0.4, 0.4],
	"tension": [180, 520, 0.9, 0.1, 0.3],
	"alarm": [760, 520, 0.9, 0.0, 0.4],
	"bubble": [300, 620, 0.3, 0.0, 0.3],
	"fire": [200, 150, 0.5, 1.0, 0.3],
	"splash": [800, 200, 0.3, 1.0, 0.5],
	"coins": [2000, 3000, 0.25, 0.2, 0.3],
	"horn": [220, 220, 0.6, 0.05, 0.5],
	"error": [200, 140, 0.25, 0.1, 0.5],
}

var players: Array = []
var cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(id: String) -> void:
	if id == "":
		return
	var s = _get_stream(id if RECIPES.has(id) else "bip")
	for p in players:
		if not p.playing:
			p.stream = s
			p.volume_db = linear_to_db(maxf(float(Game.settings.sfx), 0.001))
			p.play()
			return


func _get_stream(id: String) -> AudioStreamWAV:
	if cache.has(id):
		return cache[id]
	var r: Array = RECIPES[id]
	var n := int(RATE * float(r[2]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(float(r[0]), float(r[1]), t) / RATE
		var v := lerpf(sin(phase), randf() * 2.0 - 1.0, float(r[3])) * float(r[4]) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	cache[id] = w
	return w
