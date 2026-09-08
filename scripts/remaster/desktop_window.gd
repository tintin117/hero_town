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
	GameState.update_setting("compact", value)

func open_overlay() -> void:
	var window := get_tree().root
	if window.size.y >= 620 or not overlay_state.is_empty() or DisplayServer.get_name() == "headless": return
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
