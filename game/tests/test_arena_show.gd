extends RefCounted
## The arena's series show: main-event banner, props, team clarity, dead-fighter cleanup, popup
## cap and the crowd mood, driven by hand-made Events (old and new payloads) and one real fight.

const Kit := preload("res://game/tests/core_kit.gd")
const ArenaScene := preload("res://game/combat/arena.tscn")
const DT := 1.0 / 60.0
const PROPS: Array[StringName] = [&"fireworks", &"announcer", &"spotlights", &"ringside_bar"]
const EVENT := {"id": 3, "kind": "rivalry", "title": "Iron vs Ember", "ripeness": 0.9, "multiplier": 2.6}


func run() -> Array[String]:
	var problems: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = Kit.game()
	g.new_game()
	g.state.hype = 100.0
	for hero in g.state.heroes:
		hero.owned = true
	g.state.fighter_tier = 3
	var arena: Node2D = ArenaScene.instantiate()
	arena.game = g
	tree.root.add_child(arena)
	var show: Node2D = arena.get_node("Show")

	_old_payload(problems, g, arena, show)
	_main_event(problems, g, arena, show)
	_props(problems, g, arena, show)
	_bar_coins(problems, g, arena, show)
	_popups(problems, arena)
	_real_fight(problems, g, arena, show)
	_new_game_mid_series(problems, g, arena, show)

	arena.free()
	Kit.dispose(g)
	return problems


## Emulates the bell for a series: Game.series is what the arena checks for "still running".
func _bell(g: Node, info: Dictionary) -> void:
	g.series = {"lineup": [0, 1] as Array[int], "attendance": 60, "seats": 100, "wins": {}, "bout": 0, "pause": 3.0}
	var payload := {"lineup": [0, 1] as Array[int], "attendance": 60, "seats": 100, "wins_needed": 3}
	payload.merge(info)
	g.events.series_started.emit(payload)


func _end(g: Node, winner := -1) -> void:
	g.series = {}
	g.events.series_finished.emit({"winner": winner, "wins": {}, "bouts": 3, "fame_bonus": 0, "lineup": [0, 1]})


func _old_payload(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	_bell(g, {})  # no main_event, no prop: the pre-G4 payload
	Kit.check(problems, not show.banner_visible(), "old payload: no banner")
	Kit.check(problems, not show.props_running() and show.prop == &"", "old payload: no prop")
	_run(arena, 0.5)
	Kit.check(problems, arena.show_active(), "old payload: the series still counts as running")
	_end(g)
	Kit.check(problems, not arena.show_active(), "series_finished ends the show")
	_bell(g, {"main_event": {}, "prop": &""})
	Kit.check(problems, not show.banner_visible(), "empty main_event: no banner")
	_end(g)


func _main_event(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	_bell(g, {"main_event": EVENT})
	Kit.check(problems, show.banner_visible(), "main event: banner appears at the bell")
	_run(arena, 1.5)
	Kit.check(problems, show.banner_visible(), "main event: banner still up after 1.5 s")
	_run(arena, 2.0)
	Kit.check(problems, not show.banner_visible(), "main event: banner gone after ~3 s")
	_end(g)
	_bell(g, {"main_event": EVENT})
	_end(g)
	Kit.check(problems, not show.banner_visible(), "main event: banner cleared when the series ends")


func _props(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	var fx: Node2D = arena.get_node("Fx")
	for prop in PROPS:
		_bell(g, {"prop": prop})
		Kit.check(problems, show.prop == prop and show.props_running(), "%s starts at the bell" % prop)
		_run(arena, 3.0)
		if prop == &"fireworks":
			Kit.check(problems, fx.get_child_count() > 0, "fireworks pop into bursts")
		if prop == &"announcer":
			Kit.check(problems, arena.get_node("Crowd").loud > 1.0, "announcer makes the crowd louder")
		_end(g)
		Kit.check(problems, not show.props_running() and show.prop == &"", "%s stops with the series" % prop)
		Kit.check(problems, is_equal_approx(arena.get_node("Crowd").loud, 1.0), "%s: crowd back to normal volume" % prop)
	_bell(g, {})
	_run(arena, 0.1)
	Kit.check(problems, arena.get_node("Crowd").murmur, "the crowd murmurs between bouts of a running series")
	_end(g)
	_run(arena, 0.1)
	Kit.check(problems, not arena.get_node("Crowd").murmur, "no murmur once the series is over")
	_bell(g, {"prop": &"bogus"})  # unknown props are harmless
	_run(arena, 1.0)
	_end(g)
	_bell(g, {"prop": null, "main_event": null})
	_end(g)


func _bar_coins(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	var bar: Node2D = arena.get_node("Show/Bar")
	Kit.check(problems, not bar.visible, "bar stall hidden without the prop")
	_bell(g, {"prop": &"ringside_bar"})
	Kit.check(problems, bar.visible, "bar stall shows with the prop")
	g.events.fight_finished.emit({"winner": -1, "concessions": 60})
	Kit.check(problems, not bar._coins.is_empty(), "paid concessions throw coins")
	_run(arena, 3.0)
	Kit.check(problems, bar._coins.is_empty(), "coins fade away")
	_end(g)
	Kit.check(problems, not bar.visible, "bar stall hidden after the series")


func _popups(problems: Array[String], arena: Node2D) -> void:
	var fx: Node2D = arena.get_node("Fx")
	fx.clear()
	for i in 6:
		fx.text(str(10 + i), Vector2(256, 100), fx.CREAM, 16, 0.6)
	var rects: Array[Rect2] = []
	for child in fx.get_children():
		if child is Label:
			rects.append(Rect2(child.position, child.get_minimum_size()))
	var overlap := false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			overlap = overlap or rects[i].intersects(rects[j])
	Kit.check(problems, not overlap, "simultaneous popups do not overlap")
	for i in 40:
		fx.text("+%d" % i, Vector2(256 + i, 90), fx.GOLD, 16, 0.6)
	var labels := fx.get_children().filter(func(node: Node) -> bool: return node is Label and not node.is_queued_for_deletion())
	Kit.check(problems, labels.size() <= fx.MAX_POPUPS, "popups capped at %d (got %d)" % [fx.MAX_POPUPS, labels.size()])
	fx.clear()


func _real_fight(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	g.state.hype = 100.0
	var lineup: Array[int] = [0, 1, 2, 3, 5]
	g.set_preferred_lineup(lineup)
	var finished: Array = []
	g.events.series_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	Kit.check(problems, g.book_fight(lineup, {"seed": 11, "prop": &"spotlights"}), "book five fighters")
	Kit.check(problems, arena.fighter_count() == 5, "five fighters at the bell")
	var teams := {}
	for fighter in arena._fighters.values():
		teams[fighter.team_color()] = true
	Kit.check(problems, teams.size() == 2, "both teams have their own colour")
	var fewest := 5
	var steps := 0
	while not g.fight.is_empty() and steps < 60 * 300:
		g.advance(DT)
		arena._process(DT)
		fewest = mini(fewest, arena.fighter_count())
		steps += 1
	Kit.check(problems, fewest < 5, "fallen fighters are removed during the fight (fewest %d)" % fewest)
	Kit.check(problems, arena.fighter_count() >= 1, "the winner stays")
	Kit.check(problems, finished.size() == 1, "series finished once")
	if not finished.is_empty() and int(finished[0].winner) >= 0:
		var winner = arena._fighters.get(int(finished[0].winner))
		Kit.check(problems, winner != null and winner.crowned, "the series winner is crowned")
	Kit.check(problems, not show.props_running(), "props gone after the series")
	_run(arena, 4.0)
	Kit.check(problems, arena.fighter_count() == 5, "idle lineup restored, fighters back on their spots")
	for fighter in arena._fighters.values():
		Kit.check(problems, fighter.position.distance_to(fighter.home) < 2.0 and not fighter.crowned, "%s is back home, uncrowned" % fighter.hero_name)


func _new_game_mid_series(problems: Array[String], g: Node, arena: Node2D, show: Node2D) -> void:
	g.state.hype = 100.0
	g.state.heroes[0].owned = true
	g.state.heroes[1].owned = true
	g.set_preferred_lineup([0, 1] as Array[int])
	g.book_fight([0, 1] as Array[int], {"seed": 5, "prop": &"fireworks"})
	# The running Game may not carry the new keys yet: replay the bell with them.
	g.events.series_started.emit({"lineup": [0, 1], "attendance": 100, "seats": 100, "wins_needed": 3, "prop": &"fireworks", "main_event": EVENT})
	for i in 90:
		g.advance(DT)
		arena._process(DT)
	Kit.check(problems, arena.is_fighting() and show.props_running() and show.banner_visible(), "series running with its show")
	g.new_game()
	_run(arena, 0.2)
	Kit.check(problems, not arena.is_fighting() and not arena.show_active(), "new_game mid-series stops the show")
	Kit.check(problems, not show.props_running() and not show.banner_visible(), "new_game clears props and banner")
	Kit.check(problems, arena.fighter_count() == g.state.preferred_lineup.size(), "idle lineup after new_game")


func _run(arena: Node2D, seconds: float) -> void:
	for i in int(seconds / DT):
		arena._process(DT)
