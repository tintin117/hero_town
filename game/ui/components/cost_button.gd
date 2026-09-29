class_name CostButton
extends Button
## Button showing [currency icon] cost, plus an optional left-hand label (e.g. the item name).
## Unaffordable = disabled + red-tinted cost. Signal: pressed(). Min size ~ (84, 40).

@export var currency_icon: Texture2D:
	set(v):
		currency_icon = v
		icon = v
@export var cost := 0:
	set(v):
		cost = v
		_refresh()
@export var label := "":
	set(v):
		label = v
		_refresh()
## When true the button is disabled and shows the unaffordable colours.
@export var unaffordable := false:
	set(v):
		unaffordable = v
		disabled = v


func _init() -> void:
	theme_type_variation = &"CostButton"
	custom_minimum_size = Vector2(84, 40)
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_NONE


## Convenience for the caller's gold value: `button.set_gold(state_gold)`.
func set_gold(gold: int) -> void:
	unaffordable = gold < cost


func _refresh() -> void:
	text = (label + "  " if label != "" else "") + StatPill._fmt(cost)
