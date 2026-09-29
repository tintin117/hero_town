extends RefCounted
## Shared helpers for test_core_* / test_hype_*. Not a test itself (runner only takes test_*.gd).
## Game and Events autoloads do not exist under --script, so tests build their own instances.

const GameScript := preload("res://game/core/game.gd")
const EventsScript := preload("res://game/core/events.gd")
const SAVE_DIR := "res://.godot/test_core"


class FakeSim extends RefCounted:
	## Returns a fixed 5 s fight: two skills (at 2 s and 4 s), winner hero 0, final excitement 45.
	var calls := 0
	var last_lineup: Array = []
	var last_seed := -1
	var last_mods: Variant = "unset"
	var duration := 5.0
	var excitement := 45.0
	var winner := 0

	func simulate(lineup: Array, rng_seed: int, mods: Variant) -> Dictionary:
		calls += 1
		last_lineup = lineup
		last_seed = rng_seed
		last_mods = mods
		var list: Array[Dictionary] = [
			{"t": 0.5, "kind": &"move"}, {"t": 1.0, "kind": &"attack"},
			{"t": 2.0, "kind": &"skill", "tip": 10}, {"t": 3.0, "kind": &"attack"},
			{"t": 4.0, "kind": &"skill", "tip": 10}, {"t": duration, "kind": &"attack"},
		]
		return {"events": list, "result": {"winner": winner, "duration": duration, "excitement": excitement,
			"tips": 20, "skills": 2, "attacks": 3, "hp_left": {0: 100, 1: 0}, "tracks": {}}}


static func catalog() -> Catalog:
	return load("res://game/data/catalog.tres")


static func tuning() -> Tuning:
	return catalog().tuning


## A Game wired to a fresh Events instance and a fake sim; never touches the player's save.
static func game(fake: FakeSim = null) -> Node:
	var g: Node = GameScript.new()
	g.events = EventsScript.new()
	g.autosave = false
	g.save_path = SAVE_DIR + "/game_save.json"
	if fake != null:
		g.sim = Callable(fake, &"simulate")
	return g


static func dispose(g: Node) -> void:
	g.events.free()
	g.free()


## Collects [signal_name, args...] entries for the signals tests care about.
static func record(events: Node) -> Array:
	var log: Array = []
	events.gold_changed.connect(func(gold: int, delta: int) -> void: log.append(["gold", gold, delta]))
	events.hype_changed.connect(func(hype: float) -> void: log.append(["hype", hype]))
	events.fame_changed.connect(func(points: int, tier: int) -> void: log.append(["fame", points, tier]))
	events.fight_booked.connect(func(lineup: Array[int], main_event: StringName) -> void: log.append(["booked", lineup, main_event]))
	events.fight_started.connect(func(info: Dictionary) -> void: log.append(["started", info]))
	events.combat_event.connect(func(event: Dictionary) -> void: log.append(["combat", event]))
	events.fight_finished.connect(func(result: Dictionary) -> void: log.append(["finished", result]))
	events.roster_changed.connect(func() -> void: log.append(["roster"]))
	events.hero_changed.connect(func(id: int) -> void: log.append(["hero", id]))
	events.manager_changed.connect(func() -> void: log.append(["manager"]))
	events.toast.connect(func(text: String, icon: StringName) -> void: log.append(["toast", text, icon]))
	events.paused_changed.connect(func(paused: bool) -> void: log.append(["paused", paused]))
	return log


static func count(log: Array, name: String) -> int:
	return log.filter(func(entry: Array) -> bool: return entry[0] == name).size()


static func check(problems: Array[String], condition: bool, message: String) -> void:
	if not condition:
		problems.append(message)


static func near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps


static func ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


static func clear_save_files(path: String) -> void:
	ensure_save_dir()
	for suffix in ["", ".tmp", ".bak", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
