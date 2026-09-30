extends RefCounted
## Props: content, seat-scaled prices, buy / select / consume / refund, and each effect reaching a bout.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	_content_and_prices(p)
	_commands(p)
	_effects(p)
	return p


func _content_and_prices(p: Array[String]) -> void:
	var catalog := Kit.catalog()
	Kit.check(p, catalog.props.map(func(d: PropDef) -> StringName: return d.id) == [&"fireworks", &"announcer", &"spotlights", &"ringside_bar"], "four props")
	for d in catalog.props:
		Kit.check(p, ResourceLoader.exists("res://resources/ui/icons/%s.png" % d.icon_name) and d.display_name != "" and d.description != "" and d.value > 0.0, "%s is authored" % d.id)
	var g := Kit.game()
	Kit.check(p, g.prop_defs().size() == 4, "Game.prop_defs")
	var base := {&"fireworks": 60, &"announcer": 80, &"spotlights": 100, &"ringside_bar": 120}
	for id: StringName in base:
		Kit.check(p, g.prop_price(id) == base[id], "%s costs its base price at 100 seats" % id)
	g.state.seats_tier = 1
	Kit.check(p, g.prop_price(&"fireworks") == 90 and g.prop_price(&"ringside_bar") == 180, "150 seats: x1.5")
	g.state.seats_tier = 2
	Kit.check(p, g.prop_price(&"fireworks") == 120 and g.prop_price(&"announcer") == 160, "200 seats: x2")
	Kit.check(p, g.prop_price(&"confetti") == -1, "unknown prop")
	Kit.dispose(g)


func _commands(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	g.new_game()  # rings the bell by itself
	var changes := [0]
	g.events.prop_changed.connect(func() -> void: changes[0] += 1)
	Kit.check(p, not g.buy_prop(&"fireworks") and g.props_owned(&"fireworks") == 0 and changes[0] == 0, "cannot afford")
	g.state.gold = 1000
	Kit.check(p, g.buy_prop(&"fireworks") and g.state.gold == 940 and g.props_owned(&"fireworks") == 1 and changes[0] == 1, "buy")
	Kit.check(p, not g.buy_prop(&"confetti"), "unknown prop")
	Kit.check(p, not g.select_prop(&"announcer") and g.selected_prop == &"", "nothing to select without stock")
	Kit.check(p, not g.select_prop(&"confetti"), "unknown selection")
	Kit.check(p, g.select_prop(&"fireworks") and g.selected_prop == &"fireworks" and changes[0] == 2, "select")
	Kit.check(p, g.select_prop(&"") and g.selected_prop == &"" and g.select_prop(&""), "empty clears (and is always fine)")
	g.select_prop(&"fireworks")
	# the cap
	g.state.gold = 100000
	for i in 8:
		Kit.check(p, g.buy_prop(&"fireworks"), "buy up to the cap (%d)" % i)
	Kit.check(p, g.props_owned(&"fireworks") == 9 and not g.buy_prop(&"fireworks") and g.props_owned(&"fireworks") == 9, "cap of 9")
	# plant consumes the selected one and clears the selection; uproot gives it back
	Kit.check(p, g.plant() and g.props_owned(&"fireworks") == 8 and g.selected_prop == &"" and g.planted_prop == &"fireworks", "plant consumes")
	Kit.check(p, not g.buy_prop(&"fireworks"), "the planted one still counts against the cap")
	Kit.check(p, g.uproot() and g.props_owned(&"fireworks") == 9 and g.planted_prop == &"", "uproot refunds")
	# planting without a selection consumes nothing
	Kit.check(p, g.plant() and g.props_owned(&"fireworks") == 9 and g.planted_prop == &"", "no selection, no prop used")
	g.uproot()
	# the prop of a series is spent for good; changing the selection after the plant does nothing
	g.select_prop(&"fireworks")
	g.plant()
	g.select_prop(&"fireworks")
	var started: Array[Dictionary] = []
	var finished: Array[Dictionary] = []
	g.events.series_started.connect(func(info: Dictionary) -> void: started.append(info))
	g.events.series_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, started.size() == 1 and started[0].prop == &"fireworks" and started[0].main_event == {}, "series_started names the prop: %s" % [started])
	Kit.check(p, finished.size() == 1 and finished[0].prop == &"fireworks" and finished[0].main_event == {}, "series_finished names it too")
	Kit.check(p, g.props_owned(&"fireworks") == 8 and g.planted_prop == &"", "spent for good")
	# new game starts empty
	g.new_game()
	Kit.check(p, g.selected_prop == &"" and g.state.props.is_empty() and g.props_owned(&"fireworks") == 0, "new game resets props")
	Kit.dispose(g)


func _effects(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	g.new_game()
	g.state.gold = 100000
	g.state.heroes[2].owned = true
	var duo: Array[int] = [0, 1]  # Bram (brawler) + Ivo (showman)
	# fireworks: +15 start excitement
	g.buy_prop(&"fireworks")
	g.select_prop(&"fireworks")
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.check(p, Kit.near(fake.last_mods.start_excitement, 15.0), "fireworks: %s" % [fake.last_mods])
	Kit.play_out(g)
	# announcer x1.5 stacks multiplicatively with the showman
	g.buy_prop(&"announcer")
	g.select_prop(&"announcer")
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.check(p, Kit.near(fake.last_mods.skill_excitement_mult, 2.25) and not fake.last_mods.has("start_excitement"), "announcer x showman: %s" % [fake.last_mods])
	Kit.play_out(g)
	# no prop: neutral again
	g.book_fight(duo)
	Kit.check(p, Kit.near(fake.last_mods.skill_excitement_mult, 1.5), "without a prop only the showman counts")
	Kit.play_out(g)
	# spotlights: afterglow x1.5 when the series ends (and with a crowd pleaser x2.25)
	var glow := Hype.afterglow(fake.excitement, g.tuning)
	g.buy_prop(&"spotlights")
	g.select_prop(&"spotlights")
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, Kit.near(g.state.hype, glow * 1.5), "spotlights: afterglow x1.5 (%s)" % g.state.hype)
	Kit.check(p, g.props_owned(&"spotlights") == 0 and not g.select_prop(&"spotlights"), "the spotlights were used up")
	g.buy_prop(&"spotlights")
	g.select_prop(&"spotlights")
	g.state.preferred_lineup = [0, 2] as Array[int]
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, Kit.near(g.state.hype, glow * 2.25), "spotlights x crowd pleaser (%s)" % g.state.hype)
	# ringside bar: +0.5 gold per attendee on top of the restaurant
	var results: Array[Dictionary] = []
	g.events.fight_finished.connect(func(r: Dictionary) -> void: results.append(r))
	g.state.preferred_lineup = duo
	g.buy_prop(&"ringside_bar")
	g.select_prop(&"ringside_bar")
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, results[0].concessions == roundi(results[0].attendance * 0.5), "bar: half a gold per fan (%d of %d)" % [results[0].concessions, results[0].attendance])
	g.state.buildings["restaurant"] = {"level": 1, "cell": [10, 0]}
	var rate := Buildings.concession_rate(g.state, g.catalog)
	g.buy_prop(&"ringside_bar")
	g.select_prop(&"ringside_bar")
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, rate > 0.0 and results[1].concessions == roundi(results[1].attendance * (rate + 0.5)), "bar adds to the restaurant (%d)" % results[1].concessions)
	g.plant()
	g.state.hype = 70.0
	g.advance(0.25)
	Kit.play_out(g)
	Kit.check(p, results[2].concessions == roundi(results[2].attendance * rate), "the restaurant alone afterwards")
	Kit.dispose(g)
