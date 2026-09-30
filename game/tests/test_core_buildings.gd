extends RefCounted
## Buildings: content, placement rules, commands, wired effects (hype tau, recruit cap, concessions),
## save round trip and validation, and old saves without the new keys.

const Kit := preload("res://game/tests/core_kit.gd")
const PATH := Kit.SAVE_DIR + "/buildings_save.json"
const STEP := 0.25


func run() -> Array[String]:
	var p: Array[String] = []
	_content(p)
	_placement(p)
	_commands(p)
	_effects(p)
	_saves(p)
	return p


func _content(p: Array[String]) -> void:
	var catalog := Kit.catalog()
	var expected := {&"promotion_office": [Vector2i(2, 2), [300, 50000, 2000000], [0.85, 0.70, 0.55]],
		&"recruitment_hall": [Vector2i(3, 2), [200, 350, 900000], [5.0, 6.0, 8.0]],
		&"gym": [Vector2i(3, 2), [250, 150000, 1000000], [1.0, 2.0, 3.0]],
		&"restaurant": [Vector2i(2, 2), [100, 300000, 7000000], [0.3, 0.8, 1.5]]}
	Kit.check(p, catalog.buildings.size() == 4, "four buildings")
	for id: StringName in expected:
		var d := Buildings.def(catalog, id)
		Kit.check(p, d != null and d.footprint == expected[id][0] and d.levels.size() == 3, "%s def" % id)
		for i in 3:
			Kit.check(p, d.levels[i].cost == expected[id][1][i] and Kit.near(d.levels[i].effect, expected[id][2][i]), "%s level %d" % [id, i + 1])
	Kit.check(p, Buildings.def(catalog, &"nope") == null, "unknown def is null")
	Kit.check(p, Buildings.describe(catalog, &"promotion_office", 2) == "Hype builds 30% faster", Buildings.describe(catalog, &"promotion_office", 2))
	Kit.check(p, Buildings.describe(catalog, &"recruitment_hall", 1) == "Up to 5 heroes", "hall text")
	Kit.check(p, Buildings.describe(catalog, &"gym", 2) == "2 training slots" and Buildings.describe(catalog, &"gym", 1) == "1 training slot", "gym text")
	Kit.check(p, Buildings.describe(catalog, &"restaurant", 2) == "+0.8 gold per fan each bout", Buildings.describe(catalog, &"restaurant", 2))
	Kit.check(p, Buildings.describe(catalog, &"gym", 0) == "" and Buildings.describe(catalog, &"gym", 4) == "", "no text outside levels")
	var g := Kit.game()
	Kit.check(p, g.state.buildings.is_empty() and g.state.training.is_empty(), "nothing built at start")
	Kit.check(p, g.hero_capacity() == 3 and g.training_slots() == 0, "neutral effects at start")
	Kit.check(p, g.building_defs().size() == 4 and g.building_level(&"gym") == 0, "queries at start")
	Kit.dispose(g)


func _placement(p: Array[String]) -> void:
	var g := Kit.game()
	var ok := func(id: StringName, x: int, y: int) -> bool: return g.can_place(id, Vector2i(x, y))
	Kit.check(p, ok.call(&"promotion_office", 10, 0) and ok.call(&"promotion_office", 36, 5), "land corners are buildable")
	Kit.check(p, not ok.call(&"promotion_office", 9, 0) and not ok.call(&"promotion_office", 37, 0), "off owned land (left, right)")
	Kit.check(p, not ok.call(&"promotion_office", 10, -1) and not ok.call(&"promotion_office", 10, 6), "row 7 is the public path")
	Kit.check(p, ok.call(&"promotion_office", 14, 3) and not ok.call(&"promotion_office", 15, 3), "arena starts at column 16")
	Kit.check(p, ok.call(&"promotion_office", 32, 3) and not ok.call(&"promotion_office", 31, 3), "arena ends at column 31")
	Kit.check(p, ok.call(&"gym", 11, 0) and not ok.call(&"gym", 14, 0), "3-wide footprint against the arena")
	Kit.check(p, not ok.call(&"nope", 10, 0), "unknown building")
	Kit.check(p, g.building_cell(&"gym") == Vector2i(-1, -1) and g.building_at(Vector2i(10, 0)) == &"", "nothing there yet")

	g.state.gold = 1000
	Kit.check(p, g.build(&"promotion_office", Vector2i(10, 0)), "build office")
	Kit.check(p, g.building_at(Vector2i(10, 0)) == &"promotion_office" and g.building_at(Vector2i(11, 1)) == &"promotion_office", "building_at inside the footprint")
	Kit.check(p, g.building_at(Vector2i(12, 0)) == &"" and g.building_at(Vector2i(10, 2)) == &"", "building_at outside the footprint")
	Kit.check(p, not ok.call(&"gym", 11, 1) and not ok.call(&"gym", 10, 0), "overlap refused")
	Kit.check(p, ok.call(&"gym", 12, 0) and ok.call(&"gym", 10, 2), "touching edges is fine")
	Kit.check(p, ok.call(&"promotion_office", 10, 0) and ok.call(&"promotion_office", 11, 1), "a built one ignores its own rect")
	Kit.check(p, g.build(&"gym", Vector2i(12, 0)), "build gym beside the office")
	Kit.check(p, not g.move_building(&"promotion_office", Vector2i(11, 0)), "move onto the gym refused")
	Kit.check(p, g.move_building(&"promotion_office", Vector2i(10, 4)) and g.building_cell(&"promotion_office") == Vector2i(10, 4), "move to free ground")
	Kit.check(p, g.building_at(Vector2i(10, 0)) == &"" and g.building_at(Vector2i(10, 4)) == &"promotion_office", "old spot freed")
	Kit.check(p, not g.move_building(&"promotion_office", Vector2i(15, 4)) and g.building_cell(&"promotion_office") == Vector2i(10, 4), "move into the arena refused")
	Kit.check(p, not g.move_building(&"restaurant", Vector2i(20, 0)), "cannot move an unbuilt building")
	Kit.dispose(g)


func _commands(p: Array[String]) -> void:
	var g := Kit.game()
	var changed: Array[StringName] = []
	g.events.building_changed.connect(func(id: StringName) -> void: changed.append(id))
	var log := Kit.record(g.events)
	Kit.check(p, g.building_next_cost(&"promotion_office") == 300 and g.building_next_cost(&"nope") == -1, "level-1 cost when unbuilt")
	Kit.check(p, not g.build(&"promotion_office", Vector2i(10, 0)) and g.state.buildings.is_empty(), "cannot afford")
	g.state.gold = 350
	Kit.check(p, not g.build(&"promotion_office", Vector2i(15, 0)) and g.state.gold == 350, "invalid cell costs nothing")
	Kit.check(p, not g.build(&"nope", Vector2i(10, 0)) and not g.upgrade(&"nope") and not g.upgrade(&"gym"), "unknown / unbuilt")
	Kit.check(p, g.build(&"promotion_office", Vector2i(10, 0)), "build office")
	Kit.check(p, g.state.gold == 50 and g.building_level(&"promotion_office") == 1, "paid 300, level 1")
	Kit.check(p, changed == [&"promotion_office"] and Kit.count(log, "gold") == 1, "building_changed and gold announced")
	Kit.check(p, not g.build(&"promotion_office", Vector2i(20, 0)), "unique: no second build")
	Kit.check(p, g.building_next_cost(&"promotion_office") == 50000 and not g.upgrade(&"promotion_office"), "upgrade unaffordable")
	g.state.gold = 50000
	Kit.check(p, g.upgrade(&"promotion_office") and g.building_level(&"promotion_office") == 2 and g.state.gold == 0, "upgrade to 2")
	g.state.gold = 2000000
	Kit.check(p, g.upgrade(&"promotion_office") and g.building_level(&"promotion_office") == 3, "upgrade to 3")
	Kit.check(p, g.building_next_cost(&"promotion_office") == -1 and not g.upgrade(&"promotion_office"), "maxed")
	var gold: int = g.state.gold
	changed.clear()
	Kit.check(p, g.move_building(&"promotion_office", Vector2i(12, 4)) and g.state.gold == gold and changed == [&"promotion_office"], "moving is free")
	changed.clear()
	Kit.check(p, g.move_building(&"promotion_office", Vector2i(12, 4)) and changed.is_empty(), "moving in place is a silent success")
	changed.clear()
	g.new_game()
	Kit.check(p, g.state.buildings.is_empty() and changed.size() == 4, "new_game clears and announces every building")
	Kit.dispose(g)


func _effects(p: Array[String]) -> void:
	# hype tau: the planted, idle clock uses tau * multiplier
	var g := Kit.game(Kit.FakeSim.new())
	g.planted = [0, 1] as Array[int]
	g.state.manager.enabled = false
	g.advance(10.0)
	var plain: float = g.state.hype
	Kit.check(p, Kit.near(plain, Hype.grow(15.0, 10.0, g.tuning)), "no office: plain tau")
	g.state.hype = 15.0
	g.state.buildings["promotion_office"] = {"level": 2, "cell": [10, 0]}
	g.advance(10.0)
	Kit.check(p, Kit.near(g.state.hype, Hype.grow(15.0, 10.0, g.tuning, 0.70)) and g.state.hype > plain, "office level 2: tau x 0.70")
	Kit.dispose(g)

	# recruit cap: 3 with no hall
	g = Kit.game()
	g.state.gold = 100000
	Kit.check(p, g.recruit(2), "third hero fits the baseline cap")
	Kit.check(p, not g.recruit(3) and not g.state.heroes[3].owned and g.state.gold == 99900, "fourth refused without a hall")
	Kit.check(p, g.build(&"recruitment_hall", Vector2i(10, 0)) and g.hero_capacity() == 5, "hall level 1: 5 heroes")
	Kit.check(p, g.recruit(3) and g.recruit(4) and not g.recruit(5), "fills up to 5")
	g.state.gold = 1000000
	Kit.check(p, g.upgrade(&"recruitment_hall") and g.recruit(5) and not g.recruit(6), "hall level 2: 6 heroes")
	Kit.dispose(g)

	# concessions: paid per attendee outside the excitement multiplier
	var fake := Kit.FakeSim.new()
	g = Kit.game(fake)
	var log := Kit.record(g.events)
	g.state.hype = 70.0
	g.state.gold = 100
	Kit.check(p, g.build(&"restaurant", Vector2i(10, 0)) and g.state.gold == 0, "build restaurant")
	Kit.check(p, g.book_fight([0, 1] as Array[int], {"seed": 5}), "book")
	for k in 20:
		g.advance(STEP)
	var result: Dictionary = log.filter(func(e: Array) -> bool: return e[0] == "finished")[0][1]
	Kit.check(p, result.attendance == 73 and result.payout == 91 and result.concessions == 22, "payout 91 plus concessions round(73 x 0.3) = 22 (got %s / %s)" % [result.payout, result.concessions])
	Kit.check(p, g.state.gold == 20 + 91 + 22, "gold: tips + payout + concessions (got %d)" % g.state.gold)
	var deltas := log.filter(func(e: Array) -> bool: return e[0] == "gold").map(func(e: Array) -> int: return e[2])
	Kit.check(p, deltas.back() == 113, "final gold delta covers concessions (%s)" % [deltas])
	Kit.dispose(g)

	var state := GameState.create(Kit.tuning(), Kit.catalog().heroes)
	var out := Economy.settle(state, Kit.tuning(), [0, 1] as Array[int], {"winner": 0, "excitement": 70.0}, 100, 100)
	Kit.check(p, out.concessions == 0 and out.payout == 250 and state.gold == 250, "no restaurant: concessions 0, payout unchanged")
	state.gold = 0
	out = Economy.settle(state, Kit.tuning(), [0, 1] as Array[int], {"winner": 0, "excitement": 70.0}, 100, 100, 1.5)
	Kit.check(p, out.concessions == 150 and out.payout == 250 and state.gold == 400, "1.5 gold per fan, not multiplied by excitement")


func _saves(p: Array[String]) -> void:
	var catalog := Kit.catalog()
	var t := catalog.tuning
	var n := catalog.heroes.size()
	Kit.clear_save_files(PATH)
	var state := GameState.create(t, catalog.heroes)
	state.buildings["gym"] = {"level": 2, "cell": [12, 0]}
	state.buildings["restaurant"] = {"level": 1, "cell": [33, 4]}
	state.training[1] = 12.5
	Kit.check(p, SaveStore.save(state, PATH) == OK, "save")
	var loaded := SaveStore.load_state(t, n, PATH)
	Kit.check(p, not loaded.is_empty(), "load")
	var back: GameState = loaded.state
	Kit.check(p, back.buildings == state.buildings and back.training == {1: 12.5}, "round trip: %s %s" % [back.buildings, back.training])
	Kit.check(p, back.buildings["gym"].cell[0] is int and back.training.keys()[0] is int, "loaded cells and hero ids are ints")
	Kit.clear_save_files(PATH)

	# Game.continue_game restores them
	var g := Kit.game()
	g.state = state
	Kit.check(p, g.save() and g.new_game() and g.state.buildings.is_empty(), "new game wipes")
	Kit.clear_save_files(g.save_path)
	g.state = state
	g.save()
	Kit.check(p, g.continue_game() and g.building_level(&"gym") == 2 and g.building_cell(&"restaurant") == Vector2i(33, 4) and g.training_heroes() == ([1] as Array[int]), "continue_game restores buildings and trainees")
	Kit.clear_save_files(g.save_path)
	Kit.dispose(g)

	# validation
	_rejects(p, t, n, "unknown building", func(s: Dictionary) -> void: s.buildings["castle"] = {"level": 1, "cell": [12, 0]})
	_rejects(p, t, n, "level 0", func(s: Dictionary) -> void: s.buildings.gym.level = 0)
	_rejects(p, t, n, "level 4", func(s: Dictionary) -> void: s.buildings.gym.level = 4)
	_rejects(p, t, n, "fractional level", func(s: Dictionary) -> void: s.buildings.gym.level = 1.5)
	_rejects(p, t, n, "cell off the land", func(s: Dictionary) -> void: s.buildings.gym.cell = [9, 0])
	_rejects(p, t, n, "cell on the path", func(s: Dictionary) -> void: s.buildings.gym.cell = [12, 6])
	_rejects(p, t, n, "cell off the grid", func(s: Dictionary) -> void: s.buildings.gym.cell = [100, 0])
	_rejects(p, t, n, "cell in the arena", func(s: Dictionary) -> void: s.buildings.gym.cell = [15, 0])
	_rejects(p, t, n, "malformed cell", func(s: Dictionary) -> void: s.buildings.gym.cell = [12])
	_rejects(p, t, n, "overlapping buildings", func(s: Dictionary) -> void: s.buildings.restaurant.cell = [13, 1])
	_rejects(p, t, n, "buildings not a dictionary", func(s: Dictionary) -> void: s.buildings = [])
	_rejects(p, t, n, "trainee not owned", func(s: Dictionary) -> void: s.training = {"5": 1.0})
	_rejects(p, t, n, "trainee out of range", func(s: Dictionary) -> void: s.training = {"9": 1.0})
	_rejects(p, t, n, "trainee garbage key", func(s: Dictionary) -> void: s.training = {"bram": 1.0})
	_rejects(p, t, n, "negative progress", func(s: Dictionary) -> void: s.training["1"] = -1.0)
	_rejects(p, t, n, "progress past the interval", func(s: Dictionary) -> void: s.training["1"] = 30.0)
	_rejects(p, t, n, "more trainees than slots", func(s: Dictionary) -> void:
		s.buildings.gym.level = 1
		s.training["0"] = 1.0)

	# old saves without the new keys still load, with defaults
	var old := state.to_dict()
	old.erase("buildings")
	old.erase("training")
	var decoded := SaveStore.decode(JSON.parse_string(JSON.stringify({"version": 1, "state": old})) as Dictionary, t, n)
	Kit.check(p, decoded != null and decoded.buildings.is_empty() and decoded.training.is_empty(), "old save loads with no buildings")
	Kit.check(p, SaveStore.decode({"version": 1, "state": old}, t, n, catalog) != null, "old save loads with an explicit catalog")


func _rejects(p: Array[String], t: Tuning, n: int, label: String, change: Callable) -> void:
	var state := GameState.create(t, Kit.catalog().heroes)
	state.buildings["gym"] = {"level": 2, "cell": [12, 0]}
	state.buildings["restaurant"] = {"level": 1, "cell": [33, 4]}
	state.training[1] = 12.5
	var data: Dictionary = JSON.parse_string(JSON.stringify({"version": 1, "state": state.to_dict()}))
	Kit.check(p, SaveStore.decode(data, t, n) != null, "baseline decodes before: " + label)
	change.call(data.state)
	Kit.check(p, SaveStore.decode(data, t, n) == null, "rejects: " + label)
