extends Control
## Pause menu: opening it pauses the sim (the only UI that does), closing resumes. Resume / Save & Main Menu / Quit.
## The shell listens to `main_menu_requested` and `quit_requested`; this script only pauses and saves.
## `game` defaults to the autoload; the HUD (or a test) may set it first.

signal main_menu_requested
signal quit_requested

var game: Node


func _ready() -> void:
	visible = false
	%Resume.pressed.connect(close)
	%SaveMenu.pressed.connect(_on_save_menu)
	%Quit.pressed.connect(func() -> void: quit_requested.emit())


func open() -> void:
	game = game if game else get_node_or_null("/root/Game")
	visible = true
	game.set_paused(true)
	%Resume.grab_focus()


func close() -> void:
	if visible:
		visible = false
		game.set_paused(false)


func _on_save_menu() -> void:
	game.save()
	close()
	main_menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
