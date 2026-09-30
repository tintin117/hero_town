class_name Preview
extends RefCounted
## What the bell is expected to deliver for a lineup: a star range and the ticket income at the manager's
## bell threshold. Pure estimate from the templates (no fight is simulated); the Promotion Office narrows it.

const STAR_STEP := 0.5
const MIN_STARS := 1.0
const MAX_STARS := 5.0


## `story_match`: a ripe story fits the lineup. `main_mult`: payout multiplier of the chosen main event.
static func estimate(state: GameState, catalog: Catalog, lineup: Array[int], prop: PropDef,
		story_match: bool, main_mult: float) -> Dictionary:
	var t := catalog.tuning
	if not Roster.valid_lineup(state, t, lineup):
		return {"stars_min": 0.0, "stars_max": 0.0, "income_min": 0, "income_max": 0}
	var mods := Traits.combat_mods(state, catalog, lineup)
	Props.apply(prop, mods)
	var casters := lineup.filter(func(id: int) -> bool: return catalog.heroes[id].skill.kind != "heal").size()
	var levels := lineup.map(func(id: int) -> int: return state.heroes[id].level)
	var excitement: float = t.preview_base_excitement + float(mods.get("start_excitement", 0.0)) \
			+ casters * t.preview_skills_per_fighter * t.preview_skill_excitement * float(mods.get("skill_excitement_mult", 1.0)) \
			- (levels.max() - levels.min()) * t.preview_level_gap_penalty \
			+ (t.preview_story_bonus if story_match else 0.0)
	var stars := clampf(MIN_STARS + excitement / t.preview_excitement_per_star, MIN_STARS, MAX_STARS)
	var width := maxf(0.0, t.preview_width - t.preview_width_step * Buildings.level(state, Buildings.OFFICE))
	var low := _snap(stars - width)
	var high := _snap(stars + width)
	var base := Economy.base_income(state, t, lineup, Hype.attendance(Roster.seats(state, t), state.manager.threshold, t))
	return {"stars_min": low, "stars_max": high,
		"income_min": _income(base, low, main_mult, t), "income_max": _income(base, high, main_mult, t)}


static func _snap(stars: float) -> float:
	return clampf(snappedf(stars, STAR_STEP), MIN_STARS, MAX_STARS)


## Ticket payout at a star rating: stars map back to excitement, then to the multiplier band.
static func _income(base: int, stars: float, main_mult: float, t: Tuning) -> int:
	var multiplier := Economy.excitement_multiplier((stars - MIN_STARS) * t.preview_excitement_per_star, t)
	return roundi(roundi(base * multiplier) * main_mult)
