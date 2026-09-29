class_name HeroDef
extends Resource
## Authored template of a named fighter. Level scaling is applied by Roster.stats_for.

@export var id := 0
@export var display_name := ""
@export var unit := &""
@export var red := false
@export var health := 0
@export var attack := 0
@export var ranged := false
@export var skill: SkillDef
@export var price := 0
@export var start_owned := false
@export var trait_ids: Array[StringName] = []
