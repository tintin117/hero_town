extends RefCounted
## Main menu (New Game / Continue / Quit, overwrite confirmation) and pause menu (pauses, saves, signals).

const Kit := preload("res://game/tests/core_kit.gd")
const Stories := preload("res://game/tests/fake_stories.gd")

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var g: Node = Stories.make()
	g.new_game()
	Kit.clear_save_files(g.save_path)
	_main_menu(g)
	_pause_menu(g)
	_hud_pause(g)
	Kit.clear_save_files(g.save_path)
	Kit.dispose(g)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _add(scene: String, g: Node) -> Control:
	var node: Control = (load(scene) as PackedScene).instantiate()
	node.game = g
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	return node


func _esc() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _main_menu(g: Node) -> void:
	var menu := _add("res://game/ui/main_menu.tscn", g)
	var log: Array = []
	menu.new_game_requested.connect(func() -> void: log.append("new"))
	menu.continue_requested.connect(func() -> void: log.append("continue"))
	menu.quit_requested.connect(func() -> void: log.append("quit"))
	var cont: Button = menu.get_node("%Continue")
	var confirm: Control = menu.get_node("%Confirm")
	_check(cont.disabled and cont.tooltip_text != "", "Continue is disabled with a tooltip when there is no save")
	menu.get_node("%NewGame").pressed.emit()
	_check(log == ["new"] and not confirm.visible, "New Game goes straight through without a save")
	g.save()
	menu.refresh()
	_check(not cont.disabled, "Continue enables once a valid save exists")
	cont.pressed.emit()
	menu.get_node("%NewGame").pressed.emit()
	_check(confirm.visible and log == ["new", "continue"], "New Game asks for confirmation when a save exists")
	menu.get_node("%Cancel").pressed.emit()
	_check(not confirm.visible and log.size() == 2, "Cancel keeps the save and closes the panel")
	menu.get_node("%NewGame").pressed.emit()
	menu.get_node("%Replace").pressed.emit()
	_check(log.back() == "new" and log.size() == 3 and not confirm.visible, "confirming replaces the save")
	menu.get_node("%Quit").pressed.emit()
	_check(log.back() == "quit", "Quit emits quit_requested")
	menu.free()
	# a corrupt save must not enable Continue
	Kit.clear_save_files(g.save_path)
	var file := FileAccess.open(g.save_path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	menu = _add("res://game/ui/main_menu.tscn", g)
	_check(menu.get_node("%Continue").disabled, "a corrupt save does not enable Continue")
	menu.free()
	Kit.clear_save_files(g.save_path)


func _pause_menu(g: Node) -> void:
	var menu := _add("res://game/ui/pause_menu.tscn", g)
	var log: Array = []
	menu.main_menu_requested.connect(func() -> void: log.append("menu"))
	menu.quit_requested.connect(func() -> void: log.append("quit"))
	_check(not menu.visible and not g.paused, "pause menu starts closed")
	menu.open()
	_check(menu.visible and g.paused, "opening the pause menu pauses the game")
	menu.get_node("%Resume").pressed.emit()
	_check(not menu.visible and not g.paused, "Resume unpauses")
	menu.open()
	menu._unhandled_input(_esc())
	_check(not g.paused and not menu.visible, "ESC resumes")
	menu.open()
	menu.get_node("%SaveMenu").pressed.emit()
	_check(log == ["menu"] and not g.paused, "Save & Main Menu emits main_menu_requested and leaves the game unpaused")
	_check(FileAccess.file_exists(g.save_path), "Save & Main Menu writes the save")
	menu.get_node("%Quit").pressed.emit()
	_check(log.back() == "quit", "Quit emits quit_requested")
	menu.free()


func _hud_pause(g: Node) -> void:
	var hud: Control = (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.game = g
	hud.events = g.events
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var log: Array = []
	hud.main_menu_requested.connect(func() -> void: log.append("menu"))
	hud.get_node("%Menu").pressed.emit()
	_check(g.paused and hud.get_node("%PauseMenu").visible, "the gear opens the pause menu and pauses")
	hud.get_node("%PauseMenu").get_node("%SaveMenu").pressed.emit()
	_check(log == ["menu"] and not g.paused, "the HUD forwards main_menu_requested")
	hud.router.open(&"manager")
	hud._unhandled_input(_esc())
	_check(not g.paused, "ESC with a drawer open does not open the pause menu")
	hud.router.close()
	hud._unhandled_input(_esc())
	_check(g.paused, "ESC with no drawer open opens the pause menu")
	hud.get_node("%PauseMenu").close()
	hud.free()
