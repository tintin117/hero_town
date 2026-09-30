class_name PropDef
extends Resource
## Authored consumable arena prop. `value` is the one number it delivers (meaning per id, see Props);
## the price scales with the arena's seats.

@export var id := &""
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := &""  ## file stem in resources/ui/icons/
@export var base_price := 0  ## gold at Tuning.prop_price_seats seats
@export var value := 0.0
