class_name ConquestEncounter
extends Resource

@export var name := "New encounter"
@export_multiline var hint := ""
@export_range(1, 1000) var count := 2
@export_range(0.1, 100000.0) var hp := 22.0
@export_range(0.0, 100000.0) var attack := 3.0
@export_range(0, 10000) var income := 5
@export_range(0, 1000) var plots := 1
