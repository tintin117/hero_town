extends RefCounted
## Town strip checks: scene structure, scroll clamping, centring, cell mapping, pointer input, no game coupling.

const SCENE := "res://game/town/town.tscn"
const SIZES: Array[Vector2i] = [Vector2i(960, 270), Vector2i(1280, 420), Vector2i(1600, 420), Vector2i(1536, 300)]

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var host := Control.new()
	host.size = Vector2(1280, 272)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var town := (load(SCENE) as PackedScene).instantiate() as Control
	host.add_child(town)
	_check_structure(town)
	_check_scroll(host, town)
	_check_centering(host, town)
	_check_cells(host, town)
	_check_pointer(host, town)
	host.free()
	_check_no_game_coupling()
	return problems


func _expect(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)


func _check_structure(town: Control) -> void:
	var slot := town.get_node_or_null("World/ArenaSlot") as Node2D
	_expect(slot != null and slot.position == Vector2(512, 0), "ArenaSlot must sit at (512, 0)")
	for path in ["World/BuildingLayer", "World/ActorLayer", "World/Terrain", "ScrollBar"]:
		_expect(town.has_node(path), "missing node %s" % path)
	_expect(town.get_node("World/Terrain").get_used_cells().size() >= 48 * 8, "terrain not filled")
	_expect(town.get_node("World/ActorLayer").get_child_count() > 0, "no ambient walkers")
	_expect(town.get_node("ScrollBar").theme != null, "scrollbar must use the game theme")


func _check_scroll(host: Control, town: Control) -> void:
	var seen: Array[float] = []
	town.scrolled.connect(func(x: float) -> void: seen.append(x))
	for s in SIZES:
		host.size = Vector2(s)
		var span := maxf(0.0, 1536.0 - s.x)
		town.center_on(-100.0)
		_expect(town.scroll_x == 0.0, "%s: left end must clamp to 0, got %s" % [s, town.scroll_x])
		town.center_on(200.0)
		_expect(town.scroll_x == span, "%s: right end must clamp to %s, got %s" % [s, span, town.scroll_x])
		_expect(town.get_node("ScrollBar").visible == (span > 0.0), "%s: scrollbar visibility" % s)
		if span == 0.0:
			_expect(town.get_node("World").position.x == (s.x - 1536) / 2.0, "%s: wide control must centre the strip" % s)
		_expect(town.get_node("World").position.y == floorf((s.y - 256) / 2.0), "%s: strip must be vertically centred" % s)
	_expect(not seen.is_empty(), "scrolled signal never fired")


func _check_centering(host: Control, town: Control) -> void:
	host.size = Vector2(1280, 272)
	town.center_on_arena()
	var arena_mid: float = town.get_node("World").position.x + town.get_node("World/ArenaSlot").position.x + 256.0
	_expect(arena_mid == 640.0, "arena must sit mid-screen at 1280 wide, got %s" % arena_mid)
	host.size = Vector2(1000, 272)  # untouched by the user, so it re-centres
	arena_mid = town.get_node("World").position.x + 768.0
	_expect(arena_mid == 500.0, "resize must re-centre the arena, got %s" % arena_mid)
	town._scroll_by_user(10.0)
	host.size = Vector2(1100, 272)
	_expect(town.scroll_x == 10.0, "user scroll must survive a resize, got %s" % town.scroll_x)
	town._scroll_by_user(400.0)
	host.size = Vector2(1300, 272)
	_expect(town.scroll_x == 236.0, "resize must re-clamp user scroll, got %s" % town.scroll_x)


func _check_cells(host: Control, town: Control) -> void:
	host.size = Vector2(1280, 272)
	for x in [0.0, 100.0, 256.0]:
		town._scroll_by_user(x)
		for c in [Vector2i(0, 0), Vector2i(47, 7), Vector2i(24, 3), Vector2i(10, 7)]:
			_expect(town.cell_for_point(town.point_for_cell(c)) == c, "cell round trip failed at scroll %s for %s" % [x, c])
	town.center_on_arena()
	_expect(town.point_for_cell(Vector2i(20, 3)) - town.point_for_cell(Vector2i(19, 3)) == Vector2(32, 0), "cells must be 32 px wide")


func _check_pointer(host: Control, town: Control) -> void:
	host.size = Vector2(1280, 272)
	town.center_on_arena()
	var clicks: Array[Vector2i] = []
	town.cell_clicked.connect(func(c: Vector2i) -> void: clicks.append(c))
	var target: Vector2 = town.point_for_cell(Vector2i(12, 3))
	town._gui_input(_button(MOUSE_BUTTON_LEFT, true, target))
	town._gui_input(_button(MOUSE_BUTTON_LEFT, false, target))
	_expect(clicks == [Vector2i(12, 3)], "click must report its cell, got %s" % [clicks])
	town._gui_input(_button(MOUSE_BUTTON_LEFT, true, target))
	town._gui_input(_button(MOUSE_BUTTON_LEFT, false, target + Vector2(40, 0)))
	_expect(clicks.size() == 1, "a drag must not count as a click")
	var before: float = town.scroll_x
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	drag.relative = Vector2(-20, 0)
	town._gui_input(drag)
	_expect(town.scroll_x == before + 20.0, "middle drag must scroll")
	var wheel := _button(MOUSE_BUTTON_WHEEL_DOWN, true, target)
	wheel.shift_pressed = true
	town._gui_input(wheel)
	_expect(town.scroll_x == minf(before + 20.0 + 96.0, 256.0), "shift+wheel must scroll, got %s" % town.scroll_x)
	wheel.shift_pressed = false
	var at: float = town.scroll_x
	town._gui_input(wheel)
	_expect(town.scroll_x == at, "plain wheel must not scroll the strip")


func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = pressed
	e.position = at
	return e


func _check_no_game_coupling() -> void:
	var dir := DirAccess.open("res://game/town")
	var pattern := RegEx.create_from_string("\\b(Game|Events)\\b")
	for file in dir.get_files():
		if file.ends_with(".gd") and file != "town_buildings.gd":  # the one view script that reads the game
			var source := FileAccess.get_file_as_string("res://game/town/" + file)
			_expect(pattern.search(source) == null, "%s must not reference Game or Events" % file)
