extends Node2D
class_name GridSystem

const GRID_ROWS := 5
const CELL_SIZE := 64.0

@export var grid_cols: int = 12
@export var origin: Vector2 = Vector2(-384.0, -160.0)  ## top-left corner of cell (0,0)

var _occupancy: Array = []
var _highlight: Sprite2D

var hovered_cell: Vector2i = Vector2i(-1, -1)

func _init() -> void:
	_init_occupancy()

func _ready() -> void:
	_build_highlight()

## Translucent square that snaps to the hovered cell during placement.
func _build_highlight() -> void:
	_highlight = Sprite2D.new()
	_highlight.texture = load("res://resources/textures/white.tres")
	var tex_size: Vector2 = _highlight.texture.get_size()
	_highlight.scale = Vector2(CELL_SIZE, CELL_SIZE) / tex_size
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
		_highlight.position = grid_to_world(hovered_cell.x, hovered_cell.y) - global_position

func _init_occupancy() -> void:
	_occupancy.resize(GRID_ROWS)
	for row in GRID_ROWS:
		var cols: Array = []
		cols.resize(grid_cols)
		_occupancy[row] = cols

func grid_to_world(row: int, col: int) -> Vector2:
	return origin + Vector2(col * CELL_SIZE + CELL_SIZE * 0.5, row * CELL_SIZE + CELL_SIZE * 0.5)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local := world_pos - origin
	var col := floori(local.x / CELL_SIZE)
	var row := floori(local.y / CELL_SIZE)
	if not is_within_bounds(row, col):
		return Vector2i(-1, -1)
	return Vector2i(row, col)

func is_within_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < GRID_ROWS and col >= 0 and col < grid_cols

func is_free(row: int, col: int) -> bool:
	if not is_within_bounds(row, col):
		return false
	return _occupancy[row][col] == null

func occupy(row: int, col: int, occupant) -> void:
	if not is_within_bounds(row, col):
		push_error("GridSystem.occupy: out of bounds row=%d col=%d" % [row, col])
		return
	_occupancy[row][col] = occupant

func clear(row: int, col: int) -> void:
	_occupancy[row][col] = null
