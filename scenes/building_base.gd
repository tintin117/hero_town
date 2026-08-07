class_name BuildingBase
extends Node3D

signal clicked

const REFERENCE_SPRITE_WIDTH := 3242.0

@export var building_id: String = ""
var is_dragging: bool = false
var current_level: int = 1

@onready var grid_system: GridSystem = get_node("../GridSystem")

func is_overlapping() -> bool:
	return $Area3D.get_overlapping_areas().size() > 1

func get_data() -> BuildingData:
	return GameData.BUILDINGS[building_id]

func upgrade() -> void:
	current_level += 1

func _ready() -> void:
	$Area3D.input_event.connect(_on_area_input_event)
	if building_id == "":
		return
	var tex := get_data().sprite_texture
	if tex != null:
		$Sprite3D.texture = tex
		$Sprite3D.scale *= REFERENCE_SPRITE_WIDTH / tex.get_width()
	add_to_group("buildings")
	_register_on_grid()

func _register_on_grid() -> void:
	var cell := grid_system.world_to_grid(global_position)
	if cell == Vector2i(-1, -1):
		return
	grid_system.occupy(cell.x, cell.y, self)

func _on_area_input_event(_camera, _event, _event_pos, _normal, _shape_idx):
	if _event is InputEventMouseButton and _event.button_index == MOUSE_BUTTON_LEFT and _event.pressed:
		clicked.emit()
		is_dragging = true

func _process(delta: float) -> void:
	if is_dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging = false
		else:
			print(is_dragging)
