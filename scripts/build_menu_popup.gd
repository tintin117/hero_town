extends PanelContainer

signal build_requested(building_type: String)

var _pending_layer: int = -1
var _pending_col: int = -1

@onready var title_label: Label = $VBox/TitleLabel
@onready var option_list: VBoxContainer = $VBox/OptionList
@onready var close_btn: Button = $VBox/CloseButton

func _ready() -> void:
	close_btn.pressed.connect(hide_popup)
	visible = false

# options: Array of {type, label, cost_label, can_afford, unlocked}
func show_options(options: Array, layer: int, col: int) -> void:
	_pending_layer = layer
	_pending_col = col
	title_label.text = "Build at Layer %d, Col %d" % [layer + 1, col + 1]

	for child in option_list.get_children():
		child.queue_free()

	for opt in options:
		var btn := Button.new()
		var suffix := " [Locked]" if not opt["unlocked"] else (" — %s" % opt["cost_label"])
		btn.text = "%s%s" % [opt["label"], suffix]
		btn.disabled = not (opt["unlocked"] and opt["can_afford"])
		if opt["unlocked"] and opt["can_afford"]:
			var t: String = opt["type"]
			btn.pressed.connect(func(): _on_option_pressed(t))
		option_list.add_child(btn)

	visible = true

func hide_popup() -> void:
	visible = false
	_pending_layer = -1
	_pending_col = -1

func _on_option_pressed(building_type: String) -> void:
	build_requested.emit(building_type)
	hide_popup()
