extends Control

signal build_requested(building_type: String)
signal popup_hidden

const BuildingItemScene := preload("res://scenes/UI_building_item.tscn")

@onready var title_label: Label = $VBoxContainer/LabelControl/Label
@onready var option_list: GridContainer = $VBoxContainer/SelectionGrid/ScrollContainer/GridContainer
@onready var close_btn: TextureButton = $CloseButton/Close

func _ready() -> void:
	close_btn.pressed.connect(hide_popup)
	visible = false

# options: Array of {type, label, cost, can_afford, thumbnail}
func show_options(options: Array) -> void:
	title_label.text = "Choose Building"

	for child in option_list.get_children():
		child.queue_free()

	for opt in options:
		var row := BuildingItemScene.instantiate() as BuildingItem
		option_list.add_child(row)
		row.setup(opt["thumbnail"], opt["label"], opt["cost"], opt["can_afford"])
		if opt["can_afford"]:
			var t: String = opt["type"]
			row.pressed.connect(func(): _on_option_pressed(t))

	visible = true

func hide_popup() -> void:
	visible = false
	popup_hidden.emit()

func _on_option_pressed(building_type: String) -> void:
	sfx.play("click")
	build_requested.emit(building_type)
	hide_popup()
