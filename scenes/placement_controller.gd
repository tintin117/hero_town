extends Node3D

const BuildingScene = preload("res://scenes/building_base.tscn")

const PREBUILT_BUILDINGS := [
	{"id": "town_hall", "cell": Vector2i(1, 0)},
	{"id": "shrine", "cell": Vector2i(1, 2)},
]

@onready var grid_system: GridSystem = get_node("../GridSystem")
@onready var canvas_layer = get_node("../CanvasLayer")

var camera: Camera3D
var placement_mode: bool = false
var ghost: Node3D = null
var selected_building: BuildingData = null
var move_target: BuildingBase = null
var move_origin_cell: Vector2i
var _last_hovered: Vector2i = Vector2i(-100, -100)

func _ready() -> void:
	get_viewport().physics_object_picking = true
	camera = get_viewport().get_camera_3d()
	for entry in PREBUILT_BUILDINGS:
		_spawn_building(entry.id, entry.cell)
	# Portal sits on the rightmost column so spawned enemies walk left toward the city.
	_spawn_building("portal", Vector2i(1, grid_system.grid_cols - 1))

func _spawn_building(building_id: String, cell: Vector2i) -> BuildingBase:
	var building := BuildingScene.instantiate()
	building.building_id = building_id
	building.position = grid_system.grid_to_world(cell.x, cell.y)
	get_parent().add_child.call_deferred(building)
	canvas_layer.connect_building(building)
	return building

func start_placement(data: BuildingData) -> void:
	if placement_mode:
		_cancel_placement()
	selected_building = data
	placement_mode = true
	_last_hovered = Vector2i(-100, -100)
	ghost = BuildingScene.instantiate()
	get_parent().add_child(ghost)
	ghost.get_node("Area3D").monitoring = false
	ghost.get_node("Area3D").monitorable = false

func start_move(building: BuildingBase) -> void:
	if placement_mode:
		_cancel_placement()
	move_target = building
	move_origin_cell = building.current_cell
	grid_system.clear(move_origin_cell.x, move_origin_cell.y)
	placement_mode = true
	_last_hovered = Vector2i(-100, -100)
	ghost = building
	ghost.get_node("Area3D").monitoring = false
	ghost.get_node("Area3D").monitorable = false

func _cancel_placement() -> void:
	placement_mode = false
	selected_building = null
	if move_target != null:
		move_target.position = grid_system.grid_to_world(move_origin_cell.x, move_origin_cell.y)
		grid_system.occupy(move_origin_cell.x, move_origin_cell.y, move_target)
		move_target.get_node("Area3D").monitoring = true
		move_target.get_node("Area3D").monitorable = true
		move_target = null
		ghost = null
	elif ghost != null:
		ghost.queue_free()
		ghost = null

func _process(_delta: float) -> void:
	if not placement_mode or ghost == null:
		return
	var cell := grid_system.hovered_cell
	if cell == _last_hovered or cell == Vector2i(-1, -1):
		return
	_last_hovered = cell
	ghost.position = grid_system.grid_to_world(cell.x, cell.y)

func _unhandled_input(event: InputEvent) -> void:
	if not placement_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_placement()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var cell := grid_system.hovered_cell
	if cell == Vector2i(-1, -1) or not grid_system.is_free(cell.x, cell.y):
		return
	if move_target != null:
		move_target.position = grid_system.grid_to_world(cell.x, cell.y)
		move_target.current_cell = cell
		grid_system.occupy(cell.x, cell.y, move_target)
		move_target.suppress_next_click = true
		move_target.get_node("Area3D").monitoring = true
		move_target.get_node("Area3D").monitorable = true
		move_target = null
		ghost = null
		placement_mode = false
		return
	if not GameState.can_afford(selected_building.build_cost):
		return
	GameState.spend(selected_building.build_cost)
	_spawn_building(selected_building.id, cell)
	_cancel_placement()
