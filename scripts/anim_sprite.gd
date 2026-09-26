class_name AnimSprite
extends Sprite2D
## Sprite de spritesheet que avança os frames sozinho (fps > 0) na linha `row`.

var fps := 0.0
var phase := 0.0
var row := 0
var t := 0.0


func _ready() -> void:
	t = phase * 7.0
	set_process(fps > 0.0 and hframes > 1)
	_apply()


func _process(delta: float) -> void:
	t += delta
	_apply()


func _apply() -> void:
	var col := int(t * fps) % hframes if fps > 0.0 else 0
	frame = clampi(row, 0, vframes - 1) * hframes + col
