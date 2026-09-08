extends Node

var town: Node2D
var started: int
var duration: float = 1800.0
var next_log: float = 60.0
var rounds: int = 0
var frames: Array[float] = []
var maximum_nodes: int = 0
var maximum_memory: int = 0
var initial_memory: int = 0
var failed: bool = false

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="): duration = float(arg.trim_prefix("--duration="))
	GameState.persistence_enabled = false
	GameState.cleared_stage = 20
	GameState.settings.reduced_effects = false
	GameState.settings.compact = false
	GameState.settings.volume = 0.0
	GameState.gold = 1000000
	for index in 8:
		var type: String = TownRules.ARMY_TYPES[index % 4]
		var response: Dictionary = GameState.place_building(type, Vector2i(2 + index / 3, index % 3))
		assert(response.ok)
		var record := GameState.get_building(response.id)
		for node: ResearchNodeData in GameData.research_for(GameData.BUILDINGS[type]): record.research[node.id] = node.cost
	town = preload("res://scenes/town_2d.tscn").instantiate()
	get_tree().root.add_child.call_deferred(town)
	await get_tree().process_frame
	get_tree().current_scene = town
	town.director.battle_started.connect(_fill_enemies)
	town.director.battle_finished.connect(func(_result): rounds += 1)
	started = Time.get_ticks_msec()
	initial_memory = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	print("ENDURANCE START: %.0fs wall clock; 48 soldiers, 20 enemies; full town nodes/effects" % duration)
	town.director.start_now()

func _fill_enemies() -> void:
	var sim: BattleSimulation = town.director.simulation
	while sim.alive_count(1) < 20:
		sim.spawn_enemy({"unit": "archer" if sim.units.size() % 3 == 0 else "warrior", "hp": 5000.0, "damage": 65.0, "ability": "cleave"}, Vector2(350 + sim.units.size() % 4 * 45, -70 + sim.units.size() % 5 * 32))
	town._combat_events(sim.events)
	if sim.alive_count(0) != 48 or sim.alive_count(1) != 20:
		failed = true
		push_error("Endurance population mismatch")

func _process(delta: float) -> void:
	if started == 0: return
	frames.append(delta * 1000.0)
	maximum_nodes = maxi(maximum_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	maximum_memory = maxi(maximum_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	if seconds >= next_log:
		print("ENDURANCE %.0fs rounds=%d nodes=%d memory=%.1fMiB" % [seconds, rounds, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		next_log += 60
	if seconds >= duration:
		frames.sort()
		var summary := {"wall_seconds": seconds, "rounds": rounds, "frames": frames.size(), "p95_frame_ms": frames[int(frames.size() * 0.95)], "max_nodes": maximum_nodes, "initial_memory_mib": initial_memory / 1048576.0, "max_memory_mib": maximum_memory / 1048576.0, "final_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "failed": failed}
		print("ENDURANCE COMPLETE ", JSON.stringify(summary))
		var file := FileAccess.open("res://.godot/remaster_endurance_result.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(summary))
		started = 0
		GameState.request_quit(1 if failed else 0)
