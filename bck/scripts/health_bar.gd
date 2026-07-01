extends Node2D

var max_value := 100.0
var current_value := 100.0

func update_bar(current: int, maximum: int) -> void:
	current_value = float(current)
	max_value = float(maximum)
	queue_redraw()

func _draw() -> void:
	if current_value >= max_value:
		return
	var ratio := current_value / max_value
	var w := 36.0
	var h := 5.0
	var x := -w * 0.5
	var y := -30.0
	draw_rect(Rect2(x, y, w, h), Color(0.15, 0.15, 0.15, 0.85))
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.1, 0.85, 0.1)
	elif ratio > 0.25:
		bar_color = Color(0.9, 0.85, 0.0)
	else:
		bar_color = Color(0.9, 0.1, 0.1)
	draw_rect(Rect2(x, y, w * ratio, h), bar_color)
