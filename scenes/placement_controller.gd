extends Node3D

const BuildingScene = preload("res://scenes/building_base.tscn")

const PREBUILT_BUILDINGS := [
	{"id": "town_hall", "cell": Vector2i(2, 1)},
	{"id": "shrine", "cell": Vector2i(2, 3)},
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
var _snap_tween: Tween

func _ready() -> void:
	get_viewport().physics_object_picking = true
	camera = get_viewport().get_camera_3d()
	await grid_system.grid_ready
	for entry in PREBUILT_BUILDINGS:
		_spawn_building(entry.id, entry.cell)
	# Portal sits on the rightmost column so spawned enemies walk left toward the city.
	_spawn_building("portal", Vector2i(2, grid_system.grid_cols - 2))

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
	ghost.is_ghost = true
	ghost.building_id = data.id
	get_parent().add_child(ghost)
	ghost.get_node("Area3D").monitoring = false
	ghost.get_node("Area3D").monitorable = false
	grid_system.set_overlay(true)

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
	grid_system.set_overlay(true)

func _cancel_placement() -> void:
	placement_mode = false
	selected_building = null
	grid_system.set_overlay(false)
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
	var valid := grid_system.is_free(cell.x, cell.y) \
			and (move_target != null or GameState.can_afford(selected_building.build_cost))
	grid_system.set_highlight_color(valid)
	if ghost is BuildingBase and ghost.is_ghost:
		ghost.set_ghost_valid(valid)
	if _snap_tween != null:
		_snap_tween.kill()
	_snap_tween = create_tween()
	_snap_tween.tween_property(ghost, "position", grid_system.grid_to_world(cell.x, cell.y), 0.08)

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
		_reject("Occupied!")
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
		grid_system.set_overlay(false)
		_confirm_fx(cell)
		return
	if not GameState.can_afford(selected_building.build_cost):
		_reject("Need %dg" % selected_building.build_cost)
		return
	GameState.spend(selected_building.build_cost)
	_spawn_building(selected_building.id, cell)
	_confirm_fx(cell)
	_cancel_placement()

func _confirm_fx(cell: Vector2i) -> void:
	var world_pos := grid_system.grid_to_world(cell.x, cell.y)
	if camera != null:
		fx.spawn("smoke_pop", camera.unproject_position(world_pos))
	fx.shake(0.08, 0.1)
	sfx.play("place")

func _reject(message: String) -> void:
	sfx.play("error")
	fx.popup(message, get_viewport().get_mouse_position(), {"color": Color(1.0, 0.4, 0.35)})
	if ghost == null:
		return
	var origin_pos: Vector3 = ghost.position
	if _snap_tween != null:
		_snap_tween.kill()
	_snap_tween = create_tween()
	for offset in [0.12, -0.1, 0.06, 0.0]:
		_snap_tween.tween_property(ghost, "position:x", origin_pos.x + offset, 0.05)
