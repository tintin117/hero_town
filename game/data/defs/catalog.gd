class_name Catalog
extends Resource
## Root of authored content; Game loads data/catalog.tres.

@export var tuning: Tuning
@export var heroes: Array[HeroDef] = []
@export var buildings: Array[BuildingDef] = []
@export var traits: Array[TraitDef] = []
@export var props: Array[PropDef] = []
