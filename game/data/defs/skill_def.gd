class_name SkillDef
extends Resource
## A fighter's special move. `kind` is read by the combat sim: strike | sweep | heal | drain.

@export var name := ""
@export var kind := ""
@export var power := 1.0
@export_multiline var description := ""
