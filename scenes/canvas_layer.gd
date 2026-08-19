extends CanvasLayer


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

func _on_spawn_requested(enemy_id: String, building: BuildingBase) -> void:
	var enemy_data: EnemyData = GameData.ENEMIES[enemy_id]
	var enemy_instance: Enemy = _enemy_scene(enemy_id).instantiate()
	var stats := UnitStats.new()
	stats.max_hp = enemy_data.hp
	stats.atk = enemy_data.atk
	enemy_instance.stats = stats
	enemy_instance.enemy_data = enemy_data
	enemy_instance.global_position = building.global_position
	get_tree().current_scene.add_child(enemy_instance)

## Builds a fresh UnitStats from hero_data, applying that hero's class buff if active.
func _build_hero_stats(hero_data: HeroData) -> UnitStats:
	var stats := UnitStats.new()
	stats.max_hp = hero_data.base_hp
	stats.atk = hero_data.base_power
	stats.atk_speed = hero_data.atk_speed
	stats.mana_per_hit = hero_data.mana_per_hit
	if GameState.has_class_buff(hero_data.hero_class):
		var buff: Dictionary = GameState.CLASS_BUFFS.get(hero_data.hero_class, {})
		if buff.has("stat"):
			stats.set(buff["stat"], stats.get(buff["stat"]) * buff["mult"])
	return stats

func _on_hero_acquired(hero_id: String, building: BuildingBase) -> void:
	var hero_data: HeroData = GameData.HEROES[hero_id]
	var hero_instance: Hero = _hero_scene(hero_id).instantiate()
	hero_instance.stats = _build_hero_stats(hero_data)
	hero_instance.global_position = building.global_position
	get_tree().current_scene.add_child(hero_instance)
	hero_instances[hero_id] = hero_instance

func _on_hero_released(hero_id: String) -> void:
	if hero_instances.has(hero_id):
		hero_instances[hero_id].queue_free()
		hero_instances.erase(hero_id)

## Re-derives stats for every spawned hero (class buff thresholds may have changed).
## Leaves current hp untouched so a buff never heals/resets a hero mid-fight.
func _recompute_all_hero_stats() -> void:
	for hero_id in hero_instances:
		var hero_instance: Hero = hero_instances[hero_id]
		if not is_instance_valid(hero_instance):
			continue
		var fresh := _build_hero_stats(GameData.HEROES[hero_id])
		hero_instance.stats.max_hp = fresh.max_hp
		hero_instance.stats.atk = fresh.atk
		hero_instance.stats.atk_speed = fresh.atk_speed
		hero_instance.stats.mana_per_hit = fresh.mana_per_hit
	_update_class_hud()

func _update_class_hud() -> void:
	var counts := GameState.get_class_counts()
	for entry in [
		["warrior", warrior_label, "Warrior"],
		["rogue", rogue_label, "Rogue"],
		["mage", mage_label, "Mage"],
		["cleric", cleric_label, "Cleric"],
	]:
		var cls: String = entry[0]
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
