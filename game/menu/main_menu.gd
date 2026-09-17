extends Control

const Rules = preload("res://game/companion/conquest_state.gd")
const Presentation = preload("res://game/shared/presentation_scale.gd")
@export var companion_save_path := "user://conquest_companion_v1.json"
@export var companion_scene: PackedScene = preload("res://game/companion/companion.tscn")
@onready var status: Label = $front_ui/Layout/Status

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
	$front_ui/Layout/PlayButton.disabled = not (FileAccess.file_exists(companion_save_path) or FileAccess.file_exists(Rules.SAVE))


func _on_play_button_pressed() -> void:
	_open_companion.call_deferred()


func _on_compact_button_pressed() -> void:
	if not create_fresh_save():
		status.text = "Could not start a new game. Your current save has been kept."
		return
	_open_companion.call_deferred()
	



func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _open_companion() -> void:
	var companion := companion_scene.instantiate()
	companion.save_path = companion_save_path
	var tree := get_tree()
	var previous := tree.current_scene
	tree.root.add_child(companion)
	tree.current_scene = companion
	if previous != null: previous.queue_free()
	else: queue_free()

func create_fresh_save() -> bool:
	# Preserve the previous run before replacing it with the opening state.
	if FileAccess.file_exists(companion_save_path):
		if DirAccess.copy_absolute(companion_save_path, companion_save_path + ".previous") != OK:
			return false
	var companion := companion_scene.instantiate()
	var fresh = Rules.new(companion.balance)
	companion.free()
	return fresh.save_game(companion_save_path)
