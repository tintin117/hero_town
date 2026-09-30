class_name Catalog
extends Resource
## Root of authored content; Game loads data/catalog.tres. Later gates add props, traits.

@export var tuning: Tuning
@export var heroes: Array[HeroDef] = []
@export var buildings: Array[BuildingDef] = []
