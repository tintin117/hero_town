class_name Buildings
extends RefCounted
## Town placement rules and building effects. Pure: state.buildings is {id String: {level, cell [x, y]}}.
## Each level has one number (BuildingLevel.effect): Promotion Office = hype tau multiplier,
## Recruitment Hall = owned-hero capacity, Gym = training slots, Restaurant = gold per fan each bout.

const OFFICE := &"promotion_office"
const HALL := &"recruitment_hall"
const GYM := &"gym"
const RESTAURANT := &"restaurant"


static func arena_rect(t: Tuning) -> Rect2i:
	return Rect2i(t.arena_first_col, 0, t.arena_last_col - t.arena_first_col + 1, t.grid_rows)


## Owned land above the public path.
static func land_rect(t: Tuning) -> Rect2i:
	return Rect2i(t.land_first_col, 0, t.land_last_col - t.land_first_col + 1, t.path_row)


static func def(catalog: Catalog, id: StringName) -> BuildingDef:
	for d in catalog.buildings:
		if d.id == id:
			return d
	return null


static func level(state: GameState, id: StringName) -> int:
	return int(state.buildings.get(String(id), {}).get("level", 0))


## (-1, -1) when unbuilt.
static func cell(state: GameState, id: StringName) -> Vector2i:
	var saved: Array = state.buildings.get(String(id), {}).get("cell", [-1, -1])
	return Vector2i(int(saved[0]), int(saved[1]))


static func footprint_rect(d: BuildingDef, at: Vector2i) -> Rect2i:
	return Rect2i(at, d.footprint)


## Inside the buildable land, off the arena, clear of every other building (a built one ignores itself).
static func can_place(state: GameState, catalog: Catalog, id: StringName, at: Vector2i) -> bool:
	var d := def(catalog, id)
	if d == null:
		return false
	var rect := footprint_rect(d, at)
	if not land_rect(catalog.tuning).encloses(rect) or rect.intersects(arena_rect(catalog.tuning)):
		return false
	for other: String in state.buildings:
		var other_def := def(catalog, StringName(other))
		if other != String(id) and other_def != null \
				and footprint_rect(other_def, cell(state, StringName(other))).intersects(rect):
			return false
	return true


static func building_at(state: GameState, catalog: Catalog, at: Vector2i) -> StringName:
	for id: String in state.buildings:
		var d := def(catalog, StringName(id))
		if d != null and footprint_rect(d, cell(state, StringName(id))).has_point(at):
			return StringName(id)
	return &""


## Price of the next level (level 1 when unbuilt), or -1 when maxed or unknown.
static func next_cost(state: GameState, catalog: Catalog, id: StringName) -> int:
	var d := def(catalog, id)
	var next := level(state, id)
	return d.levels[next].cost if d != null and next < d.levels.size() else -1


## Current level's number; the neutral value while unbuilt.
static func effect(state: GameState, catalog: Catalog, id: StringName) -> float:
	var d := def(catalog, id)
	var lvl := level(state, id)
	if d != null and lvl >= 1:
		return d.levels[lvl - 1].effect
	match id:
		OFFICE:
			return 1.0
		HALL:
			return float(catalog.tuning.hall_base_capacity)
	return 0.0


static func hype_tau_multiplier(state: GameState, catalog: Catalog) -> float:
	return effect(state, catalog, OFFICE)


static func hero_capacity(state: GameState, catalog: Catalog) -> int:
	return roundi(effect(state, catalog, HALL))


static func training_slots(state: GameState, catalog: Catalog) -> int:
	return roundi(effect(state, catalog, GYM))


static func concession_rate(state: GameState, catalog: Catalog) -> float:
	return effect(state, catalog, RESTAURANT)


## Short text for what `lvl` of a building does; "" for an unknown building or level.
static func describe(catalog: Catalog, id: StringName, lvl: int) -> String:
	var d := def(catalog, id)
	if d == null or lvl < 1 or lvl > d.levels.size():
		return ""
	var e := d.levels[lvl - 1].effect
	match id:
		OFFICE:
			return "Hype builds %d%% faster" % roundi((1.0 - e) * 100.0)
		HALL:
			return "Up to %d heroes" % roundi(e)
		GYM:
			return "%d training slot%s" % [roundi(e), "" if roundi(e) == 1 else "s"]
		RESTAURANT:
			return "+%.1f gold per fan each bout" % e
	return ""
