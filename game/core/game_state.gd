class_name GameState
extends Resource
## The single serialisable game state. Only Game and the systems it calls mutate it; UI reads.
## The running fight is transient (Game.fight) and not saved: combat restarts after loading.

var gold := 0
var hype := 0.0
var fame_points := 0
var seats_tier := 0
var fighter_tier := 0
var heroes: Array[HeroState] = []
var preferred_lineup: Array[int] = []
var manager := {"enabled": false, "threshold": 0.0}
## Built buildings: id (String) -> {level: int, cell: [x, y]}. Unbuilt ids are absent.
var buildings := {}
## Gym trainees: hero id (int) -> seconds since their last training payout.
var training := {}
## Stories (see Stories): {id, kind, title, heroes, ripeness, ripe, cooling, full_bouts}.
var stories: Array[Dictionary] = []
var next_story_id := 0
## Head-to-head results "a-b" (a < b) -> {wins_a, wins_b}.
var meetings := {}
## Owned props: prop id (String) -> count.
var props := {}
var fight_count := 0
var rng_seed_counter := 0


static func create(tuning: Tuning, defs: Array[HeroDef]) -> GameState:
	var state := GameState.new()
	state.gold = tuning.starting_gold
	state.hype = tuning.hype_start
	state.manager.threshold = tuning.manager_threshold
	for def in defs:
		var hero := HeroState.new()
		hero.owned = def.start_owned
		state.heroes.append(hero)
		if hero.owned and state.preferred_lineup.size() < tuning.fighter_tiers[0]:
			state.preferred_lineup.append(def.id)
	return state


func to_dict() -> Dictionary:
	return {
		"gold": gold, "hype": hype, "fame_points": fame_points,
		"seats_tier": seats_tier, "fighter_tier": fighter_tier,
		"heroes": heroes.map(func(h: HeroState) -> Dictionary: return h.to_dict()),
		"preferred_lineup": preferred_lineup.duplicate(),
		"buildings": buildings.duplicate(true), "training": _training_json(),
		"stories": stories.map(func(s: Dictionary) -> Dictionary: return _story_json(s)), "next_story_id": next_story_id, "meetings": meetings.duplicate(true),
		"props": props.duplicate(), "manager": manager.duplicate(), "fight_count": fight_count, "rng_seed_counter": rng_seed_counter,
	}


## Lenient: SaveStore validates ranges first. JSON numbers arrive as floats, hence the int() casts.
static func from_dict(d: Dictionary) -> GameState:
	var state := GameState.new()
	state.gold = int(d.get("gold", 0))
	state.hype = float(d.get("hype", 0.0))
	state.fame_points = int(d.get("fame_points", 0))
	state.seats_tier = int(d.get("seats_tier", 0))
	state.fighter_tier = int(d.get("fighter_tier", 0))
	for hero: Dictionary in d.get("heroes", []):
		state.heroes.append(HeroState.from_dict(hero))
	for id in d.get("preferred_lineup", []):
		state.preferred_lineup.append(int(id))
	var saved: Dictionary = d.get("manager", {})
	state.manager = {"enabled": bool(saved.get("enabled", false)), "threshold": float(saved.get("threshold", 0.0))}
	var saved_buildings: Dictionary = d.get("buildings", {})
	for id: String in saved_buildings:
		var b: Dictionary = saved_buildings[id]
		state.buildings[id] = {"level": int(b.level), "cell": [int(b.cell[0]), int(b.cell[1])]}
	var saved_training: Dictionary = d.get("training", {})
	for id: Variant in saved_training:
		state.training[int(id)] = float(saved_training[id])
	for saved_story: Dictionary in d.get("stories", []):
		state.stories.append(Stories.from_dict(saved_story))
		state.next_story_id = maxi(state.next_story_id, state.stories[-1].id + 1)
	state.next_story_id = maxi(state.next_story_id, int(d.get("next_story_id", 0)))
	var saved_meetings: Dictionary = d.get("meetings", {})
	for key: String in saved_meetings:
		state.meetings[key] = {"wins_a": int(saved_meetings[key].wins_a), "wins_b": int(saved_meetings[key].wins_b)}
	var saved_props: Dictionary = d.get("props", {})
	for id: String in saved_props:
		state.props[id] = int(saved_props[id])
	state.fight_count = int(d.get("fight_count", 0))
	state.rng_seed_counter = int(d.get("rng_seed_counter", 0))
	return state


func _story_json(story: Dictionary) -> Dictionary:
	var result := story.duplicate(true)
	result.kind = String(story.kind)
	return result


func _training_json() -> Dictionary:
	var result := {}
	for id: int in training:
		result[str(id)] = training[id]  # JSON keys are strings
	return result
