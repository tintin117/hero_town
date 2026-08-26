extends CanvasLayer

## Hero granted for free at game start (no hero-select UI yet -- pick one here).
@export var starting_hero_id: String = "H001"
@export var starting_hero_position: Vector3 = Vector3(-11.9, 0, 0)

@onready var building_popup = $BuildingPopup
@onready var build_menu_popup = $BuildPopup
@onready var placement_controller = $"../PlacementController"
@onready var currency_label: Label = $"Coin_HUD/CurrencyLabel"
@onready var shard_label: Label = $"Shard_HUD/ShardLabel"

@onready var warrior_label: Label = $ClassSynergyHUD/VBoxContainer/WarriorLabel
@onready var rogue_label: Label = $ClassSynergyHUD/VBoxContainer/RogueLabel
@onready var mage_label: Label = $ClassSynergyHUD/VBoxContainer/MageLabel
@onready var cleric_label: Label = $ClassSynergyHUD/VBoxContainer/ClericLabel

var hero_instances: Dictionary = {}  # hero_id -> Hero

func _ready() -> void:
	build_menu_popup.build_requested.connect(_on_build_requested)
	building_popup.move_requested.connect(_on_move_requested)
	building_popup.spawn_requested.connect(_on_spawn_requested)
	building_popup.hero_acquired.connect(_on_hero_acquired)
	building_popup.hero_released.connect(_on_hero_released)
	GameState.currency_changed.connect(_on_currency_changed)
	GameState.roster_changed.connect(_recompute_all_hero_stats)
	_on_currency_changed(GameState.gold, GameState.shard)
	_update_class_hud()
	if GameState.owned_heroes.is_empty():
		GameState.grant_hero(starting_hero_id)
		_spawn_hero(starting_hero_id, starting_hero_position)

func connect_building(building: BuildingBase) -> void:
	building.clicked.connect(_on_building_clicked.bind(building))
	building.auto_spawn_requested.connect(_on_spawn_requested)

func _on_building_clicked(building: BuildingBase) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var world_pos: Vector3 = building.global_transform.origin
	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	var pixel_offset_y = 200
	screen_pos.y -= pixel_offset_y
	if camera.is_position_behind(world_pos):
		visible = false
		return
	else:
		visible = true
	building_popup.size
	var ui_size: Vector2 = building_popup.size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var top_left: Vector2 = screen_pos - ui_size / 2.0
	var screen_margin = 20
	top_left.x = clamp(top_left.x, screen_margin, viewport_size.x - ui_size.x - screen_margin)
	top_left.y = clamp(top_left.y, screen_margin, viewport_size.y - ui_size.y - screen_margin)
	building_popup.global_position = top_left
	building_popup.open(building)

func _on_placement_button_pressed() -> void:
	var options: Array = []
	for data in GameData.BUILDINGS.values():
		if data.build_cost <= 0:
			continue
		options.append({
			"type": data.id,
			"label": str(data.display_name),
			"cost": data.build_cost,
			"can_afford": GameState.can_afford(data.build_cost),
			"thumbnail": data.thumbnail,
		})
	build_menu_popup.show_options(options)

func _on_build_requested(building_type: String) -> void:
	placement_controller.start_placement(GameData.BUILDINGS[building_type])

func _on_move_requested(building: BuildingBase) -> void:
	placement_controller.start_move(building)

const HERO_BASE_SCENE := preload("res://scenes/hero.tscn")
const ENEMY_BASE_SCENE := preload("res://scenes/enemy.tscn")

## Per-id override scene, e.g. res://scenes/heroes/h001.tscn, falls back to the shared base scene.
func _hero_scene(hero_id: String) -> PackedScene:
	var path := "res://scenes/heroes/%s.tscn" % hero_id.to_lower()
	return load(path) if ResourceLoader.exists(path) else HERO_BASE_SCENE

## Same convention as _hero_scene, under res://scenes/enemies/.
func _enemy_scene(enemy_id: String) -> PackedScene:
	var path := "res://scenes/enemies/%s.tscn" % enemy_id.to_lower()
	return load(path) if ResourceLoader.exists(path) else ENEMY_BASE_SCENE

## Enemies scatter around the whole portal, not just a pinpoint, so they approach heroes
## from different angles instead of a single straight line.
const ENEMY_SPAWN_RADIUS := 15.0

## Random XZ offset within `radius` so units spawned at the same point don't stack.
static func _spawn_jitter(radius: float) -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(0.0, radius)
	return Vector3(cos(angle), 0.0, sin(angle)) * dist

func _on_spawn_requested(enemy_id: String, building: BuildingBase) -> void:
	var enemy_instance: Enemy = _enemy_scene(enemy_id).instantiate()
	enemy_instance.enemy_data = GameData.ENEMIES[enemy_id]
	enemy_instance.position = building.global_position + _spawn_jitter(ENEMY_SPAWN_RADIUS)
	enemy_instance.died.connect(building.on_enemy_defeated)
	get_tree().current_scene.add_child.call_deferred(enemy_instance)

func _spawn_hero(hero_id: String, at_position: Vector3) -> Hero:
	var hero_instance: Hero = _hero_scene(hero_id).instantiate()
	hero_instance.position = at_position + _spawn_jitter(0.5)
	get_tree().current_scene.add_child.call_deferred(hero_instance)
	hero_instances[hero_id] = hero_instance
	return hero_instance

func _on_hero_acquired(hero_id: String, building: BuildingBase) -> void:
	_spawn_hero(hero_id, building.global_position)

func _on_hero_released(hero_id: String) -> void:
	if hero_instances.has(hero_id):
		hero_instances[hero_id].queue_free()
		hero_instances.erase(hero_id)

## Re-derives stats for every spawned hero (class buff thresholds may have changed).
## Leaves current hp untouched so a buff never heals/resets a hero mid-fight.
func _recompute_all_hero_stats() -> void:
	for hero_id in hero_instances.keys():
		if not is_instance_valid(hero_instances[hero_id]):
			hero_instances.erase(hero_id)
			continue
		hero_instances[hero_id].apply_hero_data()
	_update_class_hud()

func _update_class_hud() -> void:
	var counts := GameState.get_class_counts()
	for entry in [
		[HeroData.HeroClass.WARRIOR, warrior_label, "Warrior"],
		[HeroData.HeroClass.ROGUE, rogue_label, "Rogue"],
		[HeroData.HeroClass.MAGE, mage_label, "Mage"],
		[HeroData.HeroClass.CLERIC, cleric_label, "Cleric"],
	]:
		var cls: HeroData.HeroClass = entry[0]
		var label: Label = entry[1]
		var display: String = entry[2]
		var count: int = counts.get(cls, 0)
		var buffed := GameState.has_class_buff(cls)
		label.text = "%s %d/%d%s" % [display, count, GameState.CLASS_BUFF_THRESHOLD, " ✓" if buffed else ""]
		label.modulate = Color.GREEN if buffed else Color.WHITE


func _on_currency_changed(gold: int, shard: int) -> void:
	#currency_label.text = "Gold: %d   Shard: %d" % [gold, shard]
	currency_label.text = "%d" % [gold]
	shard_label.text = "%d" % [shard]
