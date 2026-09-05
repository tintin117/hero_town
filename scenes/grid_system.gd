extends Node2D
class_name GridSystem

@export var grid_size: Vector2i = Vector2i(12, 5)  ## (cols, rows) of the buildable area

var tile_map: TileMapLayer

var _occupancy: Dictionary = {}  # Vector2i cell -> occupant, absent = free
var _highlight: Sprite2D

var hovered_cell: Vector2i = Vector2i(-1, -1)

## ponytail: resolved in _enter_tree (fires for the whole scene before any
## node's _ready) rather than @onready, because board_2d.gd's _ready() --an
## earlier sibling-- calls grid_to_world() before GridSystem's own _ready()
## would otherwise have run.
func _enter_tree() -> void:
	tile_map = get_node("../Terrain")

func _ready() -> void:
	_build_highlight()

## Translucent square that snaps to the hovered cell during placement.
func _build_highlight() -> void:
	_highlight = Sprite2D.new()
	_highlight.texture = load("res://resources/textures/white.tres")
	var tex_size: Vector2 = _highlight.texture.get_size()
	_highlight.scale = Vector2(tile_map.tile_set.tile_size) / tex_size
	_highlight.modulate = Color(0.4, 1.0, 0.5, 0.35)
	_highlight.visible = false
	add_child(_highlight)

func set_overlay(on: bool) -> void:
	_highlight.visible = on

func set_highlight_color(valid: bool) -> void:
	var c := Color(0.4, 1.0, 0.5) if valid else Color(1.0, 0.35, 0.3)
	_highlight.modulate = Color(c.r, c.g, c.b, 0.35)

## Tracked from motion events rather than polling the OS cursor, so synthetic
## input (tests) and real mice behave identically.
var _mouse_screen_pos := Vector2(-INF, -INF)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_screen_pos = event.position

func _process(_delta: float) -> void:
	if _mouse_screen_pos.x == -INF:
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * _mouse_screen_pos
	hovered_cell = world_to_grid(world_pos)
	if _highlight.visible and hovered_cell != Vector2i(-1, -1):
		_highlight.position = grid_to_world(hovered_cell) - global_position

func grid_to_world(cell: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(cell))

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var cell := tile_map.local_to_map(tile_map.to_local(world_pos))
	return cell if is_within_bounds(cell) else Vector2i(-1, -1)

## ponytail: explicit rectangle, not derived from tile_map.get_used_rect() --
## upgrade to per-cell get_cell_source_id(cell) != -1 checks if a
## non-rectangular playable board is ever needed.
func is_within_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y

func is_free(cell: Vector2i) -> bool:
	return is_within_bounds(cell) and not _occupancy.has(cell)

func occupy(cell: Vector2i, occupant) -> void:
	if not is_within_bounds(cell):
		push_error("GridSystem.occupy: out of bounds %s" % cell)
		return
	_occupancy[cell] = occupant

func clear(cell: Vector2i) -> void:
	_occupancy.erase(cell)
