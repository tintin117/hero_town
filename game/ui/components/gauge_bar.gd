class_name GaugeBar
extends Control
## Themed 0..max_value bar with optional tier marks and one movable marker.
## Look comes from the theme type named by `style` (HypeGauge / ExciteGauge ...): styles base+fill, constants inset_*.

@export var style: StringName = &"HypeGauge":
	set(v):
		style = v
		queue_redraw()
@export var max_value := 100.0
@export var value := 0.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		_tween_shown()
## Values (same scale as value) where a dark divider is drawn on the bar, e.g. the excitement tiers.
@export var marks := PackedFloat32Array():
	set(v):
		marks = v
		queue_redraw()
## Movable marker (manager threshold). Negative hides it.
@export var marker := -1.0:
	set(v):
		marker = v
		queue_redraw()
## Pulses a light wash over the fill (used when a threshold is reached).
@export var hot := false:
	set(v):
		if v == hot:
			return
		hot = v
		if is_inside_tree():
			_sync_hot()
		queue_redraw()
@export var animate := true

var _shown := 0.0
var _pulse := 0.0
var _tween: Tween
var _hot_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(96, 26)


func _ready() -> void:
	_shown = value
	_sync_hot()


func inner_rect() -> Rect2:
	var s := StringName(style)
	var l := get_theme_constant("inset_left", s)
	var t := get_theme_constant("inset_top", s)
	var r := get_theme_constant("inset_right", s)
	var b := get_theme_constant("inset_bottom", s)
	return Rect2(l, t, size.x - l - r, size.y - t - b)


## x position (local) of a value on the bar.
func x_at(v: float) -> float:
	var inner := inner_rect()
	return inner.position.x + roundf(inner.size.x * clampf(v / max_value, 0.0, 1.0))


func _tween_shown() -> void:
	if not animate or not is_inside_tree():
		_shown = value
		queue_redraw()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_shown = v
		queue_redraw(), _shown, value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _sync_hot() -> void:
	if _hot_tween:
		_hot_tween.kill()
	_pulse = 0.0
	if not hot:
		return
	_hot_tween = create_tween().set_loops()
	_hot_tween.tween_method(func(v: float) -> void:
		_pulse = v
		queue_redraw(), 0.0, 1.0, 0.45)
	_hot_tween.tween_method(func(v: float) -> void:
		_pulse = v
		queue_redraw(), 1.0, 0.0, 0.45)
	_hot_tween.set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var s := StringName(style)
	draw_style_box(get_theme_stylebox("base", s), Rect2(Vector2.ZERO, size))
	var inner := inner_rect()
	var w := roundf(inner.size.x * clampf(_shown / max_value, 0.0, 1.0))
	if w > 0.0:
		draw_style_box(get_theme_stylebox("fill", s), Rect2(inner.position, Vector2(w, inner.size.y)))
		if hot:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), Color(1, 1, 1, 0.1 + 0.35 * _pulse))
	for m in marks:
		var x := x_at(m)
		draw_rect(Rect2(x - 1, inner.position.y, 2, inner.size.y), get_theme_color("mark", s))
	if marker >= 0.0:
		var mx := x_at(marker)
		draw_rect(Rect2(mx - 2, 0, 4, size.y), Color("161c2e"))
		draw_rect(Rect2(mx - 1, 1, 2, size.y - 2), Color("fff2a0"))
