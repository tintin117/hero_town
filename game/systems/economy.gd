class_name Economy
extends RefCounted
## Money and progression rules. Tips are not settled here: Game pays them as playback releases skills.


static func excitement_tier(excitement: float, t: Tuning) -> int:
	var result := 0
	for i in t.excitement_thresholds.size():
		if excitement >= t.excitement_thresholds[i]:
			result = i
	return result


static func excitement_multiplier(excitement: float, t: Tuning) -> float:
	return t.excitement_multipliers[excitement_tier(excitement, t)]


## Ticket income locked at the bell: fighter levels and wins scaled by the crowd.
static func base_income(state: GameState, t: Tuning, lineup: Array[int], attendance: int) -> int:
	var raw := t.base_income
	for id in lineup:
		var hero := state.heroes[id]
		raw += t.income_per_level * (hero.level - 1) + t.income_per_win * mini(hero.wins, t.win_income_cap)
	return roundi(float(raw * attendance) / t.income_reference_attendance)


## Next tier price, or -1 when maxed.
static func seats_cost(state: GameState, t: Tuning) -> int:
	return t.seat_costs[state.seats_tier] if state.seats_tier < t.seat_costs.size() else -1


static func fighters_cost(state: GameState, t: Tuning) -> int:
	return t.fighter_costs[state.fighter_tier] if state.fighter_tier < t.fighter_costs.size() else -1


## Applies a finished fight to `state` (gold, XP, wins, fame, hype) exactly once and returns
## the sim result extended with everything that changed. `result` is the simulator's dictionary.
static func settle(state: GameState, t: Tuning, lineup: Array[int], result: Dictionary,
		attendance: int, locked_base: int) -> Dictionary:
	var excitement := float(result.get("excitement", 0.0))
	var winner := int(result.get("winner", -1))
	var multiplier := excitement_multiplier(excitement, t)
	var payout := roundi(locked_base * multiplier)
	var fame_before := Fame.tier(state.fame_points, t)
	var fame_gain := Fame.gained(excitement, t)
	var heroes: Array[Dictionary] = []
	for id in lineup:
		var hero := state.heroes[id]
		var won := id == winner
		if won:
			hero.wins += 1
		elif winner in lineup:
			hero.losses += 1
		hero.streak = hero.streak + 1 if won else 0
		var xp := Roster.award_xp(hero, t.xp_per_fight + (t.xp_win_bonus if won else 0), t)
		heroes.append({"id": id, "won": won, "xp": xp.xp, "level_before": xp.before, "level": xp.after,
			"wins": hero.wins, "losses": hero.losses, "streak": hero.streak})
	state.gold += payout
	state.fame_points += fame_gain
	state.fight_count += 1
	state.hype = Hype.afterglow(excitement, t)
	var out := result.duplicate()
	out.merge({"lineup": lineup.duplicate(), "attendance": attendance, "locked_base": locked_base,
		"multiplier": multiplier, "payout": payout, "fame_gained": fame_gain,
		"fame_points": state.fame_points, "fame_tier_before": fame_before,
		"fame_tier": Fame.tier(state.fame_points, t), "afterglow": state.hype, "heroes": heroes}, true)
	return out
