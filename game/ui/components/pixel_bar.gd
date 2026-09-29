class_name PixelBar
extends Control
## Sunnyside 15x7 HP / mana bar drawn at an integer scale (default 3x = 45x21). Fill is redrawn per column,
## so any ratio shows smoothly instead of the sprite's 7 fixed stages.

enum Kind { HP, MANA, RED }

const FILL := [Color("63c74d"), Color("0099db"), Color("e43b44")]
const FILLED_COLS := 11  # inner columns 2..12
const INNER_X := 2
const INNER_Y := 2
const INNER_H := 2

@export var kind := Kind.HP:
	set(v):
		kind = v
		queue_redraw()
@export_range(0.0, 1.0, 0.001) var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
@export_range(1, 6) var pixel_scale := 3:
	set(v):
		pixel_scale = v
		custom_minimum_size = Vector2(15, 7) * v
		queue_redraw()

const FRAMES: Array[Texture2D] = [  # empty frames, dark background tinted per colour
	preload("res://asset/Sunnyside_World_Assets/UI/greenbar_00.png"),
	preload("res://asset/Sunnyside_World_Assets/UI/bluebar_00.png"),
	preload("res://asset/Sunnyside_World_Assets/UI/redbar_00.png"),
]


func _init() -> void:
	custom_minimum_size = Vector2(15, 7) * 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := pixel_scale
	draw_texture_rect(FRAMES[kind], Rect2(Vector2.ZERO, Vector2(15, 7) * s), false)
	var cols := int(roundf(ratio * FILLED_COLS))
	if ratio > 0.0:
		cols = maxi(cols, 1)
	if cols > 0:
		draw_rect(Rect2(INNER_X * s, INNER_Y * s, cols * s, INNER_H * s), FILL[kind])
