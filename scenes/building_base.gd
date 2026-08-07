extends Node3D

signal clicked

var building_id: String = ""
var is_dragging: bool = false

func is_overlapping() -> bool:
	return $Area3D.get_overlapping_areas().size() > 1

func _ready() -> void:
	$Area3D.input_event.connect(_on_area_input_event)
	
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
