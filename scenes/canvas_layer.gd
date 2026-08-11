extends CanvasLayer


@onready var building_popup = $BuildingPopup
@onready var build_menu_popup = $BuildMenuPopup
@onready var placement_controller = $"../PlacementController"
@onready var currency_label: Label = $"Coin_HUD/CurrencyLabel"
@onready var shard_label: Label = $"Shard_HUD/ShardLabel"

func _ready() -> void:
	build_menu_popup.build_requested.connect(_on_build_requested)
	building_popup.move_requested.connect(_on_move_requested)
	building_popup.spawn_requested.connect(_on_spawn_requested)
	building_popup.hero_acquired.connect(_on_hero_acquired)
	GameState.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(GameState.gold, GameState.shard)

func connect_building(building: BuildingBase) -> void:
	building.clicked.connect(_on_building_clicked.bind(building))

func _on_building_clicked(building: BuildingBase) -> void:
	building_popup.open(building)

func _on_placement_button_pressed() -> void:
	var options: Array = []
	for data in GameData.BUILDINGS.values():
		if data.build_cost <= 0:
			continue
		options.append({
			"type": data.id,
			"label": data.display_name,
			"cost": data.build_cost,
			"can_afford": GameState.can_afford(data.build_cost),
			"thumbnail": data.thumbnail,
		})
	build_menu_popup.show_options(options)

func _on_build_requested(building_type: String) -> void:
	placement_controller.start_placement(GameData.BUILDINGS[building_type])

func _on_move_requested(building: BuildingBase) -> void:
	placement_controller.start_move(building)

func _on_spawn_requested(enemy_id: String, building: BuildingBase) -> void:
	var enemy_data: EnemyData = GameData.ENEMIES[enemy_id]
	var enemy_instance: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	var stats := UnitStats.new()
	stats.max_hp = enemy_data.hp
	stats.atk = enemy_data.atk
	enemy_instance.stats = stats
	enemy_instance.enemy_data = enemy_data
	enemy_instance.global_position = building.global_position
	get_tree().current_scene.add_child(enemy_instance)

func _on_hero_acquired(hero_id: String, building: BuildingBase) -> void:
	var hero_data: HeroData = GameData.HEROES[hero_id]
	var hero_instance: Hero = preload("res://scenes/hero.tscn").instantiate()
	var stats := UnitStats.new()
	stats.max_hp = hero_data.base_hp
	stats.atk = hero_data.base_power
	stats.atk_speed = hero_data.atk_speed
	hero_instance.stats = stats
	hero_instance.global_position = building.global_position
	get_tree().current_scene.add_child(hero_instance)


func _on_currency_changed(gold: int, shard: int) -> void:
	#currency_label.text = "Gold: %d   Shard: %d" % [gold, shard]
	currency_label.text = "%d" % [gold]
	shard_label.text = "%d" % [shard]
