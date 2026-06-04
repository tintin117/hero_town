extends Node2D

var gold := 200

const HeroScene := preload("res://scenes/hero.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BuildingScene := preload("res://scenes/building.tscn")

const TILE_SIZE := 64
const GROUND_Y := 400.0
const BUILDING_COSTS := {"house": 30}
const BUILDING_FOOTPRINTS := {"house": Vector2i(2, 1)}
const SAVE_PATH := "user://buildings.sav"

@onready var heroes_layer: Node2D = $HeroesLayer
@onready var enemies_layer: Node2D = $EnemiesLayer
@onready var building_layer: Node2D = $BuildingLayer
@onready var enemy_spawner: Timer = $EnemySpawner
@onready var gold_label: Label = $UI/GoldLabel
@onready var grid_overlay: Node2D = $GridOverlay

var hero_instance: CharacterBody2D = null
var occupied_cells: Dictionary = {}
var placement_mode := false
var moving_building: Node2D = null
var ghost_building: Node2D = null
var pending_type := ""
var build_buttons: Dictionary = {}
var _just_placed := false

func _ready() -> void:
	enemy_spawner.timeout.connect(_on_enemy_spawner_timeout)
	_add_ground_strip()
	_spawn_hero()
	_create_build_ui()
	_load_buildings()
	gold_label.text = "Gold: %d" % gold
	_update_build_buttons()

func _add_ground_strip() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.42, 0.28, 0.13, 1)
	ground.offset_top = GROUND_Y
	ground.offset_right = 1152.0
	ground.offset_bottom = 648.0
	add_child(ground)
	move_child(ground, 1)

func _create_build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 600.0)
	$UI.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var hbox := HBoxContainer.new()
	margin.add_child(hbox)
	var btn := Button.new()
	btn.text = "House  30g"
	btn.disabled = true
	btn.pressed.connect(func(): start_build("house"))
	hbox.add_child(btn)
	build_buttons["house"] = btn

func _spawn_hero() -> void:
	hero_instance = HeroScene.instantiate()
	hero_instance.position = Vector2(300.0, GROUND_Y)
	heroes_layer.add_child(hero_instance)

func _on_enemy_spawner_timeout() -> void:
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.position = Vector2(1100.0, GROUND_Y)
	enemies_layer.add_child(enemy)
	enemy.setup(hero_instance)
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(amount: int) -> void:
	add_gold(amount)

func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	gold_label.text = "Gold: %d" % gold
	_update_build_buttons()

func _update_build_buttons() -> void:
	for type in build_buttons:
		var cost: int = BUILDING_COSTS.get(type, 9999)
		build_buttons[type].disabled = gold < cost

# --- Footprint helpers ---

# Buildings only snap on the X axis; Y is always GROUND_Y.
func _fp_to_world(gpos: Vector2i, fp: Vector2i) -> Vector2:
	return Vector2(gpos.x * TILE_SIZE + fp.x * TILE_SIZE * 0.5, GROUND_Y)

func _get_current_fp() -> Vector2i:
	if placement_mode:
		return BUILDING_FOOTPRINTS.get(pending_type, Vector2i(1, 1))
	if moving_building:
		return moving_building.footprint
	return Vector2i(1, 1)

func _is_footprint_occupied(gpos: Vector2i, fp: Vector2i, ignore: Node2D = null) -> bool:
	for dy in fp.y:
		for dx in fp.x:
			var cell := gpos + Vector2i(dx, dy)
			if occupied_cells.has(cell) and occupied_cells.get(cell) != ignore:
				return true
	return false

func _register_footprint(gpos: Vector2i, fp: Vector2i, building: Node2D) -> void:
	for dy in fp.y:
		for dx in fp.x:
			occupied_cells[gpos + Vector2i(dx, dy)] = building

func _unregister_footprint(gpos: Vector2i, fp: Vector2i) -> void:
	for dy in fp.y:
		for dx in fp.x:
			occupied_cells.erase(gpos + Vector2i(dx, dy))

# --- Placement ---

func _process(_delta: float) -> void:
	_just_placed = false
	if ghost_building and (placement_mode or moving_building):
		var gpos := _world_to_grid(get_global_mouse_position())
		var fp := _get_current_fp()
		ghost_building.position = _fp_to_world(gpos, fp)
		var occupied: bool = _is_footprint_occupied(gpos, fp, moving_building)
		ghost_building.modulate = Color(0.4, 1.0, 0.4, 0.55) if not occupied else Color(1.0, 0.3, 0.3, 0.55)

func _unhandled_input(event: InputEvent) -> void:
	if not (placement_mode or moving_building):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_place_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_placement()

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), 0)

func start_build(type: String) -> void:
	if placement_mode or moving_building:
		_cancel_placement()
	pending_type = type
	placement_mode = true
	grid_overlay.visible = true
	_spawn_ghost()

func _spawn_ghost() -> void:
	if ghost_building:
		ghost_building.queue_free()
	ghost_building = BuildingScene.instantiate()
	ghost_building.set_meta("is_ghost", true)
	building_layer.add_child(ghost_building)

func _handle_place_click(world_pos: Vector2) -> void:
	var gpos := _world_to_grid(world_pos)
	var fp := _get_current_fp()
	var occupied: bool = _is_footprint_occupied(gpos, fp, moving_building)
	if occupied:
		return
	if placement_mode:
		var cost: int = BUILDING_COSTS.get(pending_type, 9999)
		if gold < cost:
			return
		_place_building(pending_type, gpos)
		_just_placed = true
		add_gold(-cost)
		_cancel_placement()
		_save_buildings()
	elif moving_building:
		_unregister_footprint(moving_building.grid_pos, moving_building.footprint)
		moving_building.grid_pos = gpos
		moving_building.position = _fp_to_world(gpos, moving_building.footprint)
		moving_building.modulate = Color.WHITE
		_register_footprint(gpos, moving_building.footprint, moving_building)
		moving_building = null
		_cancel_placement()
		_save_buildings()

func _place_building(type: String, gpos: Vector2i) -> void:
	var fp: Vector2i = BUILDING_FOOTPRINTS.get(type, Vector2i(1, 1))
	var b: Node2D = BuildingScene.instantiate()
	b.grid_pos = gpos
	b.footprint = fp
	b.building_type = type
	b.position = _fp_to_world(gpos, fp)
	building_layer.add_child(b)
	_register_footprint(gpos, fp, b)
	b.clicked.connect(_on_building_clicked)

func _on_building_clicked(building: Node2D) -> void:
	if placement_mode or moving_building or _just_placed:
		return
	moving_building = building
	building.modulate = Color(1.0, 1.0, 0.5, 0.75)
	grid_overlay.visible = true
	_spawn_ghost()

func _save_buildings() -> void:
	var data: Array = []
	for child in building_layer.get_children():
		if child.has_meta("is_ghost"):
			continue
		data.append({"type": child.building_type, "gx": child.grid_pos.x})
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_buildings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	if not result is Array:
		return
	for entry: Dictionary in (result as Array):
		_place_building(entry["type"], Vector2i(int(entry["gx"]), 0))

func _cancel_placement() -> void:
	placement_mode = false
	pending_type = ""
	if moving_building:
		moving_building.modulate = Color.WHITE
		moving_building = null
	grid_overlay.visible = false
	if ghost_building:
		ghost_building.queue_free()
		ghost_building = null
