extends CanvasLayer


@onready var building_popup = $BuildingPopup

func _ready() -> void:
	$"../BuildingBase".clicked.connect(_on_building_clicked)

func _on_building_clicked() -> void:
	building_popup.open()
