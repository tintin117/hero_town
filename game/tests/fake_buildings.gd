extends RefCounted
## Test helpers on top of the real Game (core_kit): put buildings at chosen levels and set the hall capacity
## without paying or placing. Not a test itself (the runner takes test_*.gd only). Dispose with CoreKit.dispose().

const Kit := preload("res://game/tests/core_kit.gd")
const CELLS := {&"promotion_office": [10, 0], &"recruitment_hall": [12, 0],
		&"gym": [10, 3], &"restaurant": [14, 3]}


static func make() -> Node:
	var fake := Kit.FakeSim.new()
	var g: Node = Kit.game(fake)
	g.set_meta("fake_sim", fake)  # a Callable does not keep a RefCounted alive
	return g


## level 0 removes the building.
static func set_level(g: Node, id: StringName, level: int) -> void:
	if level <= 0:
		g.state.buildings.erase(String(id))
	else:
		g.state.buildings[String(id)] = {"level": level, "cell": CELLS[id]}
	g.events.building_changed.emit(id)


## Hall capacity is 3 without a hall; any larger number builds a level-1 hall (5).
static func set_capacity(g: Node, capacity: int) -> void:
	set_level(g, &"recruitment_hall", 0 if capacity <= 3 else 1)
	g.events.roster_changed.emit()
