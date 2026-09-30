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
	_check(not hud.get_node("%Excitement").visible, "excitement gauge is hidden while idle")
	for locked in ["%Build", "%Stories"]:
		_check(hud.get_node(locked).disabled and hud.get_node(locked).tooltip_text.contains("coming soon"), "%s is locked" % locked)
	var roster_exists := ResourceLoader.exists("res://game/ui/drawers/roster_drawer.tscn")
	_check(hud.get_node("%Roster").disabled == not roster_exists, "Roster button follows the roster drawer's existence")
	_check(hud.get_node("%Bell").text.contains("plant") and not hud.get_node("%Bell").disabled, "the plant button is ready: %s" % hud.get_node("%Bell").text)
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
	var bell: Button = hud.get_node("%Bell")
	g.state.manager.enabled = false
	g.events.manager_changed.emit()
	_check(bell.text == "Bell off" and bell.disabled, "bell status when the auto bell is off: %s" % bell.text)
	g.state.manager.enabled = true
	g.events.manager_changed.emit()
	bell.button_down.emit()  # hold to plant
	hud._process(hud.HOLD_TIME * 0.5)
	_check(g.planted.is_empty() and hud.get_node("%Fill").value > 0.4, "holding fills the bar without planting yet")
	bell.button_up.emit()
	_check(g.planted.is_empty() and hud.get_node("%Fill").value == 0.0, "releasing early cancels the plant")
	bell.button_down.emit()
	hud._process(hud.HOLD_TIME + 0.01)
	_check(g.planted == g.state.preferred_lineup and bell.text.begins_with("Growing"), "a full hold plants: %s" % bell.text)
	_check(g.book_fight(g.planted), "the bell starts the series")
	_check(fake.calls == 1 and not g.fight.is_empty(), "the series plays its first bout")
	_check(fake.last_lineup.size() == g.state.preferred_lineup.size(), "the whole preferred lineup fights")
	_check(bell.text.begins_with("Bout 1"), "bell status shows the bout during a series: %s" % bell.text)
	_check(hud.get_node("%Seats").text == "100/100", "seats pill shows the locked crowd")
	_check(not g.book_fight(g.state.preferred_lineup), "no second bell during a series")


func _fight(hud: Control, g: Node) -> void:
	var excitement: ExcitementGauge = hud.get_node("%Excitement")
	_check(excitement.visible and Kit.near(excitement.value, 0.0), "excitement gauge appears at fight start, reset")
	g.events.combat_event.emit({"kind": &"attack", "attacker": 0, "hits": [{"target": 1, "damage": 40, "position": Vector2.ZERO}],
			"healing": 0, "excitement": 30.0})
	_check(Kit.near(excitement.value, 30.0) and excitement.multiplier_text == "x1.25", "excitement follows combat events")
	g.events.combat_event.emit({"kind": &"skill", "attacker": 0, "hits": [{"target": 1, "damage": 999, "position": Vector2.ZERO}],
			"healing": 0, "excitement": 70.0})
	var log := Kit.record(g.events)
	for i in 20:
		g.advance(0.5)
	_check(Kit.count(log, "finished") == 1, "fight settled")
	_check(not excitement.visible, "excitement gauge hides after the fight")
	var toasts: Control = hud.get_node("%Toasts")
	_check(toasts.get_child_count() == 2, "a bout summary toast and a series toast appear")
	if toasts.get_child_count() > 0:
		var text: String = toasts.get_child(0).text
		_check(text.contains("Bram") and text.contains("gold") and text.contains("fame") and text.contains("x1.25"), "summary toast content: %s" % text)
	g.events.toast.emit("Hello", &"fame")
	_check(toasts.get_child_count() == 3, "Events.toast makes a toast")
	_check(hud.get_node("%Bell").text.contains("plant"), "the plant button is ready again after the series")
