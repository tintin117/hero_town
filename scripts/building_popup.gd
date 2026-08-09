extends PanelContainer

signal move_requested(building: BuildingBase)
signal spawn_requested(enemy_id: String, building: BuildingBase)
signal hero_acquired(hero_id: String, building: BuildingBase)

@onready var title_label: Label = $VBox/TitleLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var content_list: VBoxContainer = $VBox/ContentList

var building: BuildingBase = null
var _shrine_result_text: String = ""


func _ready() -> void:
	visible = false


func open(target: BuildingBase) -> void:
	building = target
	_shrine_result_text = ""
	_refresh()
	visible = true


func close() -> void:
	visible = false


func _refresh() -> void:
	var data := building.get_data()
	title_label.text = data.display_name
	level_label.text = "Lv%d" % building.current_level
	if building.current_level >= data.levels.size():
		upgrade_btn.text = "MAX"
		upgrade_btn.disabled = true
	else:
		var cost: int = data.levels[building.current_level]["cost"]
		upgrade_btn.text = "Upgrade  %dg" % cost
		upgrade_btn.disabled = not GameState.can_afford(cost)

	if building.building_id == "portal":
		_refresh_enemy_list(data)
	elif building.building_id == "shrine":
		_refresh_shrine_content(data)
	else:
		for child in content_list.get_children():
			child.queue_free()


func _refresh_enemy_list(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()

	var current_tier: int = data.levels[building.current_level - 1]["enemy_tier"]
	for enemy in GameData.ENEMIES.values():
		if enemy.tier > current_tier:
			continue

		var row := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s (T%d)  %d-%dg %d-%ds" % [
			enemy.display_name, enemy.tier,
			enemy.gold_min, enemy.gold_max,
			enemy.shard_min, enemy.shard_max,
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var summon_btn := Button.new()
		summon_btn.text = "Summon"
		var enemy_id: String = enemy.id
		summon_btn.pressed.connect(func(): spawn_requested.emit(enemy_id, building))
		row.add_child(summon_btn)

		content_list.add_child(row)


func _refresh_shrine_content(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()

	var level_data: Dictionary = data.levels[building.current_level - 1]
	var roll_gold: int = level_data["roll_gold"]
	var roll_shard: int = level_data["roll_shard"]

	var cost_label := Label.new()
	cost_label.text = "Roll: %dg + %ds" % [roll_gold, roll_shard]
	content_list.add_child(cost_label)

	var roll_btn := Button.new()
	roll_btn.text = "Roll"
	roll_btn.disabled = not GameState.can_afford(roll_gold, roll_shard)
	roll_btn.pressed.connect(_on_roll_button_pressed)
	content_list.add_child(roll_btn)

	if not _shrine_result_text.is_empty():
		var result_label := Label.new()
		result_label.text = _shrine_result_text
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content_list.add_child(result_label)


func _on_upgrade_button_pressed() -> void:
	var data := building.get_data()
	if building.current_level >= data.levels.size():
		return
	var cost: int = data.levels[building.current_level]["cost"]
	if not GameState.can_afford(cost):
		return
	GameState.spend(cost)
	building.upgrade()
	_refresh()


func _on_move_button_pressed() -> void:
	move_requested.emit(building)
	close()


func _on_close_button_pressed() -> void:
	visible = false


func _on_roll_button_pressed() -> void:
	var data := building.get_data()
	var level_data: Dictionary = data.levels[building.current_level - 1]
	var roll_gold: int = level_data["roll_gold"]
	var roll_shard: int = level_data["roll_shard"]
	if not GameState.can_afford(roll_gold, roll_shard):
		return
	GameState.spend(roll_gold, roll_shard)

	var rarity := _weighted_pick(level_data["weights"])
	var pool: Array = GameData.HEROES.values().filter(func(h): return h.rarity == rarity)
	if pool.is_empty():
		pool = GameData.HEROES.values().filter(func(h): return h.rarity == "common")
	if pool.is_empty():
		return

	var hero: HeroData = pool[randi() % pool.size()]
	var rarity_cap: String = hero.rarity.capitalize()
	if GameState.owned_heroes.has(hero.id):
		GameState.add(0, hero.dupe_shard)
		_shrine_result_text = "%s (%s)\nAlready owned! +%d shards" % [hero.display_name, rarity_cap, hero.dupe_shard]
	else:
		GameState.owned_heroes[hero.id] = true
		_shrine_result_text = "New hero: %s (%s)!" % [hero.display_name, rarity_cap]
		hero_acquired.emit(hero.id, building)

	_refresh()


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0
	for w in weights.values():
		total += w as int
	if total == 0:
		return "common"
	var roll := randi() % total
	var acc := 0
	for rarity in weights:
		acc += weights[rarity] as int
		if roll < acc:
			return rarity
	return "common"
