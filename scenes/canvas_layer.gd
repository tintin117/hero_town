extends CanvasLayer


@onready var building_popup = $BuildingPopup
@onready var placement_controller = $"../PlacementController"

func _ready() -> void:
	$"../BuildingBase".clicked.connect(_on_building_clicked)

func _on_building_clicked() -> void:
	building_popup.open()

func _on_placement_button_pressed() -> void:
	placement_controller.toggle_placement_mode()
