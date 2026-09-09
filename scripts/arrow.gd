extends Node2D

@export var flight_time: float = 0.35
@export var arc_height: float = 40.0

@onready var sprite: Sprite2D = $Sprite2D

var _start: Vector2
var _end: Vector2
var _control: Vector2
var _elapsed: float = 0.0

func setup(from: Vector2, to: Vector2, color: Color) -> void:
	_start = from + Vector2(0, -18)
	_end = to - (to - from).normalized() * 13.0
	_control = _start.lerp(_end, 0.5) - Vector2(0, arc_height)
	sprite.modulate = color
	global_position = _start

func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clamp(_elapsed / flight_time, 0.0, 1.0)

	var pos := _quad_bezier(t)
	var ahead := _quad_bezier(min(t + 0.02, 1.0))
	global_position = pos
	rotation = (ahead - pos).angle()

	if t >= 1.0:
		queue_free()

func _quad_bezier(t: float) -> Vector2:
	var q0 := _start.lerp(_control, t)
	var q1 := _control.lerp(_end, t)
	return q0.lerp(q1, t)
