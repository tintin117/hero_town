extends RefCounted
## Fame tiers and the manager's book decision.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	var t := Kit.tuning()
	Kit.check(p, t.fame_tier_points.size() == 4 and t.fame_tier_names.size() == 4, "4 fame tiers")
	Kit.check(p, Fame.tier(0, t) == 0 and Fame.tier(299, t) == 0 and Fame.tier(300, t) == 1, "tier 1 -> 2 boundary")
	Kit.check(p, Fame.tier(2999, t) == 1 and Fame.tier(3000, t) == 2 and Fame.tier(19999, t) == 2 and Fame.tier(20000, t) == 3, "upper boundaries")
	Kit.check(p, Fame.tier(10000000, t) == 3, "top tier is the ceiling")
	Kit.check(p, Kit.near(Fame.progress(0, t), 0.0) and Kit.near(Fame.progress(150, t), 0.5), "progress within tier 0")
	Kit.check(p, Kit.near(Fame.progress(300, t), 0.0) and Kit.near(Fame.progress(1650, t), 0.5), "progress within tier 1")
	Kit.check(p, Fame.progress(20000, t) == 1.0, "progress full at the top")
	Kit.check(p, Fame.gained(45.0, t) == 5 and Fame.gained(0.0, t) == 1 and Fame.gained(100.0, t) == 11, "fame per fight")

	var state := GameState.create(t, Kit.catalog().heroes)
	Kit.check(p, state.manager.threshold == 70.0 and not state.manager.enabled, "manager defaults: off, 70")
	var lineup: Array[int] = [0, 1]
	state.hype = 80.0
	Kit.check(p, not AutoManager.should_book(state, t, lineup), "disabled manager never books")
	state.manager.enabled = true
	Kit.check(p, AutoManager.should_book(state, t, lineup), "enabled, hype above threshold")
	state.hype = 69.9
	Kit.check(p, not AutoManager.should_book(state, t, lineup), "below threshold waits")
	state.hype = 70.0
	Kit.check(p, AutoManager.should_book(state, t, lineup), "at threshold books")
	lineup = [0] as Array[int]
	Kit.check(p, not AutoManager.should_book(state, t, lineup), "a planted lineup that is too small never books")
	lineup = [0, 2] as Array[int]
	Kit.check(p, not AutoManager.should_book(state, t, lineup), "an unowned fighter never books")
	return p
