extends Node2D

signal slot_clicked(layer: int, col: int)

var layer_index: int = 0
var col_index: int = 0

@onready var click_area: Area2D = $ClickArea
@onready var label: Label = $Label

func _ready() -> void:
	click_area.input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(layer_index, col_index)
