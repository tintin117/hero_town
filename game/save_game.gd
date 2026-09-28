extends RefCounted
## Persist only durable progress. Combat is deliberately restarted after loading.
const Rules := preload("res://game/fight.gd")
const DEFAULT_PATH := "user://arena_tycoon_v1.json"


static func snapshot(fight: RefCounted, selected: Array[int]) -> Dictionary:
	var heroes: Array = []
	for id in range(fight.heroes.size()):
		var hero: Dictionary = fight.heroes[id]
		heroes.append({"owned": hero.owned, "level": hero.level, "xp": hero.xp,
			"wins": hero.wins, "stamina": hero.stamina, "rest": fight.rest_remaining[id]})
	var cells := {}
	for id in fight.grid.buildings:
		var cell: Vector2i = fight.grid.buildings[id].cell
		cells[id] = [cell.x, cell.y]
	return {"version": 1, "gold": fight.coins, "completed": fight.completed,
		"seats": fight.arena_tier, "fighters": fight.fighter_tier,
		"auto_owned": fight.auto_fill_owned, "auto_enabled": fight.auto_fill_enabled,
		"intro_seen": fight.intro_seen,
		"buildings": fight.building_levels.duplicate(), "cells": cells, "heroes": heroes,
		"selected": selected.duplicate()}


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= low and value <= high


static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1:
		return {}
	for key in ["gold", "completed", "seats", "fighters"]:
		if not _integer(data.get(key), 0, 2 if key in ["seats", "fighters"] else 1000000000000000):
			return {}
	if not data.get("auto_owned") is bool or not data.get("auto_enabled") is bool or (data.auto_enabled and not data.auto_owned):
		return {}
	if data.has("intro_seen") and not data.intro_seen is bool:
		return {}
	if not data.get("buildings") is Dictionary or not data.get("cells") is Dictionary or not data.get("heroes") is Array or not data.get("selected") is Array:
		return {}
	var fight := Rules.new()
	if data.buildings.size() != fight.building_levels.size() or data.heroes.size() != fight.heroes.size():
		return {}
	for id in fight.building_levels:
		if not _integer(data.buildings.get(id), 0, 3):
			return {}
		fight.building_levels[id] = int(data.buildings[id])
		if data.buildings[id] == 0:
			if data.cells.has(id):
				return {}
			continue
		var cell: Variant = data.cells.get(id)
		if not cell is Array or cell.size() != 2 or not _integer(cell[0], 0, 47) or not _integer(cell[1], 0, 7):
			return {}
		var position := Vector2i(int(cell[0]), int(cell[1]))
		if not fight.grid.can_place(id, position):
			return {}
		fight.grid.buildings[id] = {"cell": position, "size": Rules.TownGrid.BUILDINGS[id].size}
	if data.cells.size() != fight.grid.buildings.size():
		return {}
	for id in range(fight.heroes.size()):
		var saved: Variant = data.heroes[id]
		if not saved is Dictionary or not saved.get("owned") is bool or (id < 3 and not saved.owned):
			return {}
		for key in ["level", "xp", "wins", "stamina"]:
			if not _integer(saved.get(key), 1 if key == "level" else 0, {"level": 10, "xp": 189, "wins": 1000000000000000, "stamina": fight.max_stamina()}[key]):
				return {}
		var rest: Variant = saved.get("rest")
		if not (rest is int or rest is float) or not is_finite(float(rest)) or rest < 0.0 or rest > Rules.REST_DURATION:
			return {}
		if (saved.stamina == 0) != (rest > 0.0) or (not saved.owned and (rest > 0.0 or saved.level != 1 or saved.xp != 0 or saved.wins != 0)):
			return {}
		for key in ["level", "xp", "wins", "stamina"]:
			fight.heroes[id][key] = int(saved[key])
		fight.heroes[id].owned = saved.owned
		fight.rest_remaining[id] = float(rest)
		if (saved.level == 10 and saved.xp != 0) or (saved.level < 10 and saved.xp >= fight.xp_needed(id)):
			return {}
	if fight.owned_count() > fight.roster_capacity():
		return {}
	fight.coins = int(data.gold)
	fight.completed = int(data.completed)
	fight.arena_tier = int(data.seats)
	fight.fighter_tier = int(data.fighters)
	fight.auto_fill_owned = data.auto_owned
	fight.auto_fill_enabled = data.auto_enabled
	# Version-1 saves from before onboarding remain valid; returning owners skip the welcome.
	fight.intro_seen = data.get("intro_seen", fight.completed > 0 or not fight.grid.buildings.is_empty())
	var selected: Array[int] = []
	for id in data.selected:
		if not _integer(id, 0, 7) or int(id) in selected or not fight.heroes[int(id)].owned:
			return {}
		selected.append(int(id))
	if selected.size() > fight.fighter_capacity():
		return {}
	return {"fight": fight, "selected": selected}


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 100000:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return decode(parser.data)


static func load_game(path: String = DEFAULT_PATH) -> Dictionary:
	var result := _read(path)
	if result.is_empty():
		result = _read(path + ".bak")
		if not result.is_empty():
			result["recovered"] = true
	return result


static func save_game(fight: RefCounted, selected: Array[int], path: String = DEFAULT_PATH) -> Error:
	var data := snapshot(fight, selected)
	if decode(data).is_empty():
		return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if not _read(path).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	elif FileAccess.file_exists(path):
		# Preserve unreadable data before replacing it with the recovered/new estate.
		error = DirAccess.copy_absolute(path, path + ".corrupt")
		if error != OK:
			return error
	return DirAccess.rename_absolute(path + ".tmp", path)
