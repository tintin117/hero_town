class_name IconButton
extends Button
## Square icon button with optional tooltip; set toggle_mode for on/off buttons (Roster, Build, Stories ...).
## Signals: pressed(), toggled(on). Min size 44x44.

@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		icon = v
@export var tip := "":
	set(v):
		tip = v
		tooltip_text = v


func _init() -> void:
	theme_type_variation = &"IconButton"
	custom_minimum_size = Vector2(44, 44)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_NONE  # mouse-first idle game; keeps the gold focus ring off click


## Sets a toggle button's state without emitting `toggled`.
func set_active(on: bool) -> void:
	set_pressed_no_signal(on)
