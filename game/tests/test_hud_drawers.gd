extends RefCounted
## Drawer router (one at a time, ESC / right click, never pauses) and the manager drawer (writes through Game.set_manager).

const Kit := preload("res://game/tests/core_kit.gd")
const MANAGER := "res://game/ui/drawers/manager_drawer.tscn"
const PLAIN := "res://game/ui/components/drawer.tscn"

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var g: Node = Kit.game(Kit.FakeSim.new())
	g.new_game()
	var host := Control.new()
	host.size = Vector2(960, 272)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var router := DrawerRouter.new()
	router.host = host
	router.context = {"game": g, "events": g.events}
	router.register(&"manager", MANAGER)
	router.register(&"plain", PLAIN)
	router.register(&"missing", "res://game/ui/drawers/nope.tscn")
	host.add_child(router)
	_router(router, host, g)
	_manager_drawer(router, host, g)
	host.free()
	Kit.dispose(g)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _open_count(host: Control) -> int:
	return host.get_children().filter(func(c: Node) -> bool: return c is Drawer and c.is_open).size()


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _router(router: DrawerRouter, host: Control, g: Node) -> void:
	var log: Array = []
	router.drawer_changed.connect(func(key: StringName) -> void: log.append(key))
	_check(not router.open(&"missing") and not router.open(&"unknown"), "unknown or missing drawers do not open")
	_check(router.open(&"manager") and router.current == &"manager", "manager opens")
	_check(router.open(&"plain") and router.current == &"plain", "plain opens")
	_check(_open_count(host) == 1, "opening a drawer closes the other one")
	_check(log == [&"manager", &"plain"], "drawer_changed sequence: %s" % [log])
	_check(not g.paused, "opening a drawer never pauses the sim")
	router._unhandled_input(_key(KEY_ESCAPE))
	_check(router.current == &"" and _open_count(host) == 0, "ESC closes the open drawer")
	_check(log.back() == &"", "drawer_changed reports the close")
	router.open(&"manager")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	router._unhandled_input(click)
	_check(router.current == &"", "right click closes the open drawer")
	router.open(&"plain")
	host.get_children().filter(func(c: Node) -> bool: return c is Drawer and c.is_open)[0].close()  # like its own X button
	_check(router.current == &"", "closing the drawer itself clears the router")
	router.open(&"manager")
	router.open(&"manager")
	_check(_open_count(host) == 1 and host.get_child_count() == 3, "reopening reuses the lazily created instance")
	router.close()


func _manager_drawer(router: DrawerRouter, host: Control, g: Node) -> void:
	router.open(&"manager")
	var drawer: Drawer = host.get_child(1)
	var toggle: CheckButton = drawer.get_node("%Toggle")
	var slider: HSlider = drawer.get_node("%Slider")
	var estimate: Label = drawer.get_node("%Estimate")
	_check(toggle.button_pressed and Kit.near(slider.value, 70.0), "drawer starts from Game.state.manager (on, 70)")
	toggle.button_pressed = false
	toggle.button_pressed = true
	_check(g.state.manager.enabled, "toggle calls set_manager(true, ...)")
	slider.value = 55.0
	_check(Kit.near(g.state.manager.threshold, 55.0) and g.state.manager.enabled, "slider commits the threshold")
	g.state.hype = 15.0
	g.events.hype_changed.emit(15.0)
	# 40 s * ln((100 - 15) / (100 - 55)) = 25.4 -> 26 (the drawer rounds up)
	_check(estimate.text == "Bell in ~26 s", "estimate from the hype curve: %s" % estimate.text)
	g.state.hype = 60.0
	g.events.hype_changed.emit(60.0)
	_check(estimate.text == "Bell rings now.", "estimate at/above the threshold: %s" % estimate.text)
	g.set_manager(false, 80.0)
	_check(not toggle.button_pressed and Kit.near(slider.value, 80.0), "drawer follows manager_changed")
	_check(estimate.text.contains("off"), "estimate says the manager is off: %s" % estimate.text)
	toggle.button_pressed = true
	_check(g.state.manager == {"enabled": true, "threshold": 80.0}, "toggle keeps the threshold")
	router.close()
