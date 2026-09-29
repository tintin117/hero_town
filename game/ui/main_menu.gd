extends Control
## Title screen: New Game / Continue / Quit. New Game asks first when a valid save exists.
## Only emits signals; the shell calls new_game() / continue_game(). `game` defaults to the autoload
## (used to find out whether a save exists), tests set it before add_child.

signal new_game_requested
signal continue_requested
signal quit_requested

var game: Node

@onready var _continue: Button = %Continue
@onready var _confirm: Control = %Confirm


func _ready() -> void:
	game = game if game else get_node_or_null("/root/Game")
	%NewGame.pressed.connect(_on_new_game)
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	%Quit.pressed.connect(func() -> void: quit_requested.emit())
	%Replace.pressed.connect(func() -> void:
		_confirm.visible = false
		new_game_requested.emit())
	%Cancel.pressed.connect(func() -> void: _confirm.visible = false)
	visibility_changed.connect(refresh)
	refresh()


## Re-checks the save file; call after anything that may have written or removed it.
func refresh() -> void:
	_confirm.visible = false
	var has := has_save()
	_continue.disabled = not has
	_continue.tooltip_text = "" if has else "No saved game yet"


func has_save() -> bool:
	return game != null and not SaveStore.load_state(game.tuning, game.hero_defs.size(), game.save_path).is_empty()


func _on_new_game() -> void:
	if has_save():
		_confirm.visible = true
		%Cancel.grab_focus()
	else:
		new_game_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm.visible = false
