extends "res://game/core/game.gd"
## The real Game plus a fake of the G3 building contract (state.buildings-like dict, upgrade, training, hall capacity),
## for UI tests and the build demo until CORE's real one is merged. Not a test itself (runner takes test_*.gd only).
## FakeBuildings.make() replaces CoreKit.game(); dispose it with CoreKit.dispose().

const Kit := preload("res://game/tests/core_kit.gd")


class Level:
	var cost := 0
	var effect := 0.0


class Def:
	var id: StringName
	var display_name := ""
	var description := ""
	var footprint := Vector2i(2, 2)
	var levels: Array[Level] = []


const DEFS := [
	[&"promotion_office", "Promotion Office", "Builds hype faster.", [300, 900, 2500]],
	[&"recruitment_hall", "Recruitment Hall", "Room for more heroes.", [200, 800, 2000]],
	[&"gym", "Gym", "Trains benched fighters.", [400, 1200, 3000]],
	[&"restaurant", "Restaurant", "Fans buy snacks.", [500, 1500, 4000]],
]

var levels := {}  ## building id -> level, missing = unbuilt
var training: Array[int] = []
var capacity := 3  ## hero_capacity()
var upgrades := 0
var fake_sim: RefCounted
var _defs: Array[Def] = []


static func make() -> Node:
	var g: Node = load("res://game/tests/fake_buildings.gd").new()  # same setup as CoreKit.game()
	g.events = Kit.EventsScript.new()
	g.tuning = g.tuning.duplicate()
	g.tuning.series_wins = 1
	g.tuning.series_max_bouts = 1
	g.tuning.series_pause = 0.0
	g.tuning.series_fame_bonus = 0
	g.autosave = false
	g.save_path = Kit.SAVE_DIR + "/game_save.json"
	g.fake_sim = Kit.FakeSim.new()  # a Callable does not keep a RefCounted alive
	g.sim = Callable(g.fake_sim, &"simulate")
	return g


func _init() -> void:
	super._init()
	for row in DEFS:
		var def := Def.new()
		def.id = row[0]
		def.display_name = row[1]
		def.description = row[2]
		for cost: int in row[3]:
			var level := Level.new()
			level.cost = cost
			def.levels.append(level)
		_defs.append(def)


func building_defs() -> Array[Def]:
	return _defs


func building_level(id: StringName) -> int:
	return levels.get(id, 0)


func building_next_cost(id: StringName) -> int:
	var level := building_level(id)
	for def in _defs:
		if def.id == id:
			return -1 if level >= def.levels.size() else def.levels[level].cost
	return -1


func upgrade(id: StringName) -> bool:
	var cost := building_next_cost(id)
	if cost < 0 or not can_afford(cost) or building_level(id) == 0:
		return false
	state.gold -= cost
	levels[id] = building_level(id) + 1
	upgrades += 1
	events.gold_changed.emit(state.gold, -cost)
	events.building_changed.emit(id)
	return true


## What the shell does after a placement.
func build(id: StringName) -> void:
	levels[id] = 1
	events.building_changed.emit(id)


func training_slots() -> int:
	return building_level(&"gym")


func training_heroes() -> Array[int]:
	return training


func assign_training(hero_id: int) -> bool:
	if training.size() >= training_slots() or hero_id in training or not state.heroes[hero_id].owned:
		return false
	training.append(hero_id)
	events.hero_changed.emit(hero_id)
	return true


func recall_training(hero_id: int) -> bool:
	if hero_id not in training:
		return false
	training.erase(hero_id)
	events.hero_changed.emit(hero_id)
	return true


func hero_capacity() -> int:
	return capacity
