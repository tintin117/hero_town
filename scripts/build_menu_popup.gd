extends PanelContainer

signal build_requested(building_type: String)
signal popup_hidden

@onready var title_label: Label = $VBox/TitleLabel
@onready var option_list: VBoxContainer = $VBox/OptionList
@onready var close_btn: Button = $VBox/CloseButton

func _ready() -> void:
	close_btn.pressed.connect(hide_popup)
	visible = false

# options: Array of {type, label, cost, can_afford, thumbnail}
func show_options(options: Array) -> void:
	title_label.text = "Choose Building"

	for child in option_list.get_children():
		child.queue_free()

	for opt in options:
		var row := HBoxContainer.new()

		var thumb := TextureRect.new()
		thumb.texture = opt["thumbnail"] if opt["thumbnail"] else preload("res://icon.svg")
		thumb.custom_minimum_size = Vector2(32, 32)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumb)

		var btn := Button.new()
		btn.text = "%s — %d Gold" % [opt["label"], opt["cost"]]
		btn.disabled = not opt["can_afford"]
		if opt["can_afford"]:
			var t: String = opt["type"]
			btn.pressed.connect(func(): _on_option_pressed(t))
		row.add_child(btn)

		option_list.add_child(row)

	visible = true

func hide_popup() -> void:
	visible = false
	popup_hidden.emit()

func _on_option_pressed(building_type: String) -> void:
	build_requested.emit(building_type)
	hide_popup()
