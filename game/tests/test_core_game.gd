extends RefCounted
## Game commands and the full fight lifecycle, driven by a fake simulator (no combat_sim needed).

const Kit := preload("res://game/tests/core_kit.gd")
const STEP := 0.25  # exactly representable, so the fake sim's event times line up with the clock


func run() -> Array[String]:
	var p: Array[String] = []
	_lifecycle(p)
	_manager_and_pause(p)
	_commands(p)
	return p


func _lifecycle(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	var log := Kit.record(g.events)
	g.state.hype = 70.0
	Kit.check(p, g.attendance_if_booked_now() == 73, "attendance at hype 70 is 73")
	Kit.check(p, g.income_preview([0, 1] as Array[int]) == 73 and g.income_preview([0] as Array[int]) == 0, "income preview")

	Kit.check(p, g.book_fight([0, 1] as Array[int], {"seed": 5}), "book_fight accepted")
	Kit.check(p, fake.calls == 1 and fake.last_seed == 5 and fake.last_mods == null, "sim called once with seed and neutral mods")
	Kit.check(p, fake.last_lineup[0] == {"id": 0, "name": "Bram", "red": false, "ranged": false, "health": 225, "attack": 17,
			"skill": {"kind": "strike", "power": 2.0}}, "lineup dictionary shape: %s" % [fake.last_lineup[0]])
	Kit.check(p, not g.book_fight([0, 1] as Array[int]), "no second booking while fighting")
	Kit.check(p, fake.calls == 1, "rejected booking does not run the sim")
	Kit.check(p, Kit.count(log, "booked") == 1 and Kit.count(log, "started") == 1, "booked/started once")
	var info: Dictionary = log.filter(func(e: Array) -> bool: return e[0] == "started")[0][1]
	Kit.check(p, info.attendance == 73 and info.seats == 100 and info.seed == 5 and info.duration == 5.0 and info.lineup == [0, 1], "fight_started info")
	Kit.check(p, Kit.count(log, "combat") == 0 and g.state.gold == 0, "nothing released before playback advances")

	var seen := 0
	for k in range(1, 21):
		g.advance(STEP)
		var clock := STEP * k
		var combat := log.filter(func(e: Array) -> bool: return e[0] == "combat")
		for i in range(seen, combat.size()):
			var t: float = combat[i][1].t
			Kit.check(p, t <= clock and t > clock - STEP, "event t=%s released in step ending %s" % [t, clock])
		seen = combat.size()
		if k < 20:
			Kit.check(p, g.state.hype == 70.0 and Kit.count(log, "hype") == 0, "hype frozen during the fight (step %d)" % k)
			Kit.check(p, Kit.count(log, "finished") == 0, "not settled early (step %d)" % k)
		if k == 8:  # clock 2.0: first skill released, second not yet
			Kit.check(p, g.state.gold == 10, "first tip paid when its skill releases (gold %d)" % g.state.gold)
	var kinds := log.filter(func(e: Array) -> bool: return e[0] == "combat").map(func(e: Array) -> Variant: return e[1].kind)
	Kit.check(p, kinds == [&"move", &"attack", &"skill", &"attack", &"skill", &"attack"], "events in order: %s" % [kinds])
	var deltas := log.filter(func(e: Array) -> bool: return e[0] == "gold").map(func(e: Array) -> int: return e[2])
	Kit.check(p, deltas == [10, 10, 91], "gold: two tips then payout 91 (got %s)" % [deltas])
	Kit.check(p, g.state.gold == 111, "gold 111 (got %d)" % g.state.gold)
	Kit.check(p, Kit.count(log, "finished") == 1 and g.fight.is_empty(), "settled exactly once")
	Kit.check(p, Kit.near(g.state.hype, 13.5), "hype reset to afterglow")
	Kit.check(p, Kit.count(log, "hype") == 1 and Kit.count(log, "fame") == 1, "hype and fame announced once")
	Kit.check(p, g.state.fight_count == 1 and g.state.fame_points == 5, "fight_count and fame")
	var result: Dictionary = log.filter(func(e: Array) -> bool: return e[0] == "finished")[0][1]
	Kit.check(p, result.payout == 91 and result.attendance == 73 and result.winner == 0 and result.excitement == 45.0, "fight_finished payload")
	Kit.check(p, g.state.heroes[0].wins == 1 and g.state.heroes[0].xp == 20 and g.state.heroes[1].losses == 1, "wins/xp/losses applied")
	Kit.check(p, Kit.count(log, "hero") == 2, "hero_changed per fighter")
	g.advance(STEP * 4)
	Kit.check(p, Kit.count(log, "finished") == 1, "no repeat settlement")

	# idle again: hype grows, and a second fight can start (Bram levels up on his second win)
	Kit.check(p, g.state.hype > 13.5, "hype grows after the fight")
	Kit.check(p, g.book_fight([0, 1] as Array[int]) and fake.last_seed == 1, "second fight starts with the seed counter")
	Kit.check(p, fake.last_lineup[0].health == 225 and fake.last_lineup[0].attack == 17, "level 1 stats until settled")
	for k in 20:
		g.advance(STEP)
	Kit.check(p, Kit.count(log, "finished") == 2 and g.state.heroes[0].level == 2 and g.state.heroes[0].xp == 10, "second fight settled, Bram level 2")
	Kit.check(p, g.book_fight([0, 1] as Array[int]) and fake.last_lineup[0].health == 236 and fake.last_lineup[0].attack == 18, "level scaling in lineup")
	Kit.dispose(g)


func _manager_and_pause(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	var log := Kit.record(g.events)
	g.state.hype = 69.0
	Kit.check(p, g.set_manager(true, 70.0) and Kit.count(log, "manager") == 1, "set_manager")
	g.advance(0.5)
	Kit.check(p, fake.calls == 0 and g.fight.is_empty(), "manager waits below threshold")
	g.advance(2.0)
	Kit.check(p, fake.calls == 1 and not g.fight.is_empty(), "manager books once hype passes 70")
	Kit.check(p, g.state.hype > 70.0, "hype at the bell")

	var g2 := Kit.game(fake)
	var log2 := Kit.record(g2.events)
	Kit.check(p, g2.set_paused(true) and g2.paused and log2.back() == ["paused", true], "pause emits")
	g2._physics_process(100.0)
	Kit.check(p, g2.state.hype == 15.0, "paused sim does not advance")
	g2.set_paused(false)
	g2._physics_process(1.0)
	Kit.check(p, g2.state.hype > 15.0, "unpaused sim advances")

	var g3 := Kit.game(fake)
	var log3 := Kit.record(g3.events)
	for i in 60:
		g3.advance(1.0 / 60.0)
	var emitted := Kit.count(log3, "hype")
	Kit.check(p, emitted >= 8 and emitted <= 10, "hype_changed throttled to ~10 Hz (got %d in 1 s)" % emitted)
	for node in [g, g2, g3]:
		Kit.dispose(node)


func _commands(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	var log := Kit.record(g.events)
	# recruit
	Kit.check(p, not g.recruit(2), "recruit without gold fails")
	g.state.gold = 150
	Kit.check(p, g.recruit(2) and g.state.gold == 50 and g.state.heroes[2].owned, "recruit Nia for 100")
	Kit.check(p, log.has(["gold", 50, -100]) and log.has(["hero", 2]) and Kit.count(log, "roster") == 1 and Kit.count(log, "toast") == 1, "recruit signals")
	Kit.check(p, not g.recruit(2) and not g.recruit(99), "cannot recruit twice / unknown id")
	# lineup + manager validation
	Kit.check(p, not g.set_preferred_lineup([0] as Array[int]) and not g.set_preferred_lineup([0, 3] as Array[int]), "invalid preferred lineups rejected")
	Kit.check(p, g.set_preferred_lineup([1, 0] as Array[int]) and g.state.preferred_lineup == ([1, 0] as Array[int]),"valid preferred lineup")
	Kit.check(p, not g.set_manager(true, 100.0) and not g.set_manager(true, -1.0) and not g.state.manager.enabled, "invalid thresholds rejected")
	Kit.check(p, g.set_manager(true, 65.0) and g.state.manager == {"enabled": true, "threshold": 65.0}, "manager stored")
	# upgrades
	g.state.gold = 5499
	Kit.check(p, not g.can_afford(5500) and not g.expand_seats() and g.state.seats_tier == 0, "seats need 5500")
	g.state.gold = 5500
	Kit.check(p, g.expand_seats() and g.state.seats_tier == 1 and g.state.gold == 0, "seats to 150")
	g.state.hype = 100.0
	Kit.check(p, g.attendance_if_booked_now() == 150, "attendance uses the new seats")
	g.state.gold = 600000
	Kit.check(p, g.expand_seats() and g.state.seats_tier == 2 and not g.expand_seats(), "seats maxed at tier 2")
	g.state.gold = 1500
	var three: Array[int] = [0, 1, 2]
	Kit.check(p, not g.book_fight(three), "three fighters exceed capacity 2")
	Kit.check(p, g.expand_fighters() and g.state.fighter_tier == 1 and g.state.gold == 0, "fighters to 3")
	Kit.check(p, g.book_fight(three), "three fighters now allowed")
	g.state.gold = 3000000
	g.fight = {}
	Kit.check(p, g.expand_fighters() and g.expand_fighters() and not g.expand_fighters(), "fighters maxed at tier 3")
	# a broken simulator never leaves a half-started fight
	var broken := Callable(func(_l: Array, _s: int, _m: Variant) -> Dictionary: return {})
	g.sim = broken
	Kit.check(p, not g.book_fight([0, 1] as Array[int]) and g.fight.is_empty(), "bad sim output rejected")
	Kit.dispose(g)
