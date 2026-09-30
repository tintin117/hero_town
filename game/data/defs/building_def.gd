class_name BuildingDef
extends Resource
## Authored template of a unique, three-level building. `effect` of each level is read by Buildings.

@export var id := &""
@export var display_name := ""
@export var description := ""
@export var footprint := Vector2i.ONE  ## cells
@export var levels: Array[BuildingLevel] = []
