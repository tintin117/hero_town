class_name SaveStore
extends RefCounted
## Versioned JSON save. Writes go temp file -> backup of the last good primary -> rename, and a
## corrupt primary falls back to the backup. Tests pass their own paths under .godot/.

const VERSION := 1
const DEFAULT_PATH := "user://fight_club_save.json"
const CATALOG_PATH := "res://game/data/catalog.tres"  # building footprints, when the caller passes no catalog
const MAX_INT := 1000000000000000
const MAX_BYTES := 100000  # ponytail: sanity cap against garbage files; raise if the state ever grows


static func save(state: GameState, path: String = DEFAULT_PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "state": state.to_dict()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if not _parse(path).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak")
	elif FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, path + ".corrupt")  # keep unreadable data for inspection
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)


## Returns {state, recovered} (recovered = read from the backup), or {} when nothing valid exists.
static func load_state(t: Tuning, hero_count: int, path: String = DEFAULT_PATH, catalog: Catalog = null) -> Dictionary:
	for candidate in [[path, false], [path + ".bak", true]]:
		var state := decode(_parse(candidate[0]), t, hero_count, catalog)
		if state != null:
			return {"state": state, "recovered": candidate[1]}
	return {}


## `buildings` and `training` are optional (older saves), but when present they must be consistent.
static func decode(data: Dictionary, t: Tuning, hero_count: int, catalog: Catalog = null) -> GameState:
	if not _int(data.get("version"), VERSION, VERSION) or not data.get("state") is Dictionary:
		return null
	var s: Dictionary = data.state
	var manager: Variant = s.get("manager")
	var heroes: Variant = s.get("heroes")
	var lineup: Variant = s.get("preferred_lineup")
	if not (_int(s.get("gold"), 0, MAX_INT) and _number(s.get("hype"), 0.0, t.hype_max)
			and _int(s.get("fame_points"), 0, MAX_INT) and _int(s.get("fight_count"), 0, MAX_INT)
			and _int(s.get("rng_seed_counter"), 0, MAX_INT)
			and _int(s.get("seats_tier"), 0, t.seat_tiers.size() - 1)
			and _int(s.get("fighter_tier"), 0, t.fighter_tiers.size() - 1)):
		return null
	if not manager is Dictionary or not manager.get("enabled") is bool \
			or not _number(manager.get("threshold"), 0.0, t.hype_max) or manager.threshold >= t.hype_max:
		return null
	if not heroes is Array or heroes.size() != hero_count or not lineup is Array:
		return null
	for hero: Variant in heroes:
		if not _valid_hero(hero, t):
			return null
	if catalog == null:
		catalog = load(CATALOG_PATH)
	if not _valid_buildings(s.get("buildings", {}), catalog) or not _valid_training(s.get("training", {}), heroes, t) \
			or not _valid_stories(s.get("stories", []), s.get("next_story_id", 0), hero_count, t) \
			or not _valid_meetings(s.get("meetings", {}), hero_count) or not _valid_props(s.get("props", {}), catalog, t):
		return null
	var state := GameState.from_dict(s)
	if state.training.size() > Buildings.training_slots(state, catalog) \
			or state.stories.size() > t.story_slots_base + Buildings.level(state, Buildings.OFFICE):
		return null
	for id: String in state.buildings:  # symmetric overlap test, so one pass finds every clash
		if not Buildings.can_place(state, catalog, StringName(id), Buildings.cell(state, StringName(id))):
			return null
	var seen := {}
	for id: Variant in lineup:
		if not _int(id, 0, hero_count - 1) or seen.has(int(id)) or not state.heroes[int(id)].owned:
			return null
		seen[int(id)] = true
	if lineup.size() > t.fighter_tiers[state.fighter_tier]:
		return null
	return state


static func _valid_buildings(buildings: Variant, catalog: Catalog) -> bool:
	if not buildings is Dictionary:
		return false
	for id: Variant in buildings:
		var d := Buildings.def(catalog, StringName(id)) if id is String else null
		var b: Variant = buildings[id]
		if d == null or not b is Dictionary or not _int(b.get("level"), 1, d.levels.size()):
			return false
		var cell: Variant = b.get("cell")
		if not cell is Array or cell.size() != 2 or not _int(cell[0], 0, catalog.tuning.grid_columns) 				or not _int(cell[1], 0, catalog.tuning.grid_rows):
			return false
	return true


static func _valid_training(training: Variant, heroes: Array, t: Tuning) -> bool:
	if not training is Dictionary:
		return false
	for id: Variant in training:
		if not id is String or not id.is_valid_int() or not _int(int(id), 0, heroes.size() - 1) 				or not heroes[int(id)].owned or not _number(training[id], 0.0, t.gym_interval) or training[id] >= t.gym_interval:
			return false
	return true


static func _valid_stories(stories: Variant, next_id: Variant, hero_count: int, t: Tuning) -> bool:
	if not stories is Array or not _int(next_id, 0, MAX_INT):
		return false
	var seen := {}
	for s: Variant in stories:
		if not s is Dictionary or not _int(s.get("id"), 0, MAX_INT) or seen.has(int(s.id)):
			return false
		seen[int(s.id)] = true
		var heroes: Variant = s.get("heroes")
		if not s.get("kind") is String or not StringName(s.kind) in Stories.KINDS or not s.get("title") is String \
				or not heroes is Array or heroes.size() != Stories.hero_count(StringName(s.kind)) \
				or not _number(s.get("ripeness"), 0.0, Stories.MAX_RIPENESS) or not s.get("cooling") is bool \
				or s.get("ripe") != (s.ripeness >= t.story_ripe_threshold) or not _int(s.get("full_bouts"), 0, MAX_INT):
			return false
		for i in heroes.size():
			if not _int(heroes[i], 0, hero_count - 1) or (i > 0 and (heroes[i] == heroes[0]
					or (s.kind == Stories.RIVALRY and heroes[0] > heroes[1]))):
				return false
	return true


## Keys are "a-b" with a < b.
static func _valid_meetings(meetings: Variant, hero_count: int) -> bool:
	if not meetings is Dictionary:
		return false
	for key: Variant in meetings:
		var ids: PackedStringArray = key.split("-") if key is String else PackedStringArray()
		var m: Variant = meetings[key]
		if ids.size() != 2 or not ids[0].is_valid_int() or not ids[1].is_valid_int() \
				or not _int(int(ids[0]), 0, int(ids[1]) - 1) or not _int(int(ids[1]), 0, hero_count - 1) \
				or not m is Dictionary or not _int(m.get("wins_a"), 0, MAX_INT) or not _int(m.get("wins_b"), 0, MAX_INT):
			return false
	return true


static func _valid_props(props: Variant, catalog: Catalog, t: Tuning) -> bool:
	if not props is Dictionary:
		return false
	for id: Variant in props:
		if not id is String or Props.def(catalog, StringName(id)) == null or not _int(props[id], 0, t.prop_cap):
			return false
	return true


static func _valid_hero(hero: Variant, t: Tuning) -> bool:
	if not hero is Dictionary or not hero.get("owned") is bool or not _int(hero.get("level"), 1, t.level_cap) \
			or (hero.has("recent_losses") and not _int(hero.recent_losses, 0, MAX_INT)):
		return false
	for key in ["xp", "wins", "losses", "streak"]:
		if not _int(hero.get(key), 0, MAX_INT):
			return false
	return hero.xp < Roster.xp_needed(int(hero.level), t) if hero.level < t.level_cap else hero.xp == 0


static func _int(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
			and value == floorf(float(value)) and value >= low and value <= high


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data
