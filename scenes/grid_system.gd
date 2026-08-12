extends Node3D
class_name GridSystem

signal grid_ready

const GRID_ROWS := 3

@export var grid_cols: int = 10
@export var cell_size: float = 4.0
@export var origin: Vector3 = Vector3(-20, 0, -6)

@export var ground_mesh: MeshInstance3D

var _occupancy: Array = []
var _grid_visual: MeshInstance3D
var _shader_material: ShaderMaterial
var _camera: Camera3D

var hovered_cell: Vector2i = Vector2i(-1, -1)

func _init() -> void:
	_init_occupancy()

func _ready() -> void:
	# Fit to ground first before anything else
	if ground_mesh:
		_fit_to_ground()
		_init_occupancy()
		
	_grid_visual = $GridVisual
	_shader_material = _grid_visual.material_override as ShaderMaterial
	_camera = get_viewport().get_camera_3d()

	var visual_size := Vector2(grid_cols * cell_size, GRID_ROWS * cell_size)
	(_grid_visual.mesh as PlaneMesh).size = visual_size
	_grid_visual.position = origin + Vector3(visual_size.x * 0.5, 0.02, visual_size.y * 0.5)
	_shader_material.set_shader_parameter("grid_size", Vector2(grid_cols, GRID_ROWS))
	emit_signal("grid_ready")

func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)
	var hit = Plane(Vector3.UP, origin.y).intersects_ray(from, dir)

	var cell := Vector2i(-1, -1)
	if hit != null:
		cell = world_to_grid(hit)
	hovered_cell = cell

	# ponytail: UV axis mapping on PlaneMesh isn't verified visually (no
	# screenshots per CLAUDE.md) — if the highlight tracks the wrong cell,
	# swap cell.x/cell.y here or negate one axis in the shader.
	_shader_material.set_shader_parameter("highlight_cell", Vector2(cell.y, cell.x))


func _init_occupancy() -> void:
	_occupancy.resize(GRID_ROWS)
	for row in GRID_ROWS:
		var cols: Array = []
		cols.resize(grid_cols)
		_occupancy[row] = cols


func grid_to_world(row: int, col: int) -> Vector3:
	return origin + Vector3((col + 0.5) * cell_size, 0.0, (row + 0.5) * cell_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var local := world_pos - origin
	var row := floori(local.z / cell_size)
	var col := floori(local.x / cell_size)
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
		push_error("GridSystem.occupy: out of bounds row=%d col=%d (grid=%dx%d)" % [row, col, GRID_ROWS, grid_cols])
		return
	if _occupancy.size() == 0:
		push_error("GridSystem.occupy: _occupancy not initialized yet!")
		return
	_occupancy[row][col] = occupant


func clear(row: int, col: int) -> void:
	_occupancy[row][col] = null
	
	
func _fit_to_ground() -> void:
	var plane_mesh = ground_mesh.mesh as PlaneMesh
	if plane_mesh == null:
		push_error("GridSystem: ground_mesh is not a PlaneMesh!")
		return

	# Account for node scale (in case ground is scaled in editor)
	var mesh_size := Vector2(
		plane_mesh.size.x * ground_mesh.scale.x,
		plane_mesh.size.y * ground_mesh.scale.z  # PlaneMesh Y maps to world Z
	)

	var center := ground_mesh.global_position

	# Corner origin (top-left in world space)
	origin = Vector3(
		center.x - mesh_size.x * 0.5,
		center.y,
		center.z - mesh_size.y * 0.5
	)

	# Cell size driven by rows (so height fits exactly)
	cell_size = mesh_size.y / float(GRID_ROWS)

	# Cols fill the width exactly
	grid_cols = int(round(mesh_size.x / cell_size))

	print("GridSystem fitted → origin: ", origin,
			" | cell_size: ", cell_size,
			" | grid_cols: ", grid_cols)
