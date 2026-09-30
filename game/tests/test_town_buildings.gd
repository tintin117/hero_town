extends RefCounted
## Town buildings and placement mode against a fake game: sprites follow building_changed, the ghost follows the
## valid callable, confirm/cancel end the mode, and no pressed/released/cell_clicked leaks out while placing.

const SCENE := "res://game/town/town.tscn"
const EVENTS := "res://game/core/events.gd"
const SIZES: Array[Vector2i] = [Vector2i(960, 270), Vector2i(1280, 368)]

var problems: Array[String] = []


class FakeDef:
	extends RefCounted
	var id: StringName
	var footprint: Vector2i

	func _init(def_id: StringName, size: Vector2i) -> void:
		id = def_id
		footprint = size


## Exposes exactly the Game members the town reads.
class FakeGame:
	extends RefCounted
	var defs: Array = [
		FakeDef.new(&"promotion_office", Vector2i(2, 2)), FakeDef.new(&"recruitment_hall", Vector2i(3, 2)),
		FakeDef.new(&"gym", Vector2i(3, 2)), FakeDef.new(&"restaurant", Vector2i(2, 2)),
	]
	var built: Dictionary = {}  ## id -> {level, cell}

	func building_defs() -> Array:
		return defs

	func building_level(id: StringName) -> int:
		return built[id].level if built.has(id) else 0

	func building_cell(id: StringName) -> Vector2i:
		return built[id].cell if built.has(id) else Vector2i.ZERO

	func building_at(cell: Vector2i) -> StringName:
		for def: FakeDef in defs:
			if built.has(def.id) and Rect2i(built[def.id].cell, def.footprint).has_point(cell):
				return def.id
		return &""

	func can_place(_id: StringName, cell: Vector2i) -> bool:
		return Rect2i(10, 0, 28, 7).has_point(cell) and not Rect2i(16, 0, 16, 8).has_point(cell)

	func put(id: StringName, level: int, cell: Vector2i) -> void:
		built[id] = {"level": level, "cell": cell}


## Town wired to a fake game and the real Events script, inside a sized host that the caller frees.
static func make_town(parent: Node, game: FakeGame, events: Object, host_size: Vector2) -> Array:
	var host := Control.new()
	host.size = host_size
	var town := (load(SCENE) as PackedScene).instantiate() as Control
	var layer := town.get_node("World/BuildingLayer/TownBuildings")
	layer.game = game
	layer.events = events
	host.add_child(town)
	parent.add_child(host)
	return [host, town]


func run() -> Array[String]:
	problems.clear()
	var events: Object = load(EVENTS).new()
	for size in SIZES:
		var game := FakeGame.new()
		var made := make_town((Engine.get_main_loop() as SceneTree).root, game, events, Vector2(size))
		var host: Control = made[0]
		var town: Control = made[1]
		var tag := str(size)
		_check_sprites(game, events, town, tag)
		_check_placement(game, town, tag)
		_check_silence(game, town, tag)
		_check_hover(game, events, town, tag)
		host.free()
	events.free()
	return problems


func _expect(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)


func _check_sprites(game: FakeGame, events: Object, town: Control, tag: String) -> void:
	var layer: Node2D = town.buildings
	_expect(layer.get_child_count() == 0, "%s: nothing built, nothing drawn" % tag)
	game.put(&"gym", 1, Vector2i(11, 1))
	events.building_changed.emit(&"gym")
	var gym: Node2D = layer.group_of(&"gym")
	_expect(gym != null and _at_cell(gym, Vector2i(11, 1)), "%s: gym sprite at its top-left cell" % tag)
	_expect(layer.get_child_count() == 1, "%s: only the changed building is drawn" % tag)
	var level_one_nodes: int = gym.get_child_count()
	game.put(&"gym", 3, Vector2i(11, 1))
	events.building_changed.emit(&"gym")
	var upgraded: Node2D = layer.group_of(&"gym")
	_expect(upgraded != gym and upgraded.get_child_count() > level_one_nodes, "%s: level 3 must add visible decorations" % tag)
	game.put(&"gym", 3, Vector2i(33, 2))
	events.building_changed.emit(&"gym")
	_expect(_at_cell(layer.group_of(&"gym"), Vector2i(33, 2)), "%s: moving a building moves its sprite" % tag)
	for id in [&"restaurant", &"recruitment_hall", &"promotion_office"]:
		game.put(id, 2, {&"restaurant": Vector2i(28, 4), &"recruitment_hall": Vector2i(33, 1), &"promotion_office": Vector2i(11, 4)}[id])
		events.building_changed.emit(id)
	_expect(layer.group_of(&"restaurant") != null and layer.group_of(&"recruitment_hall") != null, "%s: every building gets a sprite" % tag)
	var kept: Node2D = layer.group_of(&"restaurant")
	events.building_changed.emit(&"restaurant")
	_expect(layer.group_of(&"restaurant") == kept, "%s: an unchanged building is not rebuilt" % tag)
	game.built.erase(&"gym")
	events.building_changed.emit(&"gym")
	_expect(layer.group_of(&"gym") == null, "%s: an unbuilt building's sprite disappears" % tag)
	_expect(town.building_id_at(Vector2i(28, 5)) == &"restaurant", "%s: building_id_at asks the game" % tag)
	_expect(town.building_id_at(Vector2i(12, 2)) == &"", "%s: empty cell has no building" % tag)
	for id in [&"restaurant", &"recruitment_hall", &"promotion_office"]:
		game.built.erase(id)
		events.building_changed.emit(id)


func _check_placement(game: FakeGame, town: Control, tag: String) -> void:
	var confirmed: Array = []
	var cancelled: Array[int] = []
	town.placement_confirmed.connect(func(id: StringName, cell: Vector2i) -> void: confirmed.append([id, cell]))
	town.placement_cancelled.connect(func() -> void: cancelled.append(1))
	town.center_on_arena()
	var valid := func(cell: Vector2i) -> bool: return game.can_place(&"gym", cell)
	_expect(not town.placing, "%s: not placing by default" % tag)
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	_expect(town.placing and town.ghost.visible, "%s: begin_placement shows the ghost" % tag)
	_motion(town, town.point_for_cell(Vector2i(12, 2)))
	_expect(town.ghost.cell == Vector2i(12, 2) and town.ghost.ok, "%s: valid cell tints green" % tag)
	_motion(town, town.point_for_cell(Vector2i(20, 2)))
	_expect(town.ghost.cell == Vector2i(20, 2) and not town.ghost.ok, "%s: arena cell tints red" % tag)
	_motion(town, town.point_for_cell(Vector2i(20, 7)))
	_expect(not town.ghost.ok, "%s: path row is invalid" % tag)
	# Invalid click keeps the mode; valid click confirms with the right cell and ends it.
	_click(town, town.point_for_cell(Vector2i(20, 2)), MOUSE_BUTTON_LEFT)
	_expect(town.placing and confirmed.is_empty(), "%s: invalid click must not confirm" % tag)
	_click(town, town.point_for_cell(Vector2i(13, 3)), MOUSE_BUTTON_LEFT)
	_expect(confirmed == [[&"gym", Vector2i(13, 3)]], "%s: confirm reports id and cell, got %s" % [tag, confirmed])
	_expect(not town.placing and not town.ghost.visible, "%s: confirming ends placement" % tag)
	# The ghost follows scrolling without pointer movement.
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	_motion(town, town.point_for_cell(Vector2i(12, 2)))
	var pointer_cell: Vector2i = town.cell_for_point(town._pointer)
	town._scroll_by_user(town.scroll_x + 64.0 if town.max_scroll() > 64.0 else town.scroll_x)
	if town.max_scroll() > 64.0:
		_expect(town.ghost.cell == town.cell_for_point(town._pointer) and town.ghost.cell != pointer_cell, "%s: ghost must follow scroll" % tag)
	# Cancel paths.
	_click(town, Vector2(400, 100), MOUSE_BUTTON_RIGHT)
	_expect(not town.placing and cancelled.size() == 1, "%s: right click cancels" % tag)
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	town._input(esc)
	_expect(not town.placing and cancelled.size() == 2, "%s: Esc cancels" % tag)
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	town.cancel_placement()
	_expect(not town.placing and cancelled.size() == 3, "%s: cancel_placement() cancels" % tag)
	town.cancel_placement()
	_expect(cancelled.size() == 3, "%s: cancelling when idle is silent" % tag)
	# Scrolling keeps working while placing.
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	var before: float = town.scroll_x
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(-10, 0)
	drag.position = Vector2(300, 100)
	town._gui_input(drag)
	_expect(town.scroll_x == clampf(before + 10.0, 0.0, town.max_scroll()), "%s: middle drag scrolls while placing" % tag)
	town.cancel_placement()


func _check_silence(game: FakeGame, town: Control, tag: String) -> void:
	var seen: Array[String] = []
	town.pressed.connect(func(_c: Vector2i) -> void: seen.append("pressed"))
	town.released.connect(func() -> void: seen.append("released"))
	town.cell_clicked.connect(func(_c: Vector2i) -> void: seen.append("clicked"))
	var valid := func(cell: Vector2i) -> bool: return game.can_place(&"gym", cell)
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	_click(town, town.point_for_cell(Vector2i(12, 2)), MOUSE_BUTTON_LEFT)
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	_click(town, town.point_for_cell(Vector2i(20, 2)), MOUSE_BUTTON_LEFT)
	_click(town, town.point_for_cell(Vector2i(20, 2)), MOUSE_BUTTON_RIGHT)
	_expect(seen.is_empty(), "%s: no pressed/released/cell_clicked while placing, got %s" % [tag, seen])
	_click(town, town.point_for_cell(Vector2i(12, 2)), MOUSE_BUTTON_LEFT)
	_expect(seen == ["pressed", "released", "clicked"], "%s: normal clicks work again after placing, got %s" % [tag, seen])
	seen.clear()
	# A hold in progress when placement starts is released so the plant gesture cannot stick.
	town._gui_input(_button(MOUSE_BUTTON_LEFT, true, town.point_for_cell(Vector2i(20, 2))))
	town.begin_placement(&"gym", Vector2i(3, 2), valid)
	town.cancel_placement()
	_expect(seen == ["pressed", "released"], "%s: held press is released when placement begins, got %s" % [tag, seen])


func _check_hover(game: FakeGame, events: Object, town: Control, tag: String) -> void:
	game.put(&"restaurant", 1, Vector2i(30, 3))
	events.building_changed.emit(&"restaurant")
	town.center_on_arena()
	_motion(town, town.point_for_cell(Vector2i(31, 4)))
	_expect(town.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s: pointing hand over a building" % tag)
	_expect(town.buildings.group_of(&"restaurant").modulate.r > 1.0, "%s: hovered building is brightened" % tag)
	_motion(town, town.point_for_cell(Vector2i(12, 2)))
	_expect(town.mouse_default_cursor_shape == Control.CURSOR_ARROW, "%s: arrow off buildings" % tag)
	_expect(town.buildings.group_of(&"restaurant").modulate == Color.WHITE, "%s: hover highlight clears" % tag)
	game.built.erase(&"restaurant")
	events.building_changed.emit(&"restaurant")


## The pop-in tween may still be lifting the sprite up to 10 px above its resting place.
func _at_cell(group: Node2D, cell: Vector2i) -> bool:
	return group.position.x == cell.x * 32 and absf(group.position.y - cell.y * 32) <= 10.0


func _motion(town: Control, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	town._gui_input(e)


func _click(town: Control, at: Vector2, index: MouseButton) -> void:
	town._gui_input(_button(index, true, at))
	town._gui_input(_button(index, false, at))


func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = pressed
	e.position = at
	return e
