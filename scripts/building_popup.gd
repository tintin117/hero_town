extends Control

signal move_requested(building: BuildingBase)
signal spawn_requested(enemy_id: String, building: BuildingBase)
signal hero_acquired(hero_id: String, building: BuildingBase)
signal hero_released(hero_id: String)

const SHOP_SLOTS := 4

@onready var title_label: Label = $"../BuildingPopup/VBoxContainer/LabelControl/Label"
@onready var level_label: Label = $"../BuildingPopup/VBoxContainer/LevelControl/Level"
@onready var upgrade_btn: TextureButton = $"../BuildingPopup/VBoxContainer/ActionButton/HBoxContainer/Upgrade"
@onready var content_list: VBoxContainer = $"../BuildingPopup/VBoxContainer/SelectionGrid/ScrollContainer/GridContainer"

var building: BuildingBase = null
var _shrine_result_text: String = ""
var _shop_offers: Array[String] = []


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
	title_label.text = str(data.display_name)
	level_label.text = "Lv%d" % building.current_level
	if building.current_level >= data.levels.size():
		upgrade_btn.text = "MAX"
		upgrade_btn.disabled = true
	else:
		var cost: int = data.levels[building.current_level]["cost"]
		#upgrade_btn.text = "Upgrade  %dg" % cost
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

		var auto_btn := Button.new()
		auto_btn.text = "Auto ✓" if building.auto_spawn_enemy_ids.has(enemy_id) else "Auto"
		auto_btn.pressed.connect(func():
			building.toggle_auto_spawn(enemy_id)
			_refresh())
		row.add_child(auto_btn)

		content_list.add_child(row)


func _refresh_shrine_content(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()

	var level_data: Dictionary = data.levels[building.current_level - 1]
	var roll_gold: int = level_data["roll_gold"]
	var roll_shard: int = level_data["roll_shard"]

	if _shop_offers.is_empty():
		_shop_offers = _generate_shop_offers(level_data)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll  %dg + %ds" % [roll_gold, roll_shard]
	reroll_btn.disabled = not GameState.can_afford(roll_gold, roll_shard)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	content_list.add_child(reroll_btn)

	for hero_id in _shop_offers:
		var hero: HeroData = GameData.HEROES[hero_id]
		var row := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s (%s, %s)" % [hero.display_name, hero.rarity.capitalize(), hero.hero_class.capitalize()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var buy_btn := Button.new()
		buy_btn.text = "Buy  %dg + %ds" % [roll_gold, roll_shard]
		var is_new := not GameState.owned_heroes.has(hero_id)
		buy_btn.disabled = not GameState.can_afford(roll_gold, roll_shard) or (is_new and GameState.is_roster_full())
		buy_btn.pressed.connect(_on_buy_offer_pressed.bind(hero_id, roll_gold, roll_shard))
		row.add_child(buy_btn)

		content_list.add_child(row)

	if not _shrine_result_text.is_empty():
		var result_label := Label.new()
		result_label.text = _shrine_result_text
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content_list.add_child(result_label)

	var roster_header := Label.new()
	roster_header.text = "Roster (%d/%d)" % [GameState.owned_heroes.size(), GameState.HERO_CAP]
	content_list.add_child(roster_header)

	for hero_id in GameState.owned_heroes.keys():
		var hero: HeroData = GameData.HEROES[hero_id]
		var row := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s (%s)" % [hero.display_name, hero.hero_class.capitalize()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var release_btn := Button.new()
		release_btn.text = "Release"
		release_btn.pressed.connect(_on_release_pressed.bind(hero_id))
		row.add_child(release_btn)

		content_list.add_child(row)


## Picks SHOP_SLOTS random heroes weighted by the shrine level's rarity table.
## Duplicate offers across slots are allowed, same as TFT-style shops.
func _generate_shop_offers(level_data: Dictionary) -> Array[String]:
	var offers: Array[String] = []
	for i in SHOP_SLOTS:
		var hero := _pick_weighted_hero(level_data)
		if hero != null:
			offers.append(hero.id)
	return offers


func _pick_weighted_hero(level_data: Dictionary) -> HeroData:
	var rarity := _weighted_pick(level_data["weights"])
	var pool: Array = GameData.HEROES.values().filter(func(h): return h.rarity == rarity)
	if pool.is_empty():
		pool = GameData.HEROES.values().filter(func(h): return h.rarity == "common")
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


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


func _on_reroll_pressed() -> void:
	var data := building.get_data()
	var level_data: Dictionary = data.levels[building.current_level - 1]
	var roll_gold: int = level_data["roll_gold"]
	var roll_shard: int = level_data["roll_shard"]
	if not GameState.can_afford(roll_gold, roll_shard):
		return
	GameState.spend(roll_gold, roll_shard)
	_shop_offers = _generate_shop_offers(level_data)
	_shrine_result_text = ""
	_refresh()


func _on_buy_offer_pressed(hero_id: String, cost_gold: int, cost_shard: int) -> void:
	var hero: HeroData = GameData.HEROES[hero_id]
	var was_new := not GameState.owned_heroes.has(hero_id)
	if not GameState.buy_hero(hero_id, cost_gold, cost_shard):
		return

	if was_new:
		_shrine_result_text = "New hero: %s (%s)!" % [hero.display_name, hero.rarity.capitalize()]
		hero_acquired.emit(hero_id, building)
	else:
		_shrine_result_text = "%s already owned! +%d shards" % [hero.display_name, hero.dupe_shard]

	var data := building.get_data()
	var level_data: Dictionary = data.levels[building.current_level - 1]
	var slot := _shop_offers.find(hero_id)
	if slot != -1:
		var replacement := _pick_weighted_hero(level_data)
		if replacement != null:
			_shop_offers[slot] = replacement.id
	_refresh()


func _on_release_pressed(hero_id: String) -> void:
	GameState.release_hero(hero_id)
	hero_released.emit(hero_id)
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
