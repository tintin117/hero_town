extends Node

signal currency_changed(gold: int, shard: int)
signal buildings_changed
signal research_changed(instance_id: String)
signal army_improved(instance_id: String)
signal progression_changed
signal settings_changed
signal save_failed(message: String)
signal battle_mode_selected(advance_enabled: bool)

const DEFAULT_SETTINGS := {"volume": 0.55, "always_on_top": true, "reduced_effects": false, "compact": false, "compact_height": 260, "landscape": 0}
var gold: int = 150
var shard: int = 0 # Retired prototype compatibility; the demo uses only gold.
var buildings: Array[Dictionary] = []
var cleared_stage: int = 0
var farm_stage: int = 1
var advancing: bool = true
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var samples: Array[Dictionary] = []
var tutorial: int = 0
var next_building_id: int = 1
var next_round_id: int = 1
var active_round_id: int = 0
var settled_round_id: int = 0
var phase: String = "PREPARE"
var offline_summary: Dictionary = {}
var last_seen: float = 0.0
var persistence_enabled: bool = true
var save_path: String = "user://hero_town_v1.json"
var save_error: String = ""
var _checkpoint: float = 0.0
var quitting: bool = false
var reorganizing: bool = false
var pinned_goal: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(func(): request_quit())
	persistence_enabled = not is_test_session()
	if persistence_enabled:
		load_game()

func _process(delta: float) -> void:
	_checkpoint += delta
	if _checkpoint >= 30.0:
		_checkpoint = 0.0
		save_game()

func request_quit(exit_code: int = 0) -> void:
	if quitting or not save_game(): return
	quitting = true
	for player in get_tree().get_nodes_in_group("remaster_audio"):
		player.stop()
		player.stream = null
	# Give the audio mixer a chance to release its playback references before shutdown.
	get_tree().paused = true
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(exit_code)

func get_building(instance_id: String) -> Dictionary:
	for record in buildings:
		if record.id == instance_id: return record
	return {}

func can_afford(gold_cost: int, shard_cost: int = 0) -> bool:
	return gold_cost >= 0 and shard_cost == 0 and gold >= gold_cost

func spend(gold_cost: int, shard_cost: int = 0) -> bool:
	if not can_afford(gold_cost, shard_cost): return false
	gold -= gold_cost
	currency_changed.emit(gold, 0)
	return true

func add(amount: int, _shards: int = 0) -> void:
	if amount < 0: return
	gold += amount
	currency_changed.emit(gold, 0)

func placement_error(type: String, cell: Vector2i) -> String:
	if not type in TownRules.ARMY_TYPES: return "Choose an army building."
	var data: BuildingData = GameData.BUILDINGS[type]
	if cleared_stage < data.unlock_stage: return "Clear stage %d to unlock this army." % data.unlock_stage
	if buildings.size() >= TownRules.capacity(cleared_stage): return "Army slots full. Defeat the next captain to expand."
	if not cell_free(cell): return "Choose a free town tile."
	if not can_afford(data.build_cost): return "Need %d gold." % data.build_cost
	return ""

func cell_free(cell: Vector2i, except_id: String = "") -> bool:
	if not TownRules.cell_valid(cell): return false
	for record in buildings:
		if record.id != except_id and Vector2i(record.cell[0], record.cell[1]) == cell: return false
	return true

func place_building(type: String, cell: Vector2i) -> Dictionary:
	var error := placement_error(type, cell)
	if not error.is_empty(): return {"ok": false, "message": error}
	var data: BuildingData = GameData.BUILDINGS[type]
	var record := {"id": "army_%03d" % next_building_id, "type": type, "cell": [cell.x, cell.y], "research": {}}
	next_building_id += 1
	gold -= data.build_cost
	buildings.append(record)
	tutorial = maxi(tutorial, 1)
	save_game()
	currency_changed.emit(gold, 0)
	buildings_changed.emit()
	army_improved.emit(record.id)
	return {"ok": true, "id": record.id}

func move_building(instance_id: String, cell: Vector2i) -> Dictionary:
	var record := get_building(instance_id)
	if record.is_empty() or not cell_free(cell, instance_id):
		return {"ok": false, "message": "Choose a free town tile."}
	record.cell = [cell.x, cell.y]
	save_game()
	buildings_changed.emit()
	return {"ok": true}

func research_error(instance_id: String, node_id: String) -> String:
	var record := get_building(instance_id)
	if record.is_empty() or not GameData.RESEARCH.has(node_id): return "Research unavailable."
	var node: ResearchNodeData = GameData.RESEARCH[node_id]
	var data: BuildingData = GameData.BUILDINGS[record.type]
	if record.research.has(node_id): return "Already researched."
	if node.branch == "crew" and node.rank > TownRules.MAX_CREW - data.starting_crew: return "Maximum crew reached."
	if not node.prerequisite.is_empty() and not record.research.has(node.prerequisite): return "Requires %s." % GameData.RESEARCH[node.prerequisite].title
	if cleared_stage < node.required_stage: return "Clear stage %d first." % node.required_stage
	if not can_afford(node.cost): return "Need %d gold." % node.cost
	return ""

func purchase_research(instance_id: String, node_id: String) -> Dictionary:
	var error := research_error(instance_id, node_id)
	if not error.is_empty(): return {"ok": false, "message": error}
	var record := get_building(instance_id)
	var node: ResearchNodeData = GameData.RESEARCH[node_id]
	gold -= node.cost
	record.research[node_id] = node.cost
	if pinned_goal.get("army") == instance_id and pinned_goal.get("node") == node_id: pinned_goal.clear()
	tutorial = maxi(tutorial, 3)
	save_game()
	currency_changed.emit(gold, 0)
	research_changed.emit(instance_id)
	army_improved.emit(instance_id)
	return {"ok": true}

func refund_research(instance_id: String) -> Dictionary:
	if phase != "PREPARE" or not reorganizing: return {"ok": false, "message": "Choose Arrange, then wait for this battle to finish before refunding."}
	var record := get_building(instance_id)
	if record.is_empty(): return {"ok": false, "message": "Army unavailable."}
	var refund := 0
	for cost in record.research.values(): refund += int(cost)
	record.research.clear()
	samples.clear()
	gold += refund
	save_game()
	currency_changed.emit(gold, 0)
	research_changed.emit(instance_id)
	return {"ok": true, "gold": refund}

func begin_battle() -> int:
	active_round_id = next_round_id
	next_round_id += 1
	save_game()
	return active_round_id

func settle_battle(round_id: int, stage_number: int, won: bool, battle_seconds: float) -> Dictionary:
	if not GameData.STAGES.has(stage_number): return {"ok": false, "message": "Unknown stage."}
	if round_id != active_round_id or round_id <= settled_round_id or round_id <= 0:
		return {"ok": false, "message": "Battle already settled."}
	settled_round_id = round_id
	active_round_id = 0
	var reward := 0
	var first_clear := false
	var stage: StageData = GameData.STAGES[stage_number]
	if won:
		first_clear = stage_number > cleared_stage
		reward = stage.gold + (stage.first_clear_gold if first_clear else 0)
		gold += reward
		cleared_stage = maxi(cleared_stage, stage_number)
		tutorial = maxi(tutorial, 2)
		if stage.boss.is_empty():
			samples.append({"gold": stage.gold, "seconds": TownRules.PREP_SECONDS + maxf(0.05, battle_seconds) + TownRules.RESULT_SECONDS})
			while samples.size() > 5: samples.pop_front()
		if advancing or first_clear: farm_stage = TownRules.normal_stage(cleared_stage)
		if cleared_stage >= 20: advancing = false
	else:
		if advancing: farm_stage = TownRules.normal_stage(cleared_stage)
		else: farm_stage = TownRules.normal_stage(farm_stage - 1)
		advancing = false
	save_game()
	currency_changed.emit(gold, 0)
	progression_changed.emit()
	return {"ok": true, "gold": reward, "first_clear": first_clear, "won": won, "stage": stage_number}

func set_advancing(value: bool) -> void:
	advancing = value and cleared_stage < 20
	if not advancing: farm_stage = TownRules.normal_stage(cleared_stage)
	save_game()
	battle_mode_selected.emit(advancing)
	progression_changed.emit()

func select_farm(stage: int) -> void:
	if stage < 1 or stage > cleared_stage or stage % 5 == 0: return
	farm_stage = stage
	advancing = false
	save_game()
	battle_mode_selected.emit(false)
	progression_changed.emit()

func update_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key): return
	if key == "volume": settings[key] = clampf(float(value), 0.0, 1.0)
	elif key == "compact_height": settings[key] = clampi(int(value), 220, 400)
	elif key == "landscape": settings[key] = clampi(int(value), 0, 2)
	else: settings[key] = bool(value)
	save_game()
	settings_changed.emit()

func offline_rate() -> float:
	var total_gold := 0.0
	var total_seconds := 0.0
	for sample in samples:
		total_gold += sample.gold
		total_seconds += sample.seconds
	return 0.5 * total_gold / total_seconds if total_seconds > 0.0 else 0.0

func offline_reward(now: float, timestamp: float) -> Dictionary:
	var seconds := clampf(now - timestamp, 0.0, TownRules.OFFLINE_CAP)
	return {"seconds": seconds, "gold": floori(seconds * offline_rate())}

func serialize(now: float) -> Dictionary:
	return {"version": TownRules.SAVE_VERSION, "gold": gold, "buildings": buildings.duplicate(true),
		"cleared_stage": cleared_stage, "farm_stage": farm_stage, "advancing": advancing,
		"settings": settings.duplicate(), "pinned_goal": pinned_goal.duplicate(), "samples": samples.duplicate(true), "tutorial": tutorial,
		"next_building_id": next_building_id, "next_round_id": next_round_id,
		"settled_round_id": settled_round_id, "last_seen": maxf(last_seen, now)}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("version", 0) != TownRules.SAVE_VERSION: return false
	for key in ["gold", "cleared_stage", "farm_stage", "next_building_id", "next_round_id", "settled_round_id", "tutorial", "last_seen"]:
		if not data.get(key) is float and not data.get(key) is int: return false
	if data.gold < 0 or data.cleared_stage < 0 or data.cleared_stage > 20: return false
	if not data.get("buildings") is Array or data.buildings.size() > TownRules.capacity(int(data.cleared_stage)): return false
	if not data.get("samples") is Array or data.samples.size() > 5 or not data.get("settings") is Dictionary: return false
	if data.farm_stage < 1 or data.farm_stage > maxi(1, int(data.cleared_stage)) or int(data.farm_stage) % 5 == 0: return false
	if data.next_building_id < 1 or data.next_round_id < 1 or data.settled_round_id < 0 or data.last_seen < 0: return false
	for key in DEFAULT_SETTINGS:
		if not data.settings.has(key): continue
		if key in ["volume", "compact_height", "landscape"]:
			if not (data.settings[key] is float or data.settings[key] is int): return false
		elif not data.settings[key] is bool: return false
	var ids := {}
	var cells := {}
	for record in data.buildings:
		if not record is Dictionary or not record.get("id") is String or not record.get("type") in TownRules.ARMY_TYPES: return false
		if not record.get("specialization", "balanced") in ["balanced", "bulwark", "vanguard"]: return false
		if record.type != "barracks" and record.get("specialization", "balanced") != "balanced": return false
		if ids.has(record.id) or not record.get("cell") is Array or record.cell.size() != 2: return false
		if not (record.cell[0] is float or record.cell[0] is int) or not (record.cell[1] is float or record.cell[1] is int): return false
		var cell := Vector2i(record.cell[0], record.cell[1])
		if not TownRules.cell_valid(cell) or cells.has(cell) or not record.get("research") is Dictionary: return false
		ids[record.id] = true
		cells[cell] = true
		var building_data: BuildingData = GameData.BUILDINGS[record.type]
		if int(data.cleared_stage) < building_data.unlock_stage: return false
		if not record.id.begins_with("army_") or not record.id.trim_prefix("army_").is_valid_int(): return false
		if int(record.id.trim_prefix("army_")) >= int(data.next_building_id): return false
		for key in record.research:
			if not GameData.RESEARCH.has(key): return false
			var research: ResearchNodeData = GameData.RESEARCH[key]
			if not (record.research[key] is float or record.research[key] is int) or record.research[key] < 0: return false
			if record.research[key] > research.cost or research.required_stage > int(data.cleared_stage): return false
			if research.branch == "crew" and research.rank > 6 - building_data.starting_crew: return false
			if not research.prerequisite.is_empty() and not record.research.has(research.prerequisite): return false
	for sample in data.samples:
		if not sample is Dictionary or not (sample.get("gold") is float or sample.get("gold") is int) or not (sample.get("seconds") is float or sample.get("seconds") is int): return false
		if sample.gold < 0 or sample.seconds < TownRules.RESULT_SECONDS + 0.05: return false
	return true

func deserialize(data: Dictionary) -> void:
	gold = int(data.gold)
	buildings.assign(data.buildings.duplicate(true))
	cleared_stage = int(data.cleared_stage)
	farm_stage = TownRules.normal_stage(int(data.farm_stage))
	advancing = bool(data.get("advancing", true)) and cleared_stage < 20
	settings = DEFAULT_SETTINGS.duplicate()
	for key in DEFAULT_SETTINGS:
		if data.settings.has(key):
			if key == "volume": settings[key] = clampf(float(data.settings[key]), 0, 1)
			elif key == "compact_height": settings[key] = clampi(int(data.settings[key]), 220, 400)
			elif key == "landscape": settings[key] = clampi(int(data.settings[key]), 0, 2)
			else: settings[key] = bool(data.settings[key])
	samples.assign(data.samples.duplicate(true))
	tutorial = int(data.tutorial)
	next_building_id = maxi(1, int(data.next_building_id))
	next_round_id = maxi(int(data.next_round_id), int(data.settled_round_id) + 1)
	settled_round_id = int(data.settled_round_id)
	active_round_id = 0
	phase = "PREPARE"
	last_seen = float(data.last_seen)
	reorganizing = false
	pinned_goal = {}
	var goal: Variant = data.get("pinned_goal", {})
	if goal is Dictionary and goal.get("army") is String and goal.get("node") is String:
		var record := get_building(goal.army)
		if not record.is_empty() and GameData.RESEARCH.has(goal.node) and not record.research.has(goal.node):
			pinned_goal = {"army": goal.army, "node": goal.node}

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return null
	var data: Variant = parser.data
	return data if valid_save(data) else null

func load_game(now: float = -1.0) -> bool:
	if now < 0: now = Time.get_unix_time_from_system()
	var data: Variant = _read_save(save_path)
	if data == null: data = _read_save(save_path + ".bak")
	if data == null:
		if FileAccess.file_exists(save_path):
			DirAccess.copy_absolute(save_path, save_path + ".unreadable")
		last_seen = now
		return false
	deserialize(data)
	offline_summary = offline_reward(now, last_seen)
	gold += int(offline_summary.gold)
	if not save_game(now):
		gold -= int(offline_summary.gold)
		offline_summary = {}
	return true

func save_game(now: float = -1.0) -> bool:
	if not persistence_enabled: return true
	if now < 0: now = Time.get_unix_time_from_system()
	var absolute := ProjectSettings.globalize_path(save_path)
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: return _save_failure("Could not write the save file.")
	file.store_string(JSON.stringify(serialize(now)))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return _save_failure("Could not finish writing the save file.")
	if _read_save(save_path) != null:
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			return _save_failure("Could not update the save backup.")
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		return _save_failure("Could not replace the save file.")
	last_seen = maxf(last_seen, now)
	save_error = ""
	return true

func _save_failure(message: String) -> bool:
	save_error = message
	save_failed.emit(message)
	push_warning(message)
	return false

func is_test_session() -> bool:
	if OS.get_cmdline_user_args().has("--test"): return true
	for arg in OS.get_cmdline_args():
		var path: String = arg.replace("\\", "/")
		if path.begins_with("res://tests/") and path.ends_with(".tscn"): return true
		# F6 designer previews must bypass this autoload before it reads a save.
		if path.ends_with("/conquest/companion_preview.tscn") or path == "conquest/companion_preview.tscn": return true
	return false

func set_reorganizing(value: bool) -> void:
	reorganizing = value
	progression_changed.emit()

func set_specialization(instance_id: String, choice: String) -> Dictionary:
	var record := get_building(instance_id)
	if record.is_empty() or record.type != "barracks" or not choice in ["balanced", "bulwark", "vanguard"]:
		return {"ok": false, "message": "Choose a Barracks specialization."}
	if record.get("specialization", "balanced") == choice: return {"ok": true}
	record.specialization = choice
	save_game()
	research_changed.emit(instance_id)
	army_improved.emit(instance_id)
	return {"ok": true}

func pin_upgrade(instance_id: String, node_id: String) -> void:
	var record := get_building(instance_id)
	if record.is_empty() or not GameData.RESEARCH.has(node_id) or record.research.has(node_id): return
	pinned_goal = {"army":instance_id, "node":node_id}
	save_game()
	progression_changed.emit()

func objective_text() -> String:
	if not pinned_goal.is_empty():
		var record := get_building(pinned_goal.get("army", ""))
		var node: ResearchNodeData = GameData.RESEARCH.get(pinned_goal.get("node", ""))
		if not record.is_empty() and node != null and not record.research.has(node.id):
			return "%s: %d/%dg" % [node.title, mini(gold,node.cost), node.cost]
	if buildings.is_empty(): return "Build a Barracks · 100g"
	if tutorial < 3: return "Improve your Barracks · 50g"
	if cleared_stage < 2: return "Stage 2 → Rangers"
	if cleared_stage < 4: return "Stage 4 → Clerics"
	if cleared_stage < 5: return "Boss 5 → fourth army plot"
	if buildings.size() < capacity_for_town(): return "Commons open · %d/%d army plots" % [buildings.size(),capacity_for_town()]
	if cleared_stage < 7: return "Stage 7 → Lancers"
	if cleared_stage < 10: return "Boss 10 → six army plots"
	if cleared_stage < 15: return "Boss 15 → eight army plots"
	if cleared_stage < 20: return "Stage 20 → secure the frontier"
	return "Frontier safe · improve your town"

func capacity_for_town() -> int:
	return TownRules.capacity(cleared_stage)
