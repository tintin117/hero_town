extends SceneTree
const Rules = preload("res://conquest/conquest_state.gd")
func _init() -> void:
	var g = Rules.new()
	for n in [3,5,7,9]:
		for spell in ["fireball","healing"]:
			g.s.warriors=n
			g.s.mages=1
			g.s.spell=spell
			var b=g.simulate(2)
			print(n," ",spell," river ",b.won," hp ",b.timeline.back().hp)
			if n == 7: assert(b.won == (spell == "healing"))
			if n == 9: assert(b.won)
	g = Rules.new()
	assert(g.simulate(0).won)
	assert(g.deploy())
	assert(g.s.owned == 1)
	g.finish_battle()
	assert(g.build_academy())
	assert(g.start("warriors"))
	assert(g.start("mage"))
	assert(not g.start("mage"))
	g.advance(g.s.last+120)
	assert(g.s.warriors==5 and g.s.mages==1 and g.s.projects.is_empty())
	assert(g.s.recovery==0)
	assert(g.simulate(1).won)
	assert(g.start("warriors"))
	assert(g.deploy())
	var remaining = g.s.projects.barracks.remaining
	var gold = g.s.gold
	g.advance(g.s.last+7)
	assert(g.s.projects.barracks.remaining==remaining)
	assert(g.s.gold>gold)
	assert(g.save_game("res://conquest/test_save.json"))
	var loaded=Rules.new()
	loaded.load_game("res://conquest/test_save.json")
	assert(loaded.s.battle.won and loaded.s.owned==2)
	loaded.s.last = Time.get_unix_time_from_system()-600
	assert(loaded.save_game("res://conquest/test_save.json"))
	var offline = Rules.new()
	var summary = offline.load_game("res://conquest/test_save.json")
	assert(offline.s.warriors == loaded.s.warriors and offline.s.battle == loaded.s.battle)
	assert(offline.s.projects == loaded.s.projects and offline.s.recovery == loaded.s.recovery)
	assert(offline.s.gold == loaded.s.gold and offline.completed.is_empty())
	assert(summary.contains("resumed where you left off"))
	var resumed_remaining: float = offline.s.battle.remaining
	offline.advance(offline.s.last + 1.0)
	assert(is_equal_approx(offline.s.battle.remaining, resumed_remaining - 1.0))
	g.advance(g.s.last+207)
	assert(g.s.warriors==7 and g.s.projects.is_empty() and g.s.recovery==0)
	var count=g.s.warriors
	g.advance(g.s.last+3600)
	assert(g.s.warriors==count)
	g.s.gold = 0
	assert(not g.start("warriors") and not g.develop())
	g.s.gold = 100
	g.s.warriors = 7
	g.s.spell = "fireball"
	assert(g.deploy() and not g.s.battle.won)
	assert(g.s.owned == 2 and g.s.warriors == 7)
	g.finish_battle()
	assert(g.start("healing"))
	g.advance(g.s.last+300)
	assert(g.s.healing and g.equip("healing"))
	var paid_gold = g.s.gold
	assert(g.equip("fireball") and g.equip("healing"))
	assert(g.s.gold == paid_gold)
	assert(g.deploy() and g.s.battle.won and g.s.owned == 3)
	g.finish_battle()
	assert(g.s.warriors == 7 and not g.deploy())
	DirAccess.remove_absolute("res://conquest/test_save.json")
	print("CONQUEST CHECKS PASSED")
	quit()
