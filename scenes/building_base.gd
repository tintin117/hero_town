class_name BuildingBase
extends Node3D

signal clicked
signal auto_spawn_requested(enemy_id: String, building: BuildingBase)

@export var building_id: String = ""
var is_ghost: bool = false
var current_level: int = 1
var current_cell: Vector2i = Vector2i(-1, -1)
var suppress_next_click: bool = false

var auto_spawn_enemy_ids: Array[String] = []
var active_enemy_count: int = 0
var _spawn_timer: Timer
var _next_spawn_index: int = 0

var model: Node3D = null
var _ghost_materials: Array[StandardMaterial3D] = []

@onready var grid_system: GridSystem = get_node("../GridSystem")

func get_data() -> BuildingData:
	return GameData.BUILDINGS[building_id]

func upgrade() -> void:
	current_level += 1
	if not auto_spawn_enemy_ids.is_empty():
		_start_spawning(get_data().levels[current_level - 1]["spawn_interval"])
	if model != null:
		var tween := create_tween()
		tween.tween_property(model, "scale", model.scale * 1.15, 0.12)
		tween.tween_property(model, "scale", model.scale, 0.18).set_trans(Tween.TRANS_BACK)

## Toggles whether `enemy_id` is one of the types this building auto-spawns.
## The single shared timer round-robins between every toggled-on type.
func toggle_auto_spawn(enemy_id: String) -> void:
	if auto_spawn_enemy_ids.has(enemy_id):
		auto_spawn_enemy_ids.erase(enemy_id)
	else:
		auto_spawn_enemy_ids.append(enemy_id)
	if auto_spawn_enemy_ids.is_empty():
		_spawn_timer.stop()
	else:
		_start_spawning(get_data().levels[current_level - 1]["spawn_interval"])

## Timer.start() waits a full interval before its first tick -- spawn one now, timer covers the repeats.
func _start_spawning(interval: float) -> void:
	_spawn_timer.start(interval)
	_on_spawn_timer_timeout()

func _on_spawn_timer_timeout() -> void:
	var active_slots: int = get_data().levels[current_level - 1].get("active_slots", 1)
	if active_enemy_count >= active_slots or auto_spawn_enemy_ids.is_empty():
		return
	_next_spawn_index %= auto_spawn_enemy_ids.size()
	var enemy_id: String = auto_spawn_enemy_ids[_next_spawn_index]
	_next_spawn_index += 1
	active_enemy_count += 1
	auto_spawn_requested.emit(enemy_id, self)

func on_enemy_defeated() -> void:
	active_enemy_count = maxi(0, active_enemy_count - 1)

func _ready() -> void:
	if building_id == "":
		return
	_build_model()
	if is_ghost:
		_make_ghost_materials()
		return
	$Area3D.input_event.connect(_on_area_input_event)
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	add_to_group("buildings")
	_register_on_grid()
	_play_spawn_pop()

func _build_model() -> void:
	var scene := get_data().model_scene
	if scene == null:
		return
	model = scene.instantiate()
	add_child(model)
	_fit_collision_to_model()

## Merged AABB of the model's meshes drives the click collider.
func _fit_collision_to_model() -> void:
	var aabb := AABB()
	var inv := global_transform.affine_inverse()
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = inv * mesh_instance.global_transform
		var mesh_aabb: AABB = local * mesh_instance.mesh.get_aabb()
		aabb = mesh_aabb if aabb.size == Vector3.ZERO else aabb.merge(mesh_aabb)
	if aabb.size == Vector3.ZERO:
		return
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	$Area3D/CollisionShape3D.shape = shape
	$Area3D/CollisionShape3D.position = aabb.get_center()

## Ghost preview: duplicate every mesh material as semi-transparent so the
## placement controller can tint them green/red without touching shared assets.
func _make_ghost_materials() -> void:
	_ghost_materials.clear()
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.55)
		mesh_instance.material_override = mat
		_ghost_materials.append(mat)

func set_ghost_valid(valid: bool) -> void:
	var tint := Color(0.55, 1.0, 0.6, 0.55) if valid else Color(1.0, 0.4, 0.35, 0.55)
	for mat in _ghost_materials:
		mat.albedo_color = tint

func _play_spawn_pop() -> void:
	if model == null:
		return
	var final_scale := model.scale
	model.scale = final_scale * 0.7
	var tween := create_tween()
	tween.tween_property(model, "scale", final_scale, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _register_on_grid() -> void:
	var cell := grid_system.world_to_grid(global_position)
	if cell == Vector2i(-1, -1):
		return
	current_cell = cell
	grid_system.occupy(cell.x, cell.y, self)

func _on_area_input_event(_camera, _event, _event_pos, _normal, _shape_idx):
	if _event is InputEventMouseButton and _event.button_index == MOUSE_BUTTON_LEFT and _event.pressed:
		# ponytail: the click that confirms a move re-enables this Area3D's
		# monitoring before physics picking processes that same click, which
		# would otherwise re-fire `clicked` and reopen the popup.
		if suppress_next_click:
			suppress_next_click = false
			return
		clicked.emit()
