extends Node2D
## Placement preview in world pixels: dims the land a building can never use, then draws the footprint
## (with a translucent copy of the building) under the pointer, green when `valid` accepts it, red otherwise.

const BuildingArt := preload("res://game/town/building_art.gd")
const CELL := 32
const GRID := Vector2i(48, 8)
const BUILDABLE := Rect2i(10, 0, 28, 7)
const ARENA := Rect2i(16, 0, 16, 8)
const FORBIDDEN := Color(0.75, 0.15, 0.12, 0.22)
const GOOD := Color(0.3, 0.9, 0.35, 0.45)
const BAD := Color(0.95, 0.25, 0.2, 0.5)

var cell := Vector2i.ZERO
var ok := false
var on_grid := false
var _footprint := Vector2i.ONE
var _valid := Callable()
var _art: Node2D


func begin(id: StringName, footprint: Vector2i, valid: Callable) -> void:
	_footprint = footprint
	_valid = valid
	_art = BuildingArt.build(id, 1, footprint)
	_art.modulate.a = 0.55
	_art.visible = false
	_art.show_behind_parent = true  # the green/red footprint tint is drawn over the building
	add_child(_art)
	visible = true
	z_index = 20
	queue_redraw()


func end() -> void:
	_art.queue_free()
	_art = null
	visible = false


## Snap to `at` (a grid cell) and re-evaluate validity; `at` outside the grid hides the footprint.
func move_to(at: Vector2i) -> void:
	on_grid = Rect2i(Vector2i.ZERO, GRID).has_point(at)
	cell = at
	ok = on_grid and _valid.call(at)
	_art.visible = on_grid
	_art.position = Vector2(at * CELL)
	queue_redraw()


func _draw() -> void:
	if _art == null:
		return
	for zone in _forbidden_zones():
		draw_rect(Rect2(Vector2(zone.position * CELL), Vector2(zone.size * CELL)), FORBIDDEN)
	if on_grid:
		var rect := Rect2(Vector2(cell * CELL), Vector2(_footprint * CELL))
		var tint := GOOD if ok else BAD
		draw_rect(rect, tint)
		draw_rect(rect, Color(tint, 1.0), false, 2.0)


## Land buildings can never use: unowned columns, the arena, and the public path row.
func _forbidden_zones() -> Array[Rect2i]:
	return [
		Rect2i(0, 0, BUILDABLE.position.x, GRID.y),
		Rect2i(BUILDABLE.end.x, 0, GRID.x - BUILDABLE.end.x, GRID.y),
		ARENA,
		Rect2i(BUILDABLE.position.x, BUILDABLE.end.y, BUILDABLE.size.x, GRID.y - BUILDABLE.end.y),
	]
