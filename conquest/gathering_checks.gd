extends SceneTree

const Rules = preload("res://conquest/conquest_state.gd")
const SAVE := "user://gathering-check-save.json"

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var g = Rules.new()
	var wood: GatheringSettings = load("res://conquest/data/wood.tres")
	var gold: GatheringSettings = load("res://conquest/data/gold.tres")
	var food: GatheringSettings = load("res://conquest/data/food.tres")
	var spots := [{"id":"wood", "capacity":1, "settings":wood}, {"id":"gold", "capacity":1, "settings":gold}, {"id":"food", "capacity":1, "settings":food}]
	var villagers := [{"id":"a", "initial_spot":"wood"}, {"id":"b", "initial_spot":"gold"}, {"id":"c", "initial_spot":"food"}]
	assert(g.register_gathering(spots, villagers).is_empty())
	assert(g.s.assignments.size() == 3)
	g.advance(g.s.last + 9)
	assert(g.s.wood == 0 and g.s.food == 0)
	var progress: Dictionary = g.s.gathering_progress.duplicate()
	assert(g.assign_villager("a", "wood"))
	assert(g.s.gathering_progress == progress)
	assert(not g.assign_villager("a", "gold"))
	assert(not g.assign_villager("missing", "wood"))
	assert(not g.assign_villager("a", "missing"))
	assert(g.s.assignments.a == "wood" and g.s.gathering_progress == progress)
	g.advance(g.s.last + 26)
	assert(g.s.wood == 15 and g.s.food == 15)
	assert(is_equal_approx(g.s.gold, 200.0 + 35.0 / 6.0 + 15.0))
	assert(is_equal_approx(g.s.gathering_progress.a, 5.0))
	assert(wood.yield_amount == 5 and wood.cycle_seconds == 10.0)
	assert(g.assign_villager("b", ""))
	assert(g.assign_villager("a", "gold"))
	assert(g.s.gathering_progress.a == 0.0 and not g.s.gathering_progress.has("b"))
	assert(g.deploy())
	g.advance(g.s.last + 10)
	assert(g.s.food == 20 and not g.s.battle.is_empty())
	assert(g.save_game(SAVE))
	var loaded = Rules.new()
	loaded.load_game(SAVE)
	assert(loaded.register_gathering(spots, villagers).is_empty())
	assert(loaded.s.assignments == g.s.assignments and loaded.s.gathering_progress == g.s.gathering_progress)
	assert(loaded.s.food == g.s.food and is_equal_approx(loaded.s.gold, g.s.gold))
	# Closing the application preserves progress; it does not accrue resources.
	loaded.s.last -= 600
	assert(loaded.save_game(SAVE))
	var offline = Rules.new()
	offline.load_game(SAVE)
	assert(offline.s.food == loaded.s.food and is_equal_approx(offline.s.gold, loaded.s.gold))
	assert(offline.s.gathering_progress == loaded.s.gathering_progress)
	# Legacy saves initialize the authored roster without touching existing progression.
	var legacy: Dictionary = g.s.duplicate(true)
	for key in ["wood", "food", "assignments", "gathering_progress", "gathering_initialized"]: legacy.erase(key)
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = Rules.new()
	migrated.load_game(SAVE)
	assert(migrated.register_gathering(spots, villagers).is_empty())
	assert(migrated.s.wood == 0 and migrated.s.food == 0 and migrated.s.assignments.size() == 3)
	assert(is_equal_approx(migrated.s.gold, g.s.gold) and migrated.s.battle == JSON.parse_string(JSON.stringify(g.s.battle)))
	# Content reconciliation keeps lower IDs when capacity shrinks.
	migrated.s.assignments = {"c":"wood", "a":"wood", "b":"deleted"}
	migrated.register_gathering(spots, villagers)
	assert(migrated.s.assignments == {"a":"wood"})
	var errors = migrated.register_gathering(spots + [spots[0]], villagers + [villagers[0]])
	assert(errors.size() == 2)
	var invalid := GatheringSettings.new()
	invalid.cycle_seconds = 0
	assert(not migrated.register_gathering([{"id":"bad", "capacity":1, "settings":invalid}], []).is_empty())
	errors = migrated.register_gathering([{"id":"bad", "capacity":1, "settings":invalid}, {"id":"bad", "capacity":1, "settings":wood}], villagers)
	assert(errors.size() == 2 and migrated.spots.is_empty())
	# Battle snapshots from before this refactor keep their original presentation.
	for key in ["duration", "land_name", "enemy_count"]: legacy.battle.erase(key)
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var old_battle = Rules.new()
	old_battle.load_game(SAVE)
	assert(old_battle.s.battle.duration == 14.0 and old_battle.s.battle.enemy_count == 2)
	assert(old_battle.s.battle.land_name == "Sunlit Meadow" and old_battle.s.battle.remaining == legacy.battle.remaining)
	# A fourth encounter and custom balance work without modifying rule code.
	var balance: ConquestBalance = Rules.DEFAULT_BALANCE.duplicate(true)
	balance.encounters.append(balance.encounters[0].duplicate())
	balance.starting_gold = 900
	balance.warrior_hp = 80
	var custom = Rules.new(balance)
	assert(custom.s.gold == 900 and custom.simulate(0).max_hp == 240)
	custom.s.owned = 3
	assert(custom.deploy() and custom.s.owned == 4)
	custom.finish_battle()
	assert(not custom.deploy())
	assert(Rules.DEFAULT_BALANCE.encounters.size() == 3 and Rules.DEFAULT_BALANCE.warrior_hp == 40)
	DirAccess.remove_absolute(SAVE)
	print("GATHERING CHECKS PASSED")
	quit()
