class_name Roster
extends RefCounted
## Fighter stats, XP curve, recruiting and lineup rules.


static func stats_for(def: HeroDef, level: int, t: Tuning) -> Dictionary:
	var growth := 1.0 + t.stat_growth * (level - 1)
	return {"health": roundi(def.health * growth), "attack": roundi(def.attack * growth)}


static func xp_needed(level: int, t: Tuning) -> int:
	return t.xp_base + t.xp_step * (level - 1) if level < t.level_cap else 0


## Adds XP and levels up; returns {xp, before, after}. Level-capped fighters keep 0 XP.
static func award_xp(hero: HeroState, amount: int, t: Tuning) -> Dictionary:
	var before := hero.level
	var gained := amount if before < t.level_cap else 0
	hero.xp += gained
	while hero.level < t.level_cap and hero.xp >= xp_needed(hero.level, t):
		hero.xp -= xp_needed(hero.level, t)
		hero.level += 1
	if hero.level == t.level_cap:
		hero.xp = 0
	return {"xp": gained, "before": before, "after": hero.level}


static func seats(state: GameState, t: Tuning) -> int:
	return t.seat_tiers[state.seats_tier]


static func fighter_capacity(state: GameState, t: Tuning) -> int:
	return t.fighter_tiers[state.fighter_tier]


static func owned_count(state: GameState) -> int:
	return state.heroes.filter(func(h: HeroState) -> bool: return h.owned).size()


## `capacity` is the Recruitment Hall's owned-hero cap.
static func can_recruit(state: GameState, defs: Array[HeroDef], id: int, capacity := 1 << 30) -> bool:
	return id >= 0 and id < defs.size() and not state.heroes[id].owned and state.gold >= defs[id].price \
			and owned_count(state) < capacity


static func valid_lineup(state: GameState, t: Tuning, lineup: Array[int]) -> bool:
	if lineup.size() < t.min_lineup or lineup.size() > fighter_capacity(state, t):
		return false
	var seen := {}
	for id in lineup:
		if id < 0 or id >= state.heroes.size() or seen.has(id) or not state.heroes[id].owned:
			return false
		seen[id] = true
	return true
