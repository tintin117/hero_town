extends Node3D
class_name GridSystem

signal grid_ready

## Hex board, pointy-top hexes (points along ±Z), odd-r offset layout.
## KayKit hex tiles are 2.0 wide (x) and 2.31 deep (z), so:
const GRID_ROWS := 5
const HEX_RADIUS := 1.1547          # corner radius of one tile
const HEX_X := 2.0                  # x distance between column centers
const HEX_Z := 1.7320508            # z distance between row centers (1.5 * radius)

@export var grid_cols: int = 12
@export var origin: Vector3 = Vector3(-11.5, 0, -3.4641016)  # center of cell (0,0)

var _occupancy: Array = []
var _camera: Camera3D
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D

var hovered_cell: Vector2i = Vector2i(-1, -1)

func _init() -> void:
	_init_occupancy()

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	_build_highlight()
	emit_signal("grid_ready")

## Glowing hex outline that snaps to the hovered cell during placement.
func _build_highlight() -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.top_radius = HEX_RADIUS * 0.98
	mesh.bottom_radius = HEX_RADIUS * 0.98
	mesh.height = 0.06
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.albedo_color = Color(0.4, 1.0, 0.5, 0.45)
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(0.4, 1.0, 0.5)
	_highlight_mat.emission_energy_multiplier = 1.5
	mesh.material = _highlight_mat
	_highlight = MeshInstance3D.new()
	_highlight.mesh = mesh
	# Cylinder's 6 segments put a flat side toward +z; rotate 30° for pointy-top.
	_highlight.rotation.y = PI / 6.0
	_highlight.position.y = 0.05
	_highlight.visible = false
	add_child(_highlight)

func set_overlay(on: bool) -> void:
	_highlight.visible = on

func set_highlight_color(valid: bool) -> void:
	var c := Color(0.4, 1.0, 0.5) if valid else Color(1.0, 0.35, 0.3)
	_highlight_mat.albedo_color = Color(c.r, c.g, c.b, 0.45)
	_highlight_mat.emission = c

## Tracked from motion events rather than polling the OS cursor, so synthetic
## input (tests) and real mice behave identically.
var _mouse_pos := Vector2(-INF, -INF)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position

func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		return
	if _mouse_pos.x == -INF:
		return
	var from := _camera.project_ray_origin(_mouse_pos)
	var dir := _camera.project_ray_normal(_mouse_pos)
	var hit = Plane(Vector3.UP, origin.y).intersects_ray(from, dir)
	hovered_cell = world_to_grid(hit) if hit != null else Vector2i(-1, -1)
	if _highlight.visible and hovered_cell != Vector2i(-1, -1):
		_highlight.position = grid_to_world(hovered_cell.x, hovered_cell.y) - global_position \
				+ Vector3(0, 0.05, 0)

func _init_occupancy() -> void:
	_occupancy.resize(GRID_ROWS)
	for row in GRID_ROWS:
		var cols: Array = []
		cols.resize(grid_cols)
		_occupancy[row] = cols

func grid_to_world(row: int, col: int) -> Vector3:
	return origin + Vector3(col * HEX_X + (row & 1) * HEX_X * 0.5, 0.0, row * HEX_Z)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	# Nearest hex center among the candidate rows around the z estimate.
	var best := Vector2i(-1, -1)
	var best_dist := INF
	var row_guess := roundi((world_pos.z - origin.z) / HEX_Z)
	for row in range(row_guess - 1, row_guess + 2):
		if row < 0 or row >= GRID_ROWS:
			continue
		var col := roundi((world_pos.x - origin.x - (row & 1) * HEX_X * 0.5) / HEX_X)
		if col < 0 or col >= grid_cols:
			continue
		var d := world_pos.distance_to(grid_to_world(row, col))
		if d < best_dist:
			best_dist = d
			best = Vector2i(row, col)
	if best_dist > HEX_RADIUS:
		return Vector2i(-1, -1)
	return best

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
