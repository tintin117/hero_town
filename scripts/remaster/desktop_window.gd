class_name DesktopWindow
extends Node

var overlay_state: Dictionary = {}
var full_state: Dictionary = {}
var compact_size := Vector2i(1280, 260)

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i.ZERO
	compact_size.y = GameState.settings.compact_height
	if DisplayServer.get_name() != "headless": get_tree().root.min_size = Vector2i(960, 540)
	GameState.settings_changed.connect(apply_settings)
	apply_settings()
	if GameState.settings.compact: set_compact(true)

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, GameState.settings.volume)))
	AudioServer.set_bus_mute(0, GameState.settings.volume <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, GameState.settings.always_on_top)
	Engine.max_fps = 60

func toggle() -> void:
	close_overlay()
	set_compact(not GameState.settings.compact)

func set_compact(value: bool) -> void:
	var window := get_tree().root
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		if value:
			full_state = {"size": window.size, "position": window.position, "mode": DisplayServer.window_get_mode()}
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			window.borderless = true
			window.min_size = Vector2i(800, 220)
			window.size = Vector2i(usable.size.x, compact_size.y)
			window.position = Vector2i(usable.position.x, usable.end.y - window.size.y)
		else:
			compact_size = window.size
			window.borderless = false
			window.min_size = Vector2i(960, 540)
			window.size = full_state.get("size", Vector2i(1280, 720)).min(usable.size)
			window.position = full_state.get("position", usable.position + (usable.size - window.size) / 2)
			DisplayServer.window_set_mode(full_state.get("mode", DisplayServer.WINDOW_MODE_WINDOWED))
	window.transparent_bg = value
	window.transparent = value
	GameState.update_setting("compact", value)
	update_mouse_region.call_deferred()

func open_overlay() -> void:
	var window := get_tree().root
	if not GameState.settings.compact or window.size.y >= 620 or not overlay_state.is_empty() or DisplayServer.get_name() == "headless": return
	window.mouse_passthrough_polygon = PackedVector2Array()
	overlay_state = {"size": window.size, "position": window.position}
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = Vector2i(window.size.x, mini(720, usable.size.y))
	window.position.y = maxi(usable.position.y, overlay_state.position.y + overlay_state.size.y - window.size.y)

func close_overlay() -> void:
	if overlay_state.is_empty(): return
	var window := get_tree().root
	window.size = overlay_state.size
	window.position = overlay_state.position
	overlay_state.clear()
	update_mouse_region.call_deferred()

func resize_compact(height: int) -> void:
	compact_size.y = clampi(height, 220, 400)
	GameState.update_setting("compact_height", compact_size.y)
	if GameState.settings.compact:
		if not overlay_state.is_empty():
			var bottom: int = overlay_state.position.y + overlay_state.size.y
			overlay_state.size.y = compact_size.y
			overlay_state.position.y = bottom - compact_size.y
		else:
			var window := get_tree().root
			var bottom := window.position.y + window.size.y
			window.size.y = compact_size.y
			window.position.y = bottom - window.size.y

func update_mouse_region() -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_tree().root
	if not GameState.settings.compact or not overlay_state.is_empty():
		window.mouse_passthrough_polygon = PackedVector2Array()
		return
	var town := get_parent()
	if town.camera == null or town.hud == null: return
	var transform: Transform2D = town.get_viewport().get_canvas_transform()
	var outline := PackedVector2Array([Vector2(-650,30),Vector2(-620,-100),Vector2(-585,-210),Vector2(-500,-210),Vector2(-460,-225),Vector2(-340,-230),Vector2(-230,-230),Vector2(-150,-210),Vector2(-40,-220),Vector2(70,-210),Vector2(220,-235),Vector2(360,-215),Vector2(460,-215),Vector2(500,-110),Vector2(570,-150),Vector2(620,-40),Vector2(650,110)])
	var polygon := PackedVector2Array()
	var scale_factor: Vector2 = Vector2(window.size) / town.get_viewport_rect().size
	for point in outline: polygon.append(transform * point)
	var hud_rect: Rect2 = town.hud.top.get_global_rect().grow(3)
	if town.hud.bottom.visible: hud_rect = hud_rect.merge(town.hud.bottom.get_global_rect())
	var join_y := hud_rect.position.y
	polygon.append(Vector2(polygon[-1].x, join_y))
	polygon.append(Vector2(hud_rect.end.x, join_y))
	polygon.append(hud_rect.end)
	polygon.append(Vector2(hud_rect.position.x, hud_rect.end.y))
	polygon.append(hud_rect.position)
	polygon.append(Vector2(polygon[0].x, join_y))
	for index in polygon.size(): polygon[index] *= scale_factor
	window.mouse_passthrough_polygon = polygon
