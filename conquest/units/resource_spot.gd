class_name ConquestResourceSpot
extends Node2D

signal assignment_requested(spot: ConquestResourceSpot)
@export var spot_id := ""
@export var display_name := "Resource spot"
@export_range(1, 100) var capacity := 1
@export var gathering: GatheringSettings

func _ready() -> void:
	$Hit.tooltip_text = display_name + " · Assign a villager"
	$Hit.pressed.connect(func(): assignment_requested.emit(self))
