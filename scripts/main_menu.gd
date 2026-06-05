extends Control

func _ready() -> void:
	$Layout/PlayButton.pressed.connect(_on_play_pressed)
	$Layout/CompactButton.pressed.connect(_on_compact_pressed)
	$Layout/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_compact_pressed() -> void:
	const OVERLAY_H := 120
	var sw := DisplayServer.screen_get_size().x
	var sh := DisplayServer.screen_get_size().y
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(sw, OVERLAY_H))
	DisplayServer.window_set_position(Vector2i(0, sh - OVERLAY_H))
	get_tree().root.transparent_bg = true
	get_tree().root.content_scale_size = Vector2i(sw, OVERLAY_H)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
