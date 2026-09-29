extends RefCounted
## Income formula against golden.json "incomes" (attendance == seats reproduces the old seat multiplier)
## plus settlement math.

const Kit := preload("res://game/tests/core_kit.gd")
const EXCITEMENT_SCORES := [0.0, 25.0, 59.0, 60.0, 100.0]  # the 5 golden with_excitement samples


func run() -> Array[String]:
	var p: Array[String] = []
	_golden_incomes(p)
	_settle(p)
	return p


func _golden_incomes(p: Array[String]) -> void:
	var t := Kit.tuning()
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/tests/golden.json"))
	Kit.check(p, golden.incomes.size() == 27, "27 golden income rows")
	for row: Dictionary in golden.incomes:
		var state := GameState.create(t, Kit.catalog().heroes)
		state.seats_tier = int(row.tier)
		for hero in state.heroes:
			hero.level = int(row.levels)
			hero.wins = int(row.wins)
		var lineup: Array[int] = [0, 1, 2]
		var seats := Roster.seats(state, t)
		var base := Economy.base_income(state, t, lineup, seats)
		var label := "tier %d level %d wins %d" % [row.tier, row.levels, row.wins]
		Kit.check(p, base == int(row.breakdown.guaranteed), "%s: base %d != golden %d" % [label, base, row.breakdown.guaranteed])
		for i in EXCITEMENT_SCORES.size():
			var got := roundi(base * Economy.excitement_multiplier(EXCITEMENT_SCORES[i], t))
			Kit.check(p, got == int(row.with_excitement[i]), "%s: excitement %s -> %d != golden %d" % [label, EXCITEMENT_SCORES[i], got, row.with_excitement[i]])
	# a half-empty house halves the ticket base
	var state := GameState.create(t, Kit.catalog().heroes)
	var pair: Array[int] = [0, 1]
	Kit.check(p, Economy.base_income(state, t, pair, 50) == 50, "half attendance halves base")
	Kit.check(p, Economy.base_income(state, t, pair, 73) == 73, "attendance 73 -> 73")
	Kit.check(p, Economy.excitement_tier(24.9, t) == 0 and Economy.excitement_tier(25.0, t) == 1 and Economy.excitement_tier(60.0, t) == 2, "excitement tier boundaries")
	Kit.check(p, Economy.seats_cost(state, t) == 5500 and Economy.fighters_cost(state, t) == 1500, "first upgrade costs")
	state.seats_tier = 2
	state.fighter_tier = 3
	Kit.check(p, Economy.seats_cost(state, t) == -1 and Economy.fighters_cost(state, t) == -1, "maxed upgrades report -1")


func _settle(p: Array[String]) -> void:
	var t := Kit.tuning()
	var state := GameState.create(t, Kit.catalog().heroes)
	state.gold = 1000
	state.hype = 70.0
	var lineup: Array[int] = [0, 1]
	var result := {"winner": 0, "duration": 12.0, "excitement": 45.0, "tips": 40, "skills": 4}
	var out := Economy.settle(state, t, lineup, result, 55, 55)
	# payout = round(55 * 1.25) = 69; gold before tips are paid by Game
	Kit.check(p, out.payout == 69 and state.gold == 1069, "payout 69 (got %s, gold %d)" % [out.payout, state.gold])
	Kit.check(p, out.multiplier == 1.25 and out.attendance == 55 and out.locked_base == 55, "multiplier/attendance echoed")
	Kit.check(p, out.fame_gained == 5 and state.fame_points == 5, "fame 1 + int(45/10)")
	Kit.check(p, Kit.near(state.hype, 13.5) and Kit.near(out.afterglow, 13.5), "hype resets to afterglow")
	Kit.check(p, state.fight_count == 1, "fight_count")
	Kit.check(p, out.excitement == 45.0 and out.winner == 0 and out.skills == 4, "sim result keys preserved")
	var winner: HeroState = state.heroes[0]
	var loser: HeroState = state.heroes[1]
	Kit.check(p, winner.wins == 1 and winner.streak == 1 and winner.losses == 0 and winner.xp == 20, "winner: 1 win, 20 xp")
	Kit.check(p, loser.wins == 0 and loser.losses == 1 and loser.streak == 0 and loser.xp == 10, "loser: 1 loss, 10 xp")
	Kit.check(p, out.heroes[0].won and not out.heroes[1].won and out.heroes[0].xp == 20, "hero rows in lineup order")

	# second win: 20 + 20 = 40 xp -> level 2 with 10 left; streak 2
	out = Economy.settle(state, t, lineup, result, 55, 55)
	Kit.check(p, winner.level == 2 and winner.xp == 10 and winner.streak == 2, "level-up on second win")
	Kit.check(p, out.heroes[0].level_before == 1 and out.heroes[0].level == 2, "level-up reported")
	Kit.check(p, state.fight_count == 2 and state.fame_points == 10, "second settle accumulates")

	# tier of excitement changes payout; a draw gives nobody a win or loss
	state = GameState.create(t, Kit.catalog().heroes)
	out = Economy.settle(state, t, lineup, {"winner": -1, "excitement": 70.0}, 100, 100)
	Kit.check(p, out.payout == 250, "wild fight pays x2.5")
	Kit.check(p, state.heroes[0].wins == 0 and state.heroes[0].losses == 0 and state.heroes[0].xp == 10, "draw: no win/loss, base xp")
	Kit.check(p, out.fame_gained == 8, "fame from excitement 70")
