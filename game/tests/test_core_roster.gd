extends RefCounted
## Content, stat growth vs golden.json "stats", XP curve, recruiting and lineup rules.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	var catalog := Kit.catalog()
	var t := catalog.tuning
	var defs := catalog.heroes
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/tests/golden.json"))

	# content
	Kit.check(p, defs.size() == 8, "8 heroes")
	var prices := [0, 0, 100, 150, 250, 400, 350000, 500000]
	for i in defs.size():
		Kit.check(p, defs[i].id == i, "hero %d has id %d" % [i, defs[i].id])
		Kit.check(p, defs[i].price == prices[i], "hero %d price" % i)
		Kit.check(p, defs[i].start_owned == (i < 2), "hero %d start_owned" % i)
		Kit.check(p, defs[i].trait_ids.size() in [1, 2], "hero %d has one or two traits" % i)
		var g: Dictionary = golden.heroes[i]
		Kit.check(p, defs[i].display_name == g.name and defs[i].health == g.health and defs[i].attack == g.attack
				and defs[i].red == g.red and defs[i].ranged == g.ranged and defs[i].unit == StringName(g.unit),
				"hero %s matches golden" % g.name)
		Kit.check(p, defs[i].skill.kind == g.skill.kind and defs[i].skill.power == g.skill.power and defs[i].skill.name == g.skill.name,
				"hero %s skill matches golden" % g.name)
	Kit.check(p, defs[5].skill.kind == defs[1].skill.kind and defs[6].skill.kind == defs[2].skill.kind and defs[7].skill.kind == defs[3].skill.kind, "Aldric/Vera/Oswin use the Ivo/Nia/Tuck templates")

	# stat growth vs golden
	for row: Dictionary in golden.stats:
		var id: int = golden.heroes.map(func(h: Dictionary) -> String: return h.name).find(row.name)
		for level_row: Array in row.levels:
			var stats := Roster.stats_for(defs[id], int(level_row[0]), t)
			Kit.check(p, stats.health == int(level_row[1]) and stats.attack == int(level_row[2]),
					"%s level %d: got %s want %d/%d" % [row.name, level_row[0], stats, level_row[1], level_row[2]])

	# XP curve
	Kit.check(p, Roster.xp_needed(1, t) == 30 and Roster.xp_needed(2, t) == 50 and Roster.xp_needed(9, t) == 190, "xp curve 30 + 20 * (lv - 1)")
	Kit.check(p, Roster.xp_needed(10, t) == 0, "no xp needed at the cap")
	var hero := HeroState.new()
	var award := Roster.award_xp(hero, 200, t)  # 30 + 50 + 70 = 150 -> level 4 with 50 left
	Kit.check(p, hero.level == 4 and hero.xp == 50 and award.before == 1 and award.after == 4, "multi-level award")
	hero.level = 9
	hero.xp = 185
	Roster.award_xp(hero, 10, t)
	Kit.check(p, hero.level == 10 and hero.xp == 0, "reaching the cap zeroes xp")
	Kit.check(p, Roster.award_xp(hero, 50, t).xp == 0 and hero.xp == 0, "no xp at the cap")

	# recruiting
	var state := GameState.create(t, defs)
	Kit.check(p, Roster.owned_count(state) == 2 and state.preferred_lineup == ([0, 1] as Array[int]), "start with Bram and Ivo")
	Kit.check(p, not Roster.can_recruit(state, defs, 2), "cannot recruit Nia with 0 gold")
	state.gold = 100
	Kit.check(p, Roster.can_recruit(state, defs, 2) and not Roster.can_recruit(state, defs, 3), "Nia affordable, Tuck not")
	Kit.check(p, not Roster.can_recruit(state, defs, 0), "cannot recruit an owned hero")
	Kit.check(p, not Roster.can_recruit(state, defs, 8) and not Roster.can_recruit(state, defs, -1), "out-of-range ids")

	# lineups
	var one: Array[int] = [0]
	var pair: Array[int] = [0, 1]
	var dup: Array[int] = [0, 0]
	var unowned: Array[int] = [0, 2]
	var three: Array[int] = [0, 1, 2]
	Kit.check(p, Roster.valid_lineup(state, t, pair), "pair valid")
	Kit.check(p, not Roster.valid_lineup(state, t, one), "single fighter invalid")
	Kit.check(p, not Roster.valid_lineup(state, t, dup), "duplicates invalid")
	Kit.check(p, not Roster.valid_lineup(state, t, unowned), "unowned invalid")
	state.heroes[2].owned = true
	Kit.check(p, not Roster.valid_lineup(state, t, three), "three exceeds capacity 2")
	state.fighter_tier = 1
	Kit.check(p, Roster.valid_lineup(state, t, three) and Roster.fighter_capacity(state, t) == 3, "three fits capacity 3")
	return p
