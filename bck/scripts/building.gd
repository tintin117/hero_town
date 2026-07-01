extends Node2D

signal clicked(building: Node2D)

var grid_pos: Vector2i = Vector2i.ZERO
var building_type := "house"
var footprint: Vector2i = Vector2i(2, 2)

func _ready() -> void:
	$ClickArea.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if has_meta("is_ghost"):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
