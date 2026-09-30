extends RefCounted
## Gym training: slots, XP per interval, level-ups, planted / series interplay, level-cap release, pause.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	_slots(p)
	_xp(p)
	_planted_and_series(p)
	_cap_and_pause(p)
	return p


## A game with a gym (level `lvl`) and a third owned hero (2) so a trainee can sit out of the lineup.
func _gym_game(lvl := 1, fake: Kit.FakeSim = null) -> Node:
	var g := Kit.game(fake)
	g.state.buildings["gym"] = {"level": lvl, "cell": [10, 0]}
	g.state.heroes[2].owned = true
	return g


func _slots(p: Array[String]) -> void:
	var g := Kit.game()
	g.state.heroes[2].owned = true
	Kit.check(p, not g.assign_training(0) and g.training_slots() == 0, "no gym, no slots")
	g.state.gold = 250 + 150000
	Kit.check(p, g.build(&"gym", Vector2i(10, 0)) and g.training_slots() == 1, "gym level 1: one slot")
	var log := Kit.record(g.events)
	Kit.check(p, g.assign_training(0) and g.training_heroes() == ([0] as Array[int]), "assign fills the slot")
	Kit.check(p, Kit.count(log, "hero") == 1 and log[0] == ["hero", 0], "hero_changed on assign")
	Kit.check(p, not g.assign_training(0), "already training")
	Kit.check(p, not g.assign_training(1), "no free slot")
	Kit.check(p, g.upgrade(&"gym") and g.training_slots() == 2 and g.assign_training(1), "level 2: second slot")
	Kit.check(p, not g.assign_training(2), "slots full again")
	Kit.check(p, not g.assign_training(5) and not g.assign_training(-1) and not g.assign_training(99), "unowned / out of range")
	Kit.check(p, g.recall_training(0) and not g.recall_training(0) and g.training_heroes() == ([1] as Array[int]), "recall frees the slot once")
	Kit.check(p, g.assign_training(2) and g.state.training[2] == 0.0, "freed slot is reusable")
	Kit.dispose(g)


func _xp(p: Array[String]) -> void:
	var g := _gym_game()
	var log := Kit.record(g.events)
	Kit.check(p, g.assign_training(2), "assign Nia")
	g.advance(29.5)
	Kit.check(p, g.state.heroes[2].xp == 0 and Kit.near(g.state.training[2], 29.5), "no xp before the interval")
	g.advance(0.5)
	Kit.check(p, g.state.heroes[2].xp == 5 and Kit.near(g.state.training[2], 0.0), "5 xp after 30 s")
	Kit.check(p, Kit.count(log, "hero") == 2, "hero_changed for the assign and the payout")
	g.advance(65.0)
	Kit.check(p, g.state.heroes[2].xp == 15 and Kit.near(g.state.training[2], 5.0), "a long step pays every interval it crossed")
	log.clear()
	# 30 xp needed at level 1: 6 intervals in total, 3 done
	g.advance(30.0 * 3 - 5.0)
	Kit.check(p, g.state.heroes[2].level == 2 and g.state.heroes[2].xp == 0, "level up at 30 xp (level %d, xp %d)" % [g.state.heroes[2].level, g.state.heroes[2].xp])
	Kit.check(p, Kit.count(log, "roster") == 1 and g.state.training.has(2), "roster_changed on level-up, still training")
	Kit.check(p, g.state.heroes[2].wins == 0 and g.state.fight_count == 0 and g.state.gold == 0, "training touches only xp")
	# a non-trainee earns nothing
	Kit.check(p, g.state.heroes[0].xp == 0 and g.state.heroes[1].xp == 0, "benched non-trainees earn nothing")
	Kit.dispose(g)

	# autosave once a payout lands
	g = _gym_game()
	g.autosave = true
	Kit.clear_save_files(g.save_path)
	g.assign_training(2)
	g.advance(30.0)
	var g2 := Kit.game()
	g2.save_path = g.save_path
	Kit.check(p, g2.continue_game() and g2.state.heroes[2].xp == 5 and g2.training_heroes() == ([2] as Array[int]), "payout is saved")
	Kit.clear_save_files(g.save_path)
	Kit.dispose(g2)
	Kit.dispose(g)


func _planted_and_series(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := _gym_game(1, fake)
	# plant refuses a picked trainee
	Kit.check(p, g.assign_training(0), "Bram trains")
	Kit.check(p, not g.plant() and g.planted.is_empty(), "plant refused while a picked hero trains")
	Kit.check(p, not g.book_fight([0, 1] as Array[int]), "the bell refuses a trainee")
	Kit.check(p, g.recall_training(0) and g.plant(), "recalled, then plant works")
	Kit.check(p, not g.assign_training(0) and not g.assign_training(1), "planted heroes cannot start training")
	Kit.check(p, g.assign_training(2), "a bench hero still can")
	g.advance(30.0)
	Kit.check(p, g.state.heroes[2].xp == 5, "training runs while a lineup is planted")

	# the series: trainee on the bench keeps earning through the bouts
	g.state.hype = 100.0
	g.state.manager.enabled = true
	g.advance(0.25)  # the bell rings by itself
	Kit.check(p, not g.series.is_empty() and not g.fight.is_empty(), "series running")
	Kit.check(p, not g.assign_training(1), "series fighters cannot start training")
	var before: float = g.state.training[2]
	g.advance(1.0)
	Kit.check(p, Kit.near(g.state.training[2], before + 1.0), "training keeps ticking during a fight")
	g.uproot()
	Kit.dispose(g)

	# a trainee inside the planted lineup or the series lineup stops earning (no auto-recall)
	g = _gym_game()
	g.assign_training(2)
	g.planted = [2, 0] as Array[int]
	g.advance(60.0)
	Kit.check(p, g.state.heroes[2].xp == 0 and g.state.training.has(2), "planted trainee is paused, not recalled")
	g.planted = [] as Array[int]
	g.series = {"lineup": [2, 0] as Array[int], "pause": 1.0e9}
	g.advance(60.0)
	Kit.check(p, g.state.heroes[2].xp == 0 and g.state.training.has(2), "series trainee is paused, not recalled")
	g.series = {}
	g.advance(30.0)
	Kit.check(p, g.state.heroes[2].xp == 5, "resumes once free")
	Kit.dispose(g)


func _cap_and_pause(p: Array[String]) -> void:
	var g := _gym_game()
	var log := Kit.record(g.events)
	g.state.heroes[2].level = 10
	Kit.check(p, not g.assign_training(2), "a capped hero cannot train")
	g.state.heroes[2].level = 9
	g.state.heroes[2].xp = 185  # 190 needed for level 10
	Kit.check(p, g.assign_training(2), "one level below the cap trains")
	log.clear()
	g.advance(30.0)
	Kit.check(p, g.state.heroes[2].level == 10 and g.state.heroes[2].xp == 0, "reaches the cap")
	Kit.check(p, g.state.training.is_empty() and g.training_heroes().is_empty(), "released at the cap")
	Kit.check(p, Kit.count(log, "roster") == 1 and Kit.count(log, "hero") >= 1, "announced")
	g.advance(300.0)
	Kit.check(p, g.state.heroes[2].xp == 0, "nothing more to earn")

	# a huge step never overshoots the cap
	g.state.heroes[2].level = 9
	g.state.heroes[2].xp = 0
	g.assign_training(2)
	g.advance(30.0 * 1000)
	Kit.check(p, g.state.heroes[2].level == 10 and g.state.training.is_empty(), "a huge step stops at the cap")

	# pause freezes training (the sim clock only advances unpaused)
	g.state.heroes[2].level = 1
	g.state.heroes[2].xp = 0
	g.assign_training(2)
	g.set_paused(true)
	g._physics_process(100.0)
	Kit.check(p, g.state.heroes[2].xp == 0 and g.state.training[2] == 0.0, "paused: no training")
	g.set_paused(false)
	g._physics_process(30.0)
	Kit.check(p, g.state.heroes[2].xp == 5, "unpaused: training resumes")
	Kit.dispose(g)
