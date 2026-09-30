class_name PropButton
extends VBoxContainer
## One stage prop in the seed tray: an icon toggle with "x2" (owned) or its price (not owned) underneath.
## Dumb view: `pressed(prop_id)`. An unowned prop is disabled; buying happens in the stories drawer.

signal pressed(prop_id: StringName)

var prop_id: StringName = &""

@onready var button: IconButton = %Button
@onready var _caption: Label = %Caption


func _ready() -> void:
	button.pressed.connect(func() -> void: pressed.emit(prop_id))


func show_prop(id: StringName, icon: Texture2D, tip: String, owned: int, price: int, selected: bool) -> void:
	prop_id = id
	button.icon_texture = icon
	button.tip = tip
	button.disabled = owned <= 0
	button.set_active(selected and owned > 0)
	_caption.text = "x%d" % owned if owned > 0 else StatPill._fmt(price)
	_caption.theme_type_variation = &"" if owned > 0 else &"SmallLabel"
