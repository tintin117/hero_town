extends Control
## Thin shell: shows the main menu, then the town (with the arena in its slot) under the HUD.
## Menu signals become Game commands here; no rules and no drawing live in this script.

const MIN_WINDOW := Vector2i(960, 420)
const ARENA_SCENE := preload("res://game/combat/arena.tscn")

@onready var town: Control = %Town
@onready var hud: Control = %HUD
@onready var menu: Control = %MainMenu


func _ready() -> void:
	var window := get_window()
	window.title = "Fight club"
	window.min_size = MIN_WINDOW
	town.get_node("World/ArenaSlot").add_child(ARENA_SCENE.instantiate())
	menu.new_game_requested.connect(func() -> void: _start(Game.new_game()))
	menu.continue_requested.connect(func() -> void: _start(Game.continue_game()))
	menu.quit_requested.connect(get_tree().quit)
	hud.main_menu_requested.connect(_show_menu)
	hud.quit_requested.connect(get_tree().quit)
	_show_menu()


func _show_menu() -> void:
	Game.set_paused(true)
	hud.hide()
	menu.show()
	menu.refresh()


func _start(loaded: bool) -> void:
	if not loaded:
		menu.refresh()
		return
	menu.hide()
	hud.show()
	town.center_on_arena()
	Game.set_paused(false)
