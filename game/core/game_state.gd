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
		"manager": manager.duplicate(), "fight_count": fight_count, "rng_seed_counter": rng_seed_counter,
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
	state.fight_count = int(d.get("fight_count", 0))
	state.rng_seed_counter = int(d.get("rng_seed_counter", 0))
	return state
