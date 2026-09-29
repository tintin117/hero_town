class_name HypeGauge
extends HBoxContainer
## Hype 0-100 with flame icon and a number. The manager threshold shows as a gold notch on the bar;
## once value >= threshold the bar pulses and the flame bounces. Setters only. Min size ~ (200, 32).

@export_range(0.0, 100.0) var value := 0.0:
	set(v):
		value = v
		_refresh()
## Manager "book at hype >= X" marker; negative = no marker.
@export_range(-1.0, 100.0) var threshold := -1.0:
	set(v):
		threshold = v
		_refresh()

var _bounce: Tween

@onready var _bar: GaugeBar = $Bar
@onready var _flame: TextureRect = $Flame
@onready var _number: Label = $Number


func _ready() -> void:
	_refresh()


func set_value(v: float) -> void:
	value = v


func set_threshold(v: float) -> void:
	threshold = v


func is_ready_to_book() -> bool:
	return threshold >= 0.0 and value >= threshold


func _refresh() -> void:
	if not is_node_ready():
		return
	_bar.value = value
	_bar.marker = threshold
	_number.text = str(int(value))
	var hot := is_ready_to_book()
	_bar.hot = hot
	if hot and (_bounce == null or not _bounce.is_running()):
		_flame.pivot_offset = _flame.size / 2
		_bounce = create_tween().set_loops()
		_bounce.tween_property(_flame, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_SINE)
		_bounce.tween_property(_flame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	elif not hot:
		if _bounce:
			_bounce.kill()
		_flame.scale = Vector2.ONE
