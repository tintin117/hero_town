extends Node2D
## "MAIN EVENT" ribbon over the ring for a few seconds when a series starts. The ribbon is the
## shared UI theme's Ribbon style; the arena drives it with tick(delta) and never mutates it.

const THEME := preload("res://game/ui/theme/fight_club_theme.tres")
const FONT := preload("res://fonts/PeaberryBase.ttf")
const SHOW_TIME := 3.0
const POP_TIME := 0.25
const FADE_TIME := 0.4
const HEIGHT := 46.0
const MAX_WIDTH := 400.0
const GOLD := Color("f2c771")
const CREAM := Color("fff0cf")
const INK := Color("18222f")

var _age := -1.0  # < 0 while hidden
var _title := ""
var _mult := ""
var _width := 300.0


func _ready() -> void:
	hide()


func is_showing() -> bool:
	return _age >= 0.0


## `event`: the series' main_event ({id, kind, title, ripeness, multiplier}); {} shows nothing.
func show_event(event: Dictionary) -> void:
	if event.is_empty():
		hide_now()
		return
	_title = str(event.get("title", "")).to_upper()
	_mult = "x%s" % String.num(float(event.get("multiplier", 1.0)), 1)
	_width = clampf(FONT.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 150.0, 260.0, MAX_WIDTH)
	_age = 0.0
	show()
	_apply()
	queue_redraw()


func hide_now() -> void:
	_age = -1.0
	hide()


func tick(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	if _age >= SHOW_TIME:
		hide_now()
	else:
		_apply()


## Pop in (scale), hold, fade out.
func _apply() -> void:
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	scale = Vector2(1.0 + (1.0 - pop) * 0.3, pop)
	modulate.a = clampf((SHOW_TIME - _age) / FADE_TIME, 0.0, 1.0)


func _draw() -> void:
	if _age < 0.0:
		return
	var area := Rect2(Vector2(-_width * 0.5, -HEIGHT * 0.5), Vector2(_width, HEIGHT))
	THEME.get_stylebox(&"panel", &"Ribbon").draw(get_canvas_item(), area)
	_line("MAIN EVENT", Vector2(-_width * 0.5 + 34.0, -3.0), _width - 68.0, 12, GOLD)
	_line(_title, Vector2(-_width * 0.5 + 34.0, 15.0), _width - 68.0, 16, CREAM)
	var badge := Vector2(_width * 0.5 - 26.0, -HEIGHT * 0.5 - 2.0)
	draw_circle(badge, 22.0, INK)
	draw_circle(badge, 20.0, GOLD)
	draw_string(FONT, badge + Vector2(-20, 4), _mult, HORIZONTAL_ALIGNMENT_CENTER, 40, 14, INK)


func _line(value: String, at: Vector2, width: float, size: int, color: Color) -> void:
	draw_string_outline(FONT, at, value, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, INK)
	draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
