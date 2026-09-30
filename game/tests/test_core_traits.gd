extends RefCounted
## Hero traits: content, the combat mods each one builds, the series afterglow and story ripening.

const Kit := preload("res://game/tests/core_kit.gd")

const EXPECTED := {0: [&"brawler"], 1: [&"showman"], 2: [&"crowd_pleaser"], 3: [&"underdog"], 4: [&"grudge_holder"],
	5: [&"brawler", &"grudge_holder"], 6: [&"showman", &"crowd_pleaser"], 7: [&"underdog", &"crowd_pleaser"]}


func run() -> Array[String]:
	var p: Array[String] = []
	_content(p)
	_mods(p)
	_afterglow(p)
	_ripening(p)
	return p


func _content(p: Array[String]) -> void:
	var catalog := Kit.catalog()
	Kit.check(p, catalog.traits.size() == 5, "five traits")
	for d in catalog.traits:
		Kit.check(p, ResourceLoader.exists("res://resources/ui/icons/%s.png" % d.icon_name), "%s icon exists" % d.id)
		Kit.check(p, d.display_name != "" and d.description != "" and d.value > 0.0, "%s is authored" % d.id)
	var g := Kit.game()
	for id: int in EXPECTED:
		var ids: Array = g.hero_traits(id).map(func(d: TraitDef) -> StringName: return d.id)
		Kit.check(p, ids == EXPECTED[id], "hero %d traits %s" % [id, ids])
	Kit.check(p, g.hero_traits(99).is_empty() and g.hero_traits(-1).is_empty(), "unknown hero has no traits")
	Kit.dispose(g)


## The mods the first bout of a booking would get; the booking is dropped without settling.
func _mods_for(g: Node, fake: Kit.FakeSim, lineup: Array[int]) -> Dictionary:
	g.book_fight(lineup)
	var mods: Dictionary = fake.last_mods
	g.fight = {}
	g.series = {}
	return mods


func _mods(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	for id in [2, 3, 5, 6, 7]:
		g.state.heroes[id].owned = true
	g.state.fighter_tier = 3
	# brawler: that hero only; showman: skill excitement x1.5 per showman
	var mods := _mods_for(g, fake, [0, 2] as Array[int])
	Kit.check(p, mods == {"damage_mult": {0: 1.15}}, "brawler: %s" % [mods])
	mods = _mods_for(g, fake, [1, 2] as Array[int])
	Kit.check(p, mods == {"skill_excitement_mult": 1.5}, "showman: %s" % [mods])
	mods = _mods_for(g, fake, [1, 6] as Array[int])
	Kit.check(p, Kit.near(mods.skill_excitement_mult, 2.25), "two showmen multiply: %s" % [mods])
	mods = _mods_for(g, fake, [5, 2] as Array[int])
	Kit.check(p, mods == {"damage_mult": {5: 1.15}}, "Aldric hits harder, grudge_holder adds no combat mod: %s" % [mods])
	# underdog: +10 start excitement only against a higher level
	mods = _mods_for(g, fake, [3, 0] as Array[int])
	Kit.check(p, not mods.has("start_excitement"), "equal levels: no underdog bonus")
	g.state.heroes[0].level = 3
	mods = _mods_for(g, fake, [3, 0] as Array[int])
	Kit.check(p, Kit.near(mods.start_excitement, 10.0), "Tuck is the underdog against Bram")
	mods = _mods_for(g, fake, [0, 3] as Array[int])
	Kit.check(p, Kit.near(mods.start_excitement, 10.0) and mods.damage_mult.has(0), "lineup order does not matter")
	g.state.heroes[7].level = 2
	mods = _mods_for(g, fake, [3, 7, 0] as Array[int])
	Kit.check(p, Kit.near(mods.start_excitement, 20.0), "two underdogs, +10 each: %s" % [mods])
	mods = _mods_for(g, fake, [7, 3] as Array[int])
	Kit.check(p, Kit.near(mods.start_excitement, 10.0), "only the lower level is the underdog: %s" % [mods])
	# the mods are rebuilt for every bout of a series from the current levels
	g.tuning.series_wins = 3
	g.tuning.series_max_bouts = 9
	g.state.heroes[0].level = 2
	fake.winner = 3
	var starts: Array[bool] = []
	g.events.fight_started.connect(func(_info: Dictionary) -> void: starts.append(fake.last_mods.has("start_excitement")))
	g.book_fight([3, 0] as Array[int])
	Kit.play_out(g)
	Kit.check(p, starts == [true, true, false], "Tuck catches up to Bram's level and loses the bonus: %s" % [starts])
	Kit.dispose(g)


func _afterglow(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	g.state.heroes[2].owned = true
	var plain := Hype.afterglow(fake.excitement, g.tuning)
	Kit.bout(g, fake, 0, [0, 1] as Array[int])
	Kit.check(p, Kit.near(g.state.hype, plain), "no crowd pleaser: plain afterglow %s" % g.state.hype)
	var log := Kit.record(g.events)
	Kit.bout(g, fake, 0, [0, 2] as Array[int])
	Kit.check(p, Kit.near(g.state.hype, plain * 1.5), "crowd pleaser: afterglow x1.5 (%s)" % g.state.hype)
	Kit.check(p, Kit.count(log, "hype") == 2, "hype announced at the bout and again when the series ends")
	# a long series keeps the plain afterglow between bouts and applies the bonus once, at the end
	g.tuning.series_wins = 3
	g.tuning.series_max_bouts = 9
	var seen: Array[float] = []
	g.events.fight_finished.connect(func(_r: Dictionary) -> void: seen.append(g.state.hype))
	Kit.bout(g, fake, 0, [0, 2] as Array[int])
	Kit.check(p, seen.size() == 3 and Kit.near(seen[0], plain) and Kit.near(seen[1], plain), "plain afterglow between bouts: %s" % [seen])
	Kit.check(p, Kit.near(seen[2], plain * 1.5) and Kit.near(g.state.hype, plain * 1.5), "bonus applied once, at the end: %s" % [seen])
	g.state.heroes[6].owned = true
	Kit.bout(g, fake, 0, [0, 6] as Array[int])
	Kit.check(p, Kit.near(g.state.hype, plain * 1.5), "Vera is a crowd pleaser too")
	Kit.dispose(g)


func _ripening(p: Array[String]) -> void:
	var fake := Kit.FakeSim.new()
	var g := Kit.game(fake)
	for id in [4, 5]:
		g.state.heroes[id].owned = true
	g.state.buildings["promotion_office"] = {"level": 3, "cell": [10, 0]}  # room for every story
	# the same three bouts for Bram/Ivo (no grudge holder) and Rook/Aldric (both)
	for pair: Array[int] in [[0, 1] as Array[int], [4, 5] as Array[int]]:
		for w: int in [pair[0], pair[1], pair[0]]:
			Kit.bout(g, fake, w, pair)
	var plain := Stories.find(g.state, Stories.RIVALRY, [0, 1] as Array[int])
	var holder := Stories.find(g.state, Stories.RIVALRY, [4, 5] as Array[int])
	Kit.check(p, Kit.near(plain.ripeness, 40.0), "rivalry: created at 20, +20 for a meeting (%s)" % plain.ripeness)
	Kit.check(p, Kit.near(holder.ripeness, 50.0), "grudge holders: the same meeting ripens x1.5 (%s)" % holder.ripeness)
	var grudge_plain := Stories.find(g.state, Stories.GRUDGE, [1, 0] as Array[int])
	var grudge_holder := Stories.find(g.state, Stories.GRUDGE, [5, 4] as Array[int])
	Kit.check(p, not grudge_plain.is_empty() and not grudge_holder.is_empty(), "both pairs grew a grudge")
	# time ripening honours the trait as well
	var before_plain: float = grudge_plain.ripeness
	var before_holder: float = grudge_holder.ripeness
	for i in 60:
		g.advance(1.0)
	Kit.check(p, Kit.near(grudge_plain.ripeness - before_plain, 10.0, 1e-4), "+1 per 6 s: 60 s is +10 (%s)" % (grudge_plain.ripeness - before_plain))
	Kit.check(p, Kit.near(grudge_holder.ripeness - before_holder, 15.0, 1e-4), "grudge holder: +15 in 60 s (%s)" % (grudge_holder.ripeness - before_holder))
	Kit.dispose(g)
