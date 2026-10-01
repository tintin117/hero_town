extends Control
## Thin shell: shows the main menu, then the town (with the arena in its slot) under the HUD.
## Menu signals become Game commands here; no rules and no drawing live in this script.

const MIN_WINDOW := Vector2i(960, 420)
const ARENA_SCENE := preload("res://game/combat/arena.tscn")
const ARENA_CELLS := Rect2i(16, 0, 16, 8)  # the town cells the arena occupies

var _moving := false  ## the placement in progress moves an existing building

@onready var town: Control = %Town
@onready var hud: Control = %HUD
@onready var menu: Control = %MainMenu


func _ready() -> void:
	var window := get_window()
	window.title = "Fight club"
	window.min_size = MIN_WINDOW
	town.align_bottom = true
	var arena := ARENA_SCENE.instantiate()
	town.get_node("World/ArenaSlot").add_child(arena)
	# The arena is the control surface: tap to pick fighters, hold to plant.
	town.pressed.connect(func(cell: Vector2i) -> void:
		if ARENA_CELLS.has_point(cell):
			hud.press_arena())
	town.released.connect(hud.release_arena)
	# Buildings: the Build drawer asks for a placement, the town's ghost picks the cell, the game builds.
	hud.placement_requested.connect(_begin_placement)
	town.placement_confirmed.connect(_place)
	town.cell_clicked.connect(func(cell: Vector2i) -> void:
		var id: StringName = town.building_id_at(cell)
		if id != &"":
			hud.focus_building(id))
	hud.plant_progress.connect(arena.set_plant_progress)
	menu.new_game_requested.connect(func() -> void: _start(Game.new_game()))
	menu.continue_requested.connect(func() -> void: _start(Game.continue_game()))
	menu.quit_requested.connect(get_tree().quit)
	hud.main_menu_requested.connect(_show_menu)
	hud.quit_requested.connect(get_tree().quit)
	if DesktopStrip.supported():
		var strip := DesktopStrip.new()
		strip.hud = hud
		strip.town = town
		strip.covering = func() -> bool: return menu.visible or hud.is_covering()
		hud.collapse_requested.connect(strip.toggle_collapse)
		add_child(strip)
	_show_menu()


func _begin_placement(id: StringName, moving: bool) -> void:
	_moving = moving
	for def: BuildingDef in Game.building_defs():
		if def.id == id:
			town.begin_placement(id, def.footprint, func(cell: Vector2i) -> bool: return Game.can_place(id, cell))


func _place(id: StringName, cell: Vector2i) -> void:
	if _moving:
		Game.move_building(id, cell)
	else:
		Game.build(id, cell)


func _show_menu() -> void:
	town.cancel_placement()
	hud.router.close()
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
	await get_tree().process_frame  # let the HUD lay out before its drawers slide in
	hud.sync_all()
	town.center_on_arena()
	Game.set_paused(false)
