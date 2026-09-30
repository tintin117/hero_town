extends RefCounted
## Game.preview: sense checks (who raises or lowers the stars), range narrowing, income, purity.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	var g := Kit.game(Kit.FakeSim.new())
	g.state.heroes[2].owned = true
	g.state.heroes[3].owned = true
	var base_duo: Array[int] = [0, 2]  # Bram + Nia: no showman
	var show_duo: Array[int] = [1, 2]  # Ivo is a showman
	var base: Dictionary = g.preview(base_duo)
	Kit.check(p, base.keys().size() == 4 and base.stars_min >= 1.0 and base.stars_max <= 5.0 and base.stars_min <= base.stars_max, "shape and range: %s" % [base])
	Kit.check(p, fmod(base.stars_min * 2.0, 1.0) == 0.0 and fmod(base.stars_max * 2.0, 1.0) == 0.0, "stars come in halves")
	Kit.check(p, base.income_min <= base.income_max and base.income_min > 0, "income range: %s" % [base])
	Kit.check(p, base.income_min == roundi(73 * 1.25), "income is base at the bell threshold (attendance 73) x the star band: %d" % base.income_min)
	Kit.check(p, g.preview([0] as Array[int]) == {"stars_min": 0.0, "stars_max": 0.0, "income_min": 0, "income_max": 0}, "an invalid lineup previews nothing")
	# more show: showman, fireworks, announcer, a ripe matching story
	var show: Dictionary = g.preview(show_duo)
	Kit.check(p, show.stars_min > base.stars_min, "a showman raises the stars")
	Kit.check(p, g.preview(base_duo, {"prop": &"fireworks"}).stars_min > base.stars_min, "fireworks raise them")
	Kit.check(p, g.preview(base_duo, {"prop": &"announcer"}).stars_min > base.stars_min, "the announcer raises them")
	Kit.check(p, g.preview(base_duo, {"prop": &"spotlights"}) == base, "spotlights only change the afterglow")
	var story := Kit.add_story(g, Stories.LEGEND, [0] as Array[int], 30.0)
	Kit.check(p, g.preview(base_duo) == base, "an unripe story changes nothing")
	g.state.stories[0].ripeness = 80.0
	g.state.stories[0].ripe = true
	var with_story: Dictionary = g.preview(base_duo)
	Kit.check(p, with_story.stars_min > base.stars_min and with_story.income_max >= base.income_max, "a ripe matching story raises them")
	Kit.check(p, g.preview(show_duo) == show, "a story about someone else changes nothing")
	# a chosen main event multiplies the income, not the stars
	var chosen: Dictionary = g.preview(base_duo, {"main_event": story})
	Kit.check(p, chosen.stars_min == with_story.stars_min and chosen.income_min == roundi(with_story.income_min * 2.6)
			and chosen.income_max == roundi(with_story.income_max * 2.6), "the main event multiplies income: %s vs %s" % [chosen, with_story])
	g.set_main_event(story)
	Kit.check(p, g.preview(g.state.preferred_lineup) == g.preview(g.state.preferred_lineup, {"main_event": story}), "defaults to the chosen main event")
	g.clear_main_event()
	g.state.stories.clear()
	# a big level gap lowers them
	g.state.heroes[0].level = 10
	Kit.check(p, g.preview(base_duo).stars_min < base.stars_min, "a mismatch lowers the stars")
	g.state.heroes[0].level = 1
	# the Promotion Office narrows the range and keeps its hype effect
	var width: float = base.stars_max - base.stars_min
	var last: float = width
	for level in [1, 2, 3]:
		g.state.buildings["promotion_office"] = {"level": level, "cell": [10, 0]}
		var narrowed: Dictionary = g.preview(base_duo)
		Kit.check(p, narrowed.stars_max - narrowed.stars_min < last, "office level %d narrows the range (%s)" % [level, narrowed])
		Kit.check(p, narrowed.stars_min >= base.stars_min and narrowed.stars_max <= base.stars_max, "and stays inside the wider one")
		last = narrowed.stars_max - narrowed.stars_min
	Kit.check(p, Kit.near(Buildings.hype_tau_multiplier(g.state, g.catalog), 0.55), "the office still speeds up hype")
	g.state.buildings.clear()
	# pure: nothing changed
	var before: Dictionary = g.state.to_dict()
	var sel: StringName = g.selected_prop
	g.preview(base_duo, {"prop": &"fireworks"})
	g.preview(show_duo)
	Kit.check(p, g.state.to_dict() == before and g.selected_prop == sel and g.fight.is_empty() and g.series.is_empty(), "preview has no side effects")
	# more seats and a higher bell threshold change the income
	g.state.seats_tier = 1
	Kit.check(p, g.preview(base_duo).income_min > base.income_min, "a bigger house pays more")
	Kit.dispose(g)
	return p
