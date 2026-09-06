extends CanvasLayer

@onready var building_popup = $BuildingPopup
@onready var build_menu_popup = $BuildPopup
@onready var placement_controller = $"../PlacementController"
@onready var currency_label: Label = $"Coin_HUD/CurrencyLabel"
@onready var shard_label: Label = $"Shard_HUD/ShardLabel"

var hero_instances: Dictionary = {}  # BuildingBase -> Array[Hero]

func _ready() -> void:
	build_menu_popup.build_requested.connect(_on_build_requested)
	building_popup.move_requested.connect(_on_move_requested)
	building_popup.spawn_requested.connect(_on_spawn_requested)
	building_popup.hero_building_changed.connect(_sync_hero_building)
	GameState.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(GameState.gold, GameState.shard)

func connect_building(building: BuildingBase) -> void:
	building.clicked.connect(_on_building_clicked.bind(building))
	building.auto_spawn_requested.connect(_on_spawn_requested)
	if building.building_id == "barracks":
		_sync_hero_building(building)

func _on_building_clicked(building: BuildingBase) -> void:
	var world_pos: Vector2 = building.global_position
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var pixel_offset_y = 140
	screen_pos.y -= pixel_offset_y
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
const ENEMY_SPAWN_RADIUS := 60.0

## Random offset within `radius` so units spawned at the same point don't stack.
static func _spawn_jitter(radius: float) -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(0.0, radius)
	return Vector2(cos(angle), sin(angle)) * dist

func _on_spawn_requested(enemy_id: String, building: BuildingBase) -> void:
	var enemy_instance: Enemy = _enemy_scene(enemy_id).instantiate()
	enemy_instance.enemy_data = GameData.ENEMIES[enemy_id]
	enemy_instance.position = building.global_position + _spawn_jitter(ENEMY_SPAWN_RADIUS)
	enemy_instance.died.connect(building.on_enemy_defeated)
	get_tree().current_scene.add_child.call_deferred(enemy_instance)

func _spawn_hero(hero_id: String, at_position: Vector2, source_building: BuildingBase) -> Hero:
	var hero_instance: Hero = _hero_scene(hero_id).instantiate()
	hero_instance.hero_data = GameData.HEROES[hero_id]
	hero_instance.source_building = source_building
	hero_instance.position = at_position + _spawn_jitter(16.0)
	get_tree().current_scene.add_child.call_deferred(hero_instance)
	return hero_instance

## Grows/shrinks `building`'s squad to match its current squad_count, and
## re-derives stats/hero_data on already-alive members (e.g. after a tier_up or
## stat_buff reward). Leaves current hp untouched so a buff never heals mid-fight.
func _sync_hero_building(building: BuildingBase) -> void:
	var squad: Array = hero_instances.get(building, []).filter(func(h): return is_instance_valid(h))
	var hero_id := building.active_hero_id()
	for hero: Hero in squad:
		hero.hero_data = GameData.HEROES[hero_id]
		hero.apply_hero_data()
	while squad.size() < building.squad_count:
		squad.append(_spawn_hero(hero_id, building.global_position, building))
	while squad.size() > building.squad_count:
		squad.pop_back().queue_free()
	hero_instances[building] = squad


var _last_gold := -1
var _last_shard := -1

func _on_currency_changed(gold: int, shard: int) -> void:
	# Floating "-N" beside the HUD on spends; gains already read via coin flights.
	if _last_gold >= 0 and gold < _last_gold:
		fx.popup("%d" % (gold - _last_gold), currency_label.global_position + Vector2(70, 0),
				{"parent": self, "font_size": 20, "color": Color(1, 0.5, 0.4)})
	if _last_shard >= 0 and shard < _last_shard:
		fx.popup("%d" % (shard - _last_shard), shard_label.global_position + Vector2(70, 0),
				{"parent": self, "font_size": 20, "color": Color(0.7, 0.9, 1)})
	_last_gold = gold
	_last_shard = shard
	currency_label.text = "%d" % [gold]
	shard_label.text = "%d" % [shard]
