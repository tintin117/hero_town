extends Node2D

const TILE_SIZE := 64
const GROUND_Y := 400.0
const STRIP_H := 64.0
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.3)

func _draw() -> void:
	var vp_w := get_viewport_rect().size.x
	var cols := int(vp_w / TILE_SIZE) + 1
	var top := GROUND_Y - STRIP_H
	draw_rect(Rect2(0.0, top, vp_w, STRIP_H), Color(1.0, 1.0, 1.0, 0.06))
	for c in cols:
		var x := float(c * TILE_SIZE)
		draw_line(Vector2(x, top), Vector2(x, GROUND_Y), LINE_COLOR)
	draw_line(Vector2(0.0, top), Vector2(vp_w, top), LINE_COLOR)
	draw_line(Vector2(0.0, GROUND_Y), Vector2(vp_w, GROUND_Y), LINE_COLOR)
