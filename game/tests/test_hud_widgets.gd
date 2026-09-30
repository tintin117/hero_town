extends RefCounted
## HUD: builds, its widgets follow Events, the Book button obeys the game state, fights drive bars and toasts.
## The HUD gets its own Game/Events (core_kit) through the `game` / `events` vars, since --script has no autoloads.

const Kit := preload("res://game/tests/core_kit.gd")
const HUD := "res://game/ui/hud.tscn"

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var fake := Kit.FakeSim.new()
	var g: Node = Kit.game(fake)
	g.new_game()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 420)
	(Engine.get_main_loop() as SceneTree).root.add_child(vp)
	var hud: Control = (load(HUD) as PackedScene).instantiate()
	hud.game = g
	hud.events = g.events
	vp.add_child(hud)

	_builds(hud, g)
	_widgets_follow_signals(hud, g)
	_book_button(hud, g, fake)
	_fight(hud, g)
	vp.free()
	Kit.dispose(g)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _builds(hud: Control, g: Node) -> void:
	_check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD root must not eat mouse input")
	for path in ["Layout", "Layout/Middle", "%Drawers", "%Toasts", "%Excitement"]:
		_check((hud.get_node(path) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s must ignore the mouse" % path)
	_check(hud.get_node("%Cards").get_child_count() == g.state.preferred_lineup.size(), "one hero card per preferred fighter")
	_check(not hud.get_node("%Excitement").visible, "excitement gauge is hidden while idle")
	for locked in ["%Build", "%Stories"]:
		_check(hud.get_node(locked).disabled and hud.get_node(locked).tooltip_text.contains("coming soon"), "%s is locked" % locked)
	var roster_exists := ResourceLoader.exists("res://game/ui/drawers/roster_drawer.tscn")
	_check(hud.get_node("%Roster").disabled == not roster_exists, "Roster button follows the roster drawer's existence")
	_check(hud.get_node("%Text").text.contains("hype 70"), "bell shows the hype target: %s" % hud.get_node("%Text").text)
	_check(hud.get_node("%Seats").text == "%d/100" % g.attendance_if_booked_now(), "seats pill shows the crowd now: %s" % hud.get_node("%Seats").text)


func _widgets_follow_signals(hud: Control, g: Node) -> void:
	g.state.gold = 500
	g.events.gold_changed.emit(500, 500)
	_check(int(hud.get_node("%Gold").value) == 500, "gold pill follows gold_changed")
	g.events.hype_changed.emit(55.0)
	_check(Kit.near(hud.get_node("%Hype").value, 55.0), "hype gauge follows hype_changed")
	_check(Kit.near(hud.get_node("%Hype").threshold, 70.0), "threshold marker shows the bell target from the start")
	g.set_manager(true, 60.0)
	_check(Kit.near(hud.get_node("%Hype").threshold, 60.0), "threshold marker follows manager_changed")
	_check(hud.get_node("%ManagerCaption").text == "Auto 60", "manager caption shows the threshold")
	g.set_manager(false, 60.0)
	_check(hud.get_node("%Hype").threshold < 0.0, "marker hides when the manager is turned off")
	g.state.fame_points = 350
	g.events.fame_changed.emit(350, 1)
	_check(hud.get_node("%Fame").text == "Local Arena", "fame pill shows the tier name")
	_check(Kit.near(hud.get_node("%Fame").progress, 50.0 / 2700.0, 0.001), "fame pill shows progress to the next tier")
	g.state.hype = 100.0
	g.events.hype_changed.emit(100.0)
	_check(hud.get_node("%Seats").text == "100/100", "seats pill follows hype (full house)")


func _book_button(hud: Control, g: Node, fake: Object) -> void:
	var text: Label = hud.get_node("%Text")
	g.state.manager.enabled = false
	g.events.manager_changed.emit()
	_check(text.text == "Bell off", "bell status when the auto bell is off: %s" % text.text)
	g.state.manager.enabled = true
	g.events.manager_changed.emit()
	_check(g.book_fight(g.state.preferred_lineup), "the bell (manager) starts the series")
	_check(fake.calls == 1 and not g.fight.is_empty(), "the series plays its first bout")
	_check(fake.last_lineup.size() == g.state.preferred_lineup.size(), "the whole preferred lineup fights")
	_check(text.text.begins_with("Bout 1"), "bell status shows the bout during a series: %s" % text.text)
	_check(hud.get_node("%Seats").text == "100/100", "seats pill shows the locked crowd")
	_check(not g.book_fight(g.state.preferred_lineup), "no second bell during a series")


func _fight(hud: Control, g: Node) -> void:
	var excitement: ExcitementGauge = hud.get_node("%Excitement")
	_check(excitement.visible and Kit.near(excitement.value, 0.0), "excitement gauge appears at fight start, reset")
	var bram: HeroCard = hud.get_node("%Cards").get_child(0)
	var ivo: HeroCard = hud.get_node("%Cards").get_child(1)
	var ivo_hp: int = Roster.stats_for(g.hero_defs[1], 1, g.tuning).health
	g.events.combat_event.emit({"kind": &"attack", "attacker": 0, "hits": [{"target": 1, "damage": ivo_hp / 2, "position": Vector2.ZERO}],
			"healing": 0, "excitement": 30.0})
	_check(Kit.near(ivo.hp, float(ivo_hp - ivo_hp / 2) / ivo_hp, 0.01), "victim HP follows hits: %f" % ivo.hp)
	_check(Kit.near(bram.mana, 0.25, 0.01) and Kit.near(ivo.mana, 0.15, 0.01), "mana follows attacks (25 / 15)")
	_check(Kit.near(excitement.value, 30.0) and excitement.multiplier_text == "x1.25", "excitement follows combat events")
	g.events.combat_event.emit({"kind": &"skill", "attacker": 0, "hits": [{"target": 1, "damage": ivo_hp, "position": Vector2.ZERO}],
			"healing": 0, "excitement": 70.0})
	_check(Kit.near(ivo.hp, 0.0) and Kit.near(bram.mana, 0.0), "a skill empties the caster's mana and can drop HP to 0")
	var log := Kit.record(g.events)
	for i in 20:
		g.advance(0.5)
	_check(Kit.count(log, "finished") == 1, "fight settled")
	_check(not excitement.visible, "excitement gauge hides after the fight")
	_check(Kit.near(ivo.hp, 1.0) and Kit.near(bram.mana, 0.0), "idle cards return to full HP and empty mana")
	var toasts: Control = hud.get_node("%Toasts")
	_check(toasts.get_child_count() == 2, "a bout summary toast and a series toast appear")
	if toasts.get_child_count() > 0:
		var text: String = toasts.get_child(0).text
		_check(text.contains("Bram") and text.contains("gold") and text.contains("fame") and text.contains("x1.25"), "summary toast content: %s" % text)
	g.events.toast.emit("Hello", &"fame")
	_check(toasts.get_child_count() == 3, "Events.toast makes a toast")
	_check(hud.get_node("%Text").text.contains("hype"), "bell shows the hype target again after the series")
