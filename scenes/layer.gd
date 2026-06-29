extends Node3D

@export var origin_x: float = 0.0
@export var slot_width: float = 4.0
@export var dept_tint: Color = Color.WHITE
@export var z_depth: float = 0.0

var occupied_slots: Dictionary = {}

func slot_to_world_x(slot_id: int) -> float:
	return origin_x + slot_id * slot_width
	

func is_slot_free(start: int, end: int) -> bool:
	for i in range(start, end + 1):
		if occupied_slots.has(i):
			return false
	return true

func place_building(start: int, end: int, building: Node3D) -> bool:
	if not is_slot_free(start, end):
		return false
	for i in range(start, end + 1):
		occupied_slots[i] = building
	building.position = Vector3(slot_to_world_x(start), 0.0, z_depth)
	return true
	
	
func _ready() -> void:
	var test_building = $Sprite3D
	place_building(2, 3, test_building)
