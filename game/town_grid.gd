extends RefCounted
## Integer-cell footprints; the view owns pixels and input.
const SIZE := Vector2i(48, 8)
const CELL_SIZE := Vector2i(48, 24)
const ARENA := Rect2i(16, 0, 16, 8)
const OWNED := Rect2i(10, 0, 28, 8)
const WORLD_WIDTH := 2304
const BUILDINGS := {
	"training": {"name": "Training Yard", "size": Vector2i(3, 2)},
	"infirmary": {"name": "Infirmary", "size": Vector2i(2, 2)},
	"hall": {"name": "Recruitment Hall", "size": Vector2i(3, 2)},
	"tavern": {"name": "Tavern", "size": Vector2i(2, 2)},
}

var buildings: Dictionary = {}


func footprint(id: String, cell: Vector2i) -> Rect2i:
	return Rect2i(cell, BUILDINGS[id].size)


func is_protected(cell: Vector2i) -> bool:
	return ARENA.has_point(cell) or cell.y == 7


func can_place(id: String, cell: Vector2i) -> bool:
	if not BUILDINGS.has(id):
		return false
	var proposed := footprint(id, cell)
	if not OWNED.encloses(proposed):
		return false
	if proposed.intersects(ARENA) or proposed.end.y > 7:
		return false
	for other in buildings:
		if other != id and proposed.intersects(footprint(other, buildings[other].cell)):
			return false
	return true


func try_move(id: String, cell: Vector2i) -> bool:
	if not buildings.has(id) or not can_place(id, cell):
		return false
	# Occupancy changes only after the entire footprint passes validation.
	buildings[id].cell = cell
	return true


func building_at(cell: Vector2i) -> String:
	for id in buildings:
		if footprint(id, buildings[id].cell).has_point(cell):
			return id
	return ""
