extends RefCounted
## HUD layout at 960x420, 1280x420 and 1600x560: bars keep their height, nothing overlaps or leaves the window,
## the bell status stays visible with a full 5-fighter lineup, and drawers fit between the bars.

const Kit := preload("res://game/tests/core_kit.gd")
const Stories := preload("res://game/tests/fake_stories.gd")
const SIZES: Array[Vector2i] = [Vector2i(960, 420), Vector2i(1280, 420), Vector2i(1600, 560)]

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	for size in SIZES:
		_at_size(size)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _kids(n: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in n.get_children():
		if c is Control and c.visible:
			out.append(c)
	return out


func _no_overlap(items: Array[Control], label: String) -> void:
	for i in items.size():
		for j in range(i + 1, items.size()):
			var hit := items[i].get_global_rect().intersection(items[j].get_global_rect())
			if hit.size.x > 1.0 and hit.size.y > 1.0:
				problems.append("%s: %s overlaps %s" % [label, items[i].name, items[j].name])


func _inside(items: Array[Control], window: Rect2, label: String) -> void:
	for c in items:
		if not window.grow(0.5).encloses(c.get_global_rect()):
			problems.append("%s: %s outside the window: %s" % [label, c.name, c.get_global_rect()])


func _at_size(size: Vector2i) -> void:
	var g: Node = Stories.make()
	g.new_game()
	for id in range(2, 5):  # all five fighters owned, so the lineup can be full
		g.state.heroes[id].owned = true
	g.state.fighter_tier = 3
	g.state.preferred_lineup = [0, 1, 2, 3, 4] as Array[int]
	g.state.gold = 1234567
	g.state.fame_points = 30000
	g.state.manager = {"enabled": true, "threshold": 70.0}
	var vp := SubViewport.new()
	vp.size = size
	(Engine.get_main_loop() as SceneTree).root.add_child(vp)
	var hud: Control = (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.game = g
	hud.events = g.events
	vp.add_child(hud)
	g.book_fight(g.state.preferred_lineup)  # excitement gauge visible too
	g.events.combat_event.emit({"kind": &"attack", "attacker": 0, "hits": [], "excitement": 70.0})
	for i in 3:
		_layout(hud)
	var label := str(size)
	var window := Rect2(Vector2.ZERO, Vector2(size))
	var top: Control = hud.get_node("Layout/TopBar")
	var middle: Control = hud.get_node("Layout/Middle")
	_check(top.size.y <= 60.0, "%s: the top bar keeps its height (%s)" % [label, top.size.y])
	_check(middle.size.y >= 300.0, "%s: room left for the town (%s)" % [label, middle.size.y])
	_no_overlap(_kids(hud.get_node("Layout/TopBar/Row")), "%s top bar" % label)
	_inside(_kids(hud.get_node("Layout/TopBar/Row")), top.get_global_rect(), "%s top bar" % label)
	var tools: Control = hud.get_node("Layout/Middle/Tools")
	var controls: Array[Control] = [hud.get_node("Layout/Middle/Status"), hud.get_node("%Action"), tools, hud.get_node("%Excitement")]
	_no_overlap(controls, "%s town controls" % label)
	_inside(controls, middle.get_global_rect(), "%s town controls" % label)
	_no_overlap(_kids(tools), "%s tool buttons" % label)
	_inside(_kids(tools), tools.get_global_rect(), "%s tool buttons" % label)
	_check(hud.get_node("%Excitement").visible, "%s: excitement gauge visible in a fight" % label)
	_inside([hud.get_node("%Text")] as Array[Control], controls[0].get_global_rect(), "%s status text" % label)
	var drawer: Drawer = load("res://game/ui/drawers/manager_drawer.tscn").instantiate()
	_check(drawer.panel_size.y + 2.0 * drawer.margin <= middle.size.y and drawer.panel_size.x + 2.0 * drawer.margin <= size.x,
			"%s: the manager drawer fits between the bars" % label)
	drawer.free()
	var menu: Control = load("res://game/ui/main_menu.tscn").instantiate()
	menu.game = g
	vp.add_child(menu)
	for i in 3:
		_layout(menu)
	var row: Control = menu.get_node("Center/Row")
	_inside([row], window, "%s menu row" % label)
	_no_overlap(_kids(row), "%s menu columns" % label)
	var buttons: Array[Control] = [menu.get_node("%NewGame"), menu.get_node("%Continue"), menu.get_node("%Quit")]
	_no_overlap(buttons, "%s menu buttons" % label)
	_inside(buttons, row.get_global_rect(), "%s menu buttons" % label)
	vp.free()
	Kit.dispose(g)
