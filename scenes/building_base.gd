class_name BuildingBase
extends Node3D

signal clicked
signal auto_spawn_requested(enemy_id: String, building: BuildingBase)

const REFERENCE_SPRITE_WIDTH := 3242.0

@export var building_id: String = ""
var is_dragging: bool = false
var current_level: int = 1
var current_cell: Vector2i = Vector2i(-1, -1)
var suppress_next_click: bool = false

var auto_spawn_enemy_ids: Array[String] = []
var active_enemy_count: int = 0
var _spawn_timer: Timer
var _next_spawn_index: int = 0

@onready var grid_system: GridSystem = get_node("../GridSystem")

func is_overlapping() -> bool:
	return $Area3D.get_overlapping_areas().size() > 1

func get_data() -> BuildingData:
	return GameData.BUILDINGS[building_id]

func upgrade() -> void:
	current_level += 1
	if not auto_spawn_enemy_ids.is_empty():
		_start_spawning(get_data().levels[current_level - 1]["spawn_interval"])

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
	$Area3D.input_event.connect(_on_area_input_event)
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	if building_id == "":
		return
	var tex := get_data().sprite_texture
	if tex != null:
		$Sprite3D.texture = tex
		$Sprite3D.scale *= REFERENCE_SPRITE_WIDTH / tex.get_width()
		_fit_collision_to_sprite(tex)
	add_to_group("buildings")
	_register_on_grid()

func _fit_collision_to_sprite(tex: Texture2D) -> void:
	# ponytail: box collider sized/offset to match the billboard sprite's
	# world bounds per-building (was a fixed 1x1x0.5 box shared across every
	# building, so most of the visible sprite had no collider at all).
	var world_size: Vector2 = Vector2(tex.get_width(), tex.get_height()) * $Sprite3D.pixel_size * $Sprite3D.scale.x
	var shape := BoxShape3D.new()
	shape.size = Vector3(world_size.x, world_size.y, 1.0)
	$Area3D/CollisionShape3D.shape = shape
	$Area3D/CollisionShape3D.position = Vector3(0, $Sprite3D.position.y, 0)

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
		is_dragging = true

func _process(delta: float) -> void:
	if is_dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging = false
		else:
			print(is_dragging)
