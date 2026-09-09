extends Control

const Rules = preload("res://conquest/conquest_state.gd")
const Presentation = preload("res://scripts/presentation_scale.gd")
@export var companion_save_path := "user://conquest_companion_v1.json"
var status: Label

func _ready() -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.transparent = true
	window.transparent_bg = true
	window.borderless = true
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var width := Presentation.window_width(window)
	window.size = Vector2i(width, roundi(width * 9.0 / 16.0))
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = usable.position + (usable.size - window.size) / 2
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	$MainMenuScene/water.hide()
	$MainMenuScene/foam_water.hide()
	$front_ui/Layout/PlayButton.disabled = not (FileAccess.file_exists(companion_save_path) or FileAccess.file_exists(Rules.SAVE))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("ffae90"))
	$front_ui/Layout.add_child(status)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://conquest/companion.tscn")


func _on_compact_button_pressed() -> void:
	if not create_fresh_save():
		status.text = "Could not start a new game. Your current save has been kept."
		return
	get_tree().change_scene_to_file("res://conquest/companion.tscn")
	



func _on_quit_button_pressed() -> void:
	get_tree().quit()

func create_fresh_save() -> bool:
	# Preserve the previous run before replacing it with the opening state.
	if FileAccess.file_exists(companion_save_path):
		if DirAccess.copy_absolute(companion_save_path, companion_save_path + ".previous") != OK:
			return false
	return Rules.new().save_game(companion_save_path)
