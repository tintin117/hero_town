extends RefCounted
## The bo5 series: hype builds once, the crowd is locked at the bell, first to 3 wins ends it.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	var fake := Kit.FakeSim.new()  # hero 0 wins every bout
	var g: Node = Kit.game(fake)
	g.tuning.series_wins = 3
	g.tuning.series_max_bouts = 9
	g.tuning.series_pause = 3.0
	g.tuning.series_fame_bonus = 5
	g.new_game()
	g.state.hype = 60.0
	var crowd: int = g.attendance_if_booked_now()
	var log := Kit.record(g.events)
	var finished: Array = []
	g.events.series_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	Kit.check(p, g.book_fight([0, 1] as Array[int], {"seed": 10}), "bell rings")
	Kit.check(p, not g.book_fight([0, 1] as Array[int]), "no second bell during a series")
	var bouts := 0
	var seeds: Array = []
	var last_started := 0
	for i in 60 * 60:
		g.advance(1.0 / 60.0)
		if Kit.count(log, "started") != last_started:
			last_started = Kit.count(log, "started")
			seeds.append(fake.last_seed)
			Kit.check(p, g.fight.attendance == crowd, "bout %d keeps the locked crowd" % last_started)
		if g.fight.is_empty() and g.series.is_empty():
			break
	bouts = Kit.count(log, "finished")
	Kit.check(p, bouts == 3 and Kit.count(log, "started") == 3, "first to 3: three bouts when hero 0 sweeps (%d)" % bouts)
	Kit.check(p, seeds == [10, 11, 12], "each bout gets its own seed: %s" % str(seeds))
	Kit.check(p, finished.size() == 1 and finished[0].winner == 0 and finished[0].wins[0] == 3 and finished[0].bouts == 3, "series result")
	Kit.check(p, g.series.is_empty() and g.fight.is_empty(), "idle after the series")
	Kit.check(p, g.state.fight_count == 3, "every bout pays out")
	Kit.check(p, g.state.hype < 60.0, "hype falls to the afterglow when the series ends")
	var grown: float = g.state.hype
	g.advance(1.0)
	Kit.check(p, g.state.hype == grown and g.planted.is_empty(), "nothing grows until a lineup is planted again")
	g.plant()
	g.advance(1.0)
	Kit.check(p, g.state.hype > grown, "hype grows again after the series")
	# a draw does not count and the guard ends an endless series
	fake.winner = -1
	g.tuning.series_max_bouts = 3
	g.state.hype = 60.0
	finished.clear()
	g.book_fight([0, 1] as Array[int])
	for i in 60 * 60:
		g.advance(1.0 / 60.0)
		if g.fight.is_empty() and g.series.is_empty():
			break
	Kit.check(p, finished.size() == 1 and finished[0].winner == -1 and finished[0].bouts == 3 and finished[0].fame_bonus == 0, "draws end unresolved at the guard")
	# new_game mid-series drops it
	fake.winner = 0
	g.state.hype = 60.0
	g.book_fight([0, 1] as Array[int])
	g.new_game()
	Kit.check(p, g.series.is_empty() and g.fight.is_empty() and g.state.manager.enabled, "new_game clears the series and rings the bell by itself")
	Kit.dispose(g)
	return p
