extends RefCounted
## SaveStore round-trip, backup/corrupt fallback, validation, and Game.save/continue_game/new_game.

const Kit := preload("res://game/tests/core_kit.gd")
const PATH := Kit.SAVE_DIR + "/store_save.json"


func run() -> Array[String]:
	var p: Array[String] = []
	var t := Kit.tuning()
	var n := Kit.catalog().heroes.size()
	Kit.clear_save_files(PATH)
	Kit.check(p, SaveStore.load_state(t, n, PATH).is_empty(), "missing file loads nothing")

	var state := _sample(t)
	Kit.check(p, SaveStore.save(state, PATH) == OK, "first save")
	var loaded := SaveStore.load_state(t, n, PATH)
	Kit.check(p, not loaded.is_empty() and not loaded.recovered, "load primary")
	Kit.check(p, _same(loaded.state, state), "round trip keeps every field")
	Kit.check(p, not FileAccess.file_exists(PATH + ".bak") and not FileAccess.file_exists(PATH + ".tmp"), "no backup or temp after first save")

	var second := _sample(t)
	second.gold += 1
	Kit.check(p, SaveStore.save(second, PATH) == OK and FileAccess.file_exists(PATH + ".bak"), "second save keeps a backup")
	Kit.check(p, _same(SaveStore.load_state(t, n, PATH).state, second), "primary holds the newest state")

	# corrupt primary -> backup (the previous good save)
	_write(PATH, "{not json")
	var recovered := SaveStore.load_state(t, n, PATH)
	Kit.check(p, not recovered.is_empty() and recovered.recovered and _same(recovered.state, state), "corrupt primary falls back to backup")
	Kit.check(p, SaveStore.save(second, PATH) == OK and FileAccess.file_exists(PATH + ".corrupt"), "corrupt primary is preserved, then replaced")
	Kit.check(p, _same(SaveStore.load_state(t, n, PATH).state, second), "save after corruption is readable")
	_write(PATH, "garbage")
	_write(PATH + ".bak", "garbage")
	Kit.check(p, SaveStore.load_state(t, n, PATH).is_empty(), "both corrupt loads nothing")

	# version guard and range validation
	var good := {"version": 1, "state": state.to_dict()}
	Kit.check(p, SaveStore.decode(good, t, n) != null, "valid payload decodes")
	Kit.check(p, SaveStore.decode({"version": 2, "state": state.to_dict()}, t, n) == null, "future version rejected")
	Kit.check(p, SaveStore.decode({"state": state.to_dict()}, t, n) == null, "missing version rejected")
	_mutated(p, t, n, "negative gold", func(s: Dictionary) -> void: s.gold = -1)
	_mutated(p, t, n, "hype over max", func(s: Dictionary) -> void: s.hype = 101.0)
	_mutated(p, t, n, "seat tier out of range", func(s: Dictionary) -> void: s.seats_tier = 3)
	_mutated(p, t, n, "fighter tier out of range", func(s: Dictionary) -> void: s.fighter_tier = 4)
	_mutated(p, t, n, "level above cap", func(s: Dictionary) -> void: s.heroes[0].level = 11)
	_mutated(p, t, n, "xp at level threshold", func(s: Dictionary) -> void: s.heroes[0].xp = 90)
	_mutated(p, t, n, "wrong hero count", func(s: Dictionary) -> void: s.heroes.pop_back())
	_mutated(p, t, n, "unowned fighter in lineup", func(s: Dictionary) -> void: s.preferred_lineup = [0, 5])
	_mutated(p, t, n, "duplicate lineup", func(s: Dictionary) -> void: s.preferred_lineup = [0, 0])
	_mutated(p, t, n, "lineup larger than capacity", func(s: Dictionary) -> void: s.fighter_tier = 0)
	_mutated(p, t, n, "threshold at max", func(s: Dictionary) -> void: s.manager.threshold = 100.0)
	_mutated(p, t, n, "non-integer gold", func(s: Dictionary) -> void: s.gold = 1.5)
	_mutated(p, t, n, "missing manager", func(s: Dictionary) -> void: s.erase("manager"))
	Kit.clear_save_files(PATH)

	_game_save(p)
	return p


func _game_save(p: Array[String]) -> void:
	var g := Kit.game()
	Kit.clear_save_files(g.save_path)
	Kit.check(p, not g.continue_game(), "continue without a save fails")
	g.state.gold = 123
	g.state.hype = 42.5
	Kit.check(p, g.save() and FileAccess.file_exists(g.save_path), "Game.save writes the file")
	var g2 := Kit.game()
	g2.save_path = g.save_path
	var log2 := Kit.record(g2.events)
	Kit.check(p, g2.continue_game() and g2.state.gold == 123 and g2.state.hype == 42.5, "continue_game restores state")
	Kit.check(p, log2.has(["gold", 123, 0]) and Kit.count(log2, "roster") == 1, "continue_game announces the new state")
	Kit.check(p, g2.new_game() and g2.state.gold == 0 and g2.state.hype == 15.0 and g2.state.fight_count == 0, "new_game resets")
	g2.autosave = true
	g2.state.gold = 7
	g2.set_manager(true, 60.0)
	var g3 := Kit.game()
	g3.save_path = g.save_path
	Kit.check(p, g3.continue_game() and g3.state.gold == 7 and g3.state.manager.threshold == 60.0, "commands autosave when enabled")
	Kit.clear_save_files(g.save_path)
	for node in [g, g2, g3]:
		Kit.dispose(node)


func _sample(t: Tuning) -> GameState:
	var state := GameState.create(t, Kit.catalog().heroes)
	state.gold = 4321
	state.hype = 61.25
	state.fame_points = 310
	state.seats_tier = 1
	state.fighter_tier = 1
	state.heroes[2].owned = true
	state.heroes[0].level = 4
	state.heroes[0].xp = 12
	state.heroes[0].wins = 9
	state.heroes[0].losses = 2
	state.heroes[0].streak = 3
	state.preferred_lineup = [0, 1, 2] as Array[int]
	state.manager = {"enabled": true, "threshold": 66.5}
	state.fight_count = 11
	state.rng_seed_counter = 11
	return state


func _mutated(p: Array[String], t: Tuning, n: int, label: String, change: Callable) -> void:
	var data := {"version": 1, "state": _sample(t).to_dict()}
	# JSON round trip so numbers arrive as floats, like a real file
	data = JSON.parse_string(JSON.stringify(data))
	change.call(data.state)
	Kit.check(p, SaveStore.decode(data, t, n) == null, "rejects: " + label)


func _same(a: GameState, b: GameState) -> bool:
	return JSON.stringify(a.to_dict(), "", true) == JSON.stringify(b.to_dict(), "", true)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
