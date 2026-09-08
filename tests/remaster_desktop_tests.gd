extends Node

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("DESKTOP TEST: " + message)

func frames(count: int = 8) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	if not GameState.is_test_session() or DisplayServer.get_name() == "headless":
		push_error("Desktop tests need a native display and -- --test.")
		get_tree().quit(1)
		return
	GameState.persistence_enabled = false
	GameState.settings.always_on_top = false
	GameState.settings.volume = 0.0
	var town := preload("res://scenes/town_2d.tscn").instantiate()
	get_tree().root.add_child.call_deferred(town)
	await frames()
	get_tree().current_scene = town
	var window := get_tree().root
	var previous_size := window.size
	var previous_position := window.position
	town.desktop.set_compact(true)
	await frames()
	check(window.size.y == 260, "Companion opens at 260 pixels")
	check(window.borderless, "Companion uses borderless window")
	check(window.transparent and window.transparent_bg, "Companion enables native and viewport transparency")
	check(window.get_texture().get_image().get_pixel(0,0).a == 0, "Outer pixels are transparent")
	check(not Geometry2D.is_point_in_polygon(Vector2(10,10), window.mouse_passthrough_polygon), "Outer empty area is excluded from native mouse region")
	check(Geometry2D.is_point_in_polygon(Vector2(window.size.x * 0.5, window.size.y - 25), window.mouse_passthrough_polygon), "Controls remain inside native mouse region")
	var compact_size := window.size
	var compact_position := window.position
	town.hud.open_build()
	await frames()
	check(window.size.y >= 620, "Management expands same native window")
	check(window.mouse_passthrough_polygon.is_empty(), "Management restores full-window interaction")
	check(town.hud.panel.get_rect().end.y <= town.hud.get_viewport_rect().size.y, "Expanded panel fits")
	town.hud.close_panel()
	await frames()
	check(window.size == compact_size and window.position == compact_position, "Closing management restores window size and position")
	town.desktop.open_overlay()
	town.desktop.open_overlay()
	town.desktop.close_overlay()
	await frames()
	check(window.size == compact_size, "Nested panel requests do not overwrite restoration state")
	town.desktop.resize_compact(300)
	await frames()
	check(window.size.y == 300 and GameState.settings.compact_height == 300, "Companion height is adjustable and saved in settings")
	town.desktop.set_compact(false)
	await frames()
	check(window.size == previous_size, "Expanded play restores prior game size")
	check(not window.transparent and not window.transparent_bg, "Full-window play restores opaque rendering")
	check(window.mouse_passthrough_polygon.is_empty(), "Full-window play restores rectangular input")
	check(window.position.distance_to(previous_position) < 8, "Expanded play restores prior position")
	GameState.update_setting("always_on_top", true)
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), "Always-on-top setting reaches the OS")
	GameState.update_setting("always_on_top", false)
	check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP), "Always-on-top can be disabled")
	for scale_factor in [1.0, 1.25, 1.5]:
		window.content_scale_factor = scale_factor
		await frames()
		var size_now: Vector2 = town.hud.get_viewport_rect().size
		check(town.hud.top.get_rect().end.x <= size_now.x + 1, "Top controls fit at scale %.2f" % scale_factor)
	window.content_scale_factor = 1
	print("DESKTOP TESTS: %d checks, %d failures; renderer=%s" % [checks, failures, RenderingServer.get_current_rendering_method()])
	GameState.request_quit(1 if failures else 0)
