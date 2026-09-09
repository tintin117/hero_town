class_name GatheringSettings
extends Resource

@export_enum("wood", "gold", "food") var resource_type := "wood"
@export_range(1, 10000) var yield_amount := 5
@export_range(0.1, 86400.0) var cycle_seconds := 10.0

func is_valid() -> bool:
	return resource_type in ["wood", "gold", "food"] and yield_amount > 0 and is_finite(cycle_seconds) and cycle_seconds > 0.0
