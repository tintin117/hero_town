extends Node3D

const BuildingScene = preload("res://scenes/building_base.tscn")

@onready var grid_system: GridSystem = get_node("../GridSystem")

var camera: Camera3D
var placement_mode: bool = false
var ghost: Node3D = null
var selected_building: BuildingData = null
var _last_hovered: Vector2i = Vector2i(-100, -100)

func _ready() -> void:
	get_viewport().physics_object_picking = true
	camera = get_viewport().get_camera_3d()

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

func _cancel_placement() -> void:
	placement_mode = false
	selected_building = null
	if ghost != null:
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
	if not GameState.can_afford(selected_building.build_cost):
		return
	GameState.spend(selected_building.build_cost)
	var building := BuildingScene.instantiate()
	building.building_id = selected_building.id
	get_parent().add_child(building)
	building.position = grid_system.grid_to_world(cell.x, cell.y)
	grid_system.occupy(cell.x, cell.y, building)
	_cancel_placement()
