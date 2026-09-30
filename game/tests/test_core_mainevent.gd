extends RefCounted
## Main event: choosing a ripe story, lineup edits, the plant snapshot, cash-in payout and fame, uproot.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	_choosing(p)
	_lineup_edits(p)
	_cash_in(p)
	_uproot(p)
	return p


func _game(fake: Kit.FakeSim) -> Node:
	var g := Kit.game(fake)
	g.new_game()
	g.state.hype = 70.0
	return g


func _choosing(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := _game(fake)
	var duo: Array[int] = [0, 1]
	var raw := Kit.add_story(g, Stories.RIVALRY, duo, 30.0)
	var ripe := Kit.add_story(g, Stories.RIVALRY, [0, 2] as Array[int], 80.0)
	var solo := Kit.add_story(g, Stories.LEGEND, [1] as Array[int], 90.0)
	Kit.check(p, not g.set_main_event(99), "unknown story")
	Kit.check(p, not g.set_main_event(raw) and g.main_event_id == -1, "an unripe story cannot be the main event")
	Kit.check(p, not g.set_main_event(ripe) and g.state.preferred_lineup == duo, "hero 2 is not owned: nothing changes")
	g.state.heroes[2].owned = true
	Kit.check(p, g.set_main_event(ripe) and g.main_event_id == ripe and g.state.preferred_lineup == [0, 2], "the story's heroes become the lineup")
	Kit.check(p, g.set_main_event(solo) and g.main_event_id == solo and g.state.preferred_lineup == [1, 0],
			"one hero brings the first other owned hero of the lineup: %s" % [g.state.preferred_lineup])
	Kit.check(p, g.clear_main_event() and g.main_event_id == -1 and not g.clear_main_event(), "clear")
	g.state.preferred_lineup = [2, 0] as Array[int]
	Kit.check(p, g.set_main_event(solo) and g.state.preferred_lineup == [1, 2], "the partner comes from the current lineup first: %s" % [g.state.preferred_lineup])
	g.state.training[1] = 0.0
	Kit.check(p, not g.set_main_event(solo), "a trainee cannot headline")
	g.state.training.clear()
	g.clear_main_event()
	g.state.heroes[0].owned = false
	g.state.heroes[2].owned = false
	Kit.check(p, not g.set_main_event(solo), "no partner to bring: the lineup cannot fit")
	var log: Array[int] = []
	g.events.story_changed.connect(func(id: int) -> void: log.append(id))
	g.state.heroes[0].owned = true
	g.set_main_event(solo)
	g.clear_main_event()
	Kit.check(p, log == [solo, solo], "choosing and clearing are announced: %s" % [log])
	Kit.dispose(g)


func _lineup_edits(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := _game(fake)
	g.state.heroes[2].owned = true
	var id := Kit.add_story(g, Stories.RIVALRY, [0, 1] as Array[int], 80.0)
	g.set_main_event(id)
	Kit.check(p, g.set_preferred_lineup([1, 0] as Array[int]) and g.main_event_id == id, "the same heroes keep it")
	Kit.check(p, not g.set_preferred_lineup([0] as Array[int]) and g.main_event_id == id, "a refused edit keeps it")
	Kit.check(p, g.set_preferred_lineup([0, 2] as Array[int]) and g.main_event_id == -1, "dropping a hero clears it")
	g.set_main_event(id)
	Kit.check(p, g.toggle_lineup(2) and g.main_event_id == -1, "a swap through toggle_lineup that drops a hero clears it")
	g.state.fighter_tier = 1
	g.set_main_event(id)
	Kit.check(p, g.toggle_lineup(2) and g.main_event_id == id and g.state.preferred_lineup == [0, 1, 2], "adding a hero to a bigger lineup keeps it")
	Kit.dispose(g)
	# a story that cools below the ripe threshold is no longer the main event
	fake = Kit.FakeSim.new()
	g = _game(fake)
	var cooling := Kit.add_story(g, Stories.WIN_STREAK, [6] as Array[int], 62.0)
	g.state.heroes[6].owned = true
	Kit.check(p, g.set_main_event(cooling) and g.main_event_id == cooling, "choose the streak")
	g.state.stories[0].cooling = true
	Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories[0].ripeness < g.tuning.story_ripe_threshold and g.main_event_id == -1, "cooled below ripe: the choice is dropped")
	Kit.dispose(g)


func _cash_in(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()  # Bram wins every bout
	var g := _game(fake)
	g.tuning.series_wins = 3
	g.tuning.series_max_bouts = 9
	g.tuning.series_fame_bonus = 5
	g.state.meetings["0-1"] = {"wins_a": 0, "wins_b": 1}  # Bram's wins split the results, so the rivalry keeps ripening
	var id := Kit.add_story(g, Stories.RIVALRY, [0, 1] as Array[int], 80.0)
	Kit.check(p, g.set_main_event(id), "choose the rivalry")
	var started: Array[Dictionary] = []
	var finished: Array[Dictionary] = []
	var bouts: Array[Dictionary] = []
	var story_ripeness: Array[float] = []
	g.events.series_started.connect(func(info: Dictionary) -> void: started.append(info))
	g.events.series_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	g.events.fight_finished.connect(func(result: Dictionary) -> void:
		bouts.append(result)
		story_ripeness.append(g.story(id).get("ripeness", -1.0)))
	var fame_before: int = g.state.fame_points
	Kit.check(p, g.plant() and g.planted_main_event.id == id and Kit.near(g.planted_main_event.multiplier, 2.6), "plant locks the story at x2.6")
	Kit.check(p, g.planted_main_event.kind == Stories.RIVALRY and g.planted_main_event.title == "test story" and Kit.near(g.planted_main_event.ripeness, 80.0), "locked snapshot")
	g.clear_main_event()  # choices after the plant change nothing
	g.advance(0.25)  # the bell rings by itself
	Kit.play_out(g)
	Kit.check(p, started.size() == 1 and started[0].main_event.id == id and started[0].prop == &"", "series_started carries the main event: %s" % [started])
	Kit.check(p, bouts.size() == 3, "three bouts (%d)" % bouts.size())
	for b in bouts:
		var normal := roundi(b.locked_base * b.multiplier)
		Kit.check(p, Kit.near(b.main_event_multiplier, 2.6) and b.payout == roundi(normal * 2.6), "bout payout x2.6: %d vs normal %d" % [b.payout, normal])
	Kit.check(p, story_ripeness.size() == 3 and story_ripeness[0] > 80.0 and story_ripeness[1] > 80.0 and story_ripeness[2] < 0.0,
			"the story keeps ripening on the board until the last bout cashes it in: %s" % [story_ripeness])
	Kit.check(p, finished.size() == 1 and finished[0].winner == 0, "series won")
	Kit.check(p, finished[0].main_event.id == id and finished[0].prop == &"", "series_finished carries it")
	Kit.check(p, finished[0].fame_bonus == 5 + 8, "series fame bonus plus round(80 / 10): %d" % finished[0].fame_bonus)
	var fame_from_bouts: int = 0
	for b in bouts:
		fame_from_bouts += b.fame_gained
	Kit.check(p, g.state.fame_points == fame_before + fame_from_bouts + 13, "the winner's side gets the fame")
	Kit.check(p, g.story(id).is_empty() and g.main_event_id == -1, "the story is consumed at the end")
	Kit.check(p, g.planted_main_event.is_empty() and g.planted.is_empty(), "nothing stays planted")
	# without a main event a bout pays the normal amount
	var plain := bouts.size()
	g.state.hype = 70.0
	g.plant()
	g.advance(0.25)
	Kit.play_out(g)
	var after := bouts.slice(plain)
	Kit.check(p, after.size() == 3 and after.all(func(b: Dictionary) -> bool: return Kit.near(b.main_event_multiplier, 1.0)), "x1 without a main event")
	Kit.check(p, finished[1].main_event.is_empty() and finished[1].fame_bonus == 5, "no bonus without one: %s" % [finished[1]])
	# ripeness 0..100 maps to x1..x3
	Kit.check(p, Kit.near(Stories.multiplier(0.0, g.tuning), 1.0) and Kit.near(Stories.multiplier(100.0, g.tuning), 3.0), "x1 to x3")
	Kit.dispose(g)


func _uproot(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := _game(fake)
	var id := Kit.add_story(g, Stories.RIVALRY, [0, 1] as Array[int], 80.0)
	g.set_main_event(id)
	Kit.check(p, g.plant() and g.uproot(), "plant and uproot")
	Kit.check(p, g.main_event_id == id and not g.story(id).is_empty() and g.planted_main_event.is_empty(), "uprooting keeps the choice and the story")
	Kit.check(p, g.plant() and g.planted_main_event.id == id, "it can be planted again")
	g.uproot()
	# an unripe story is not locked in
	g.state.stories[0].ripe = false
	g.state.stories[0].ripeness = 10.0
	Kit.check(p, g.plant() and g.planted_main_event.is_empty(), "a story that lost its ripeness is not locked")
	Kit.dispose(g)
