class_name PropEntry
extends PanelContainer
## One stage prop in the stories drawer's shop: icon, name, effect, how many are owned and a Buy CostButton.
## Dumb view: the drawer pushes state with show_prop() and listens to `buy_requested`.

signal buy_requested(prop_id: StringName)

var prop_id: StringName = &""

@onready var buy: CostButton = %Buy
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _effect: Label = %Effect
@onready var _owned: Label = %Owned


func _ready() -> void:
	buy.pressed.connect(func() -> void: buy_requested.emit(prop_id))


func show_prop(id: StringName, icon: Texture2D, title: String, effect: String, price: int, owned: int, affordable: bool, selected: bool) -> void:
	prop_id = id
	_icon.texture = icon
	_name.text = title + ("  (in use)" if selected else "")
	_effect.text = effect
	tooltip_text = effect
	_owned.text = "x%d" % owned
	_owned.modulate = Color.WHITE if owned > 0 else Color(1, 1, 1, 0.45)
	buy.label = "Buy"
	buy.cost = price
	buy.unaffordable = not affordable
