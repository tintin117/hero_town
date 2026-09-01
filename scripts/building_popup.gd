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
var _upgrade_label: Label

const TEXT_DARK := Color(0.24, 0.17, 0.1)


func _ready() -> void:
	visible = false
	# TextureButton has no text property; the cost/MAX readout lives on a child label.
	_upgrade_label = Label.new()
	_upgrade_label.add_theme_font_size_override("font_size", 12)
	_upgrade_label.add_theme_color_override("font_color", TEXT_DARK)
	_upgrade_label.position = Vector2(-4, 32)
	upgrade_btn.add_child(_upgrade_label)


## min_width > 0 is needed for standalone autowrap labels, which otherwise
## collapse to zero width inside a ScrollContainer. Row labels must leave it 0
## or they push their buttons past the scroll clip.
func _dark_label(text: String, min_width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_DARK)
	if min_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(min_width, 0)
	return label


func open(target: BuildingBase) -> void:
	building = target
	_shrine_result_text = ""
	_refresh()
	visible = true
	sfx.play("click")


func close() -> void:
	visible = false


func _refresh() -> void:
	var data := building.get_data()
	title_label.text = str(data.display_name)
	level_label.text = "Lv%d" % building.current_level
	if building.current_level >= data.levels.size():
		_upgrade_label.text = "MAX"
		upgrade_btn.disabled = true
	else:
		var cost: int = data.levels[building.current_level]["cost"]
		_upgrade_label.text = "%dg" % cost
		upgrade_btn.disabled = not GameState.can_afford(cost)
	upgrade_btn.modulate = Color(1, 1, 1, 0.5) if upgrade_btn.disabled else Color.WHITE

	if building.building_id == "portal":
		_refresh_enemy_list(data)
	elif building.building_id == "shrine":
		_refresh_shrine_content(data)
	else:
		_refresh_level_info(data)


## Generic buildings (town hall, blacksmith, tavern): show what the current and
## next level actually give, straight from the levels[] data.
func _refresh_level_info(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()
	var now: Dictionary = data.levels[building.current_level - 1]
	content_list.add_child(_dark_label("Now:  " + _format_level(now), 250.0))
	if building.current_level < data.levels.size():
		var next: Dictionary = data.levels[building.current_level]
		content_list.add_child(_dark_label("Next:  %s" % _format_level(next), 250.0))
		content_list.add_child(_dark_label("Upgrade cost: %dg" % next["cost"], 250.0))
	else:
		content_list.add_child(_dark_label("Fully upgraded.", 250.0))


func _format_level(level_data: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in level_data:
		if key == "cost" or key == "label":
			continue
		parts.append("%s %s" % [str(key).capitalize(), str(level_data[key])])
	return ", ".join(parts) if parts.size() > 0 else "-"


func _refresh_enemy_list(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()

	var current_tier: int = data.levels[building.current_level - 1]["enemy_tier"]
	for enemy in GameData.ENEMIES.values():
		if enemy.tier > current_tier:
			continue

		var row := HBoxContainer.new()

		var info := _dark_label("%s (T%d)  %d-%dg %d-%ds" % [
			enemy.display_name, enemy.tier,
			enemy.gold_min, enemy.gold_max,
			enemy.shard_min, enemy.shard_max,
		])
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

		var info := _dark_label("%s (%s, %s)" % [hero.display_name, HeroData.Rarity.keys()[hero.rarity].capitalize(), HeroData.HeroClass.keys()[hero.hero_class].capitalize()])
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
		var result_label := _dark_label(_shrine_result_text, 250.0)
		result_label.add_theme_color_override("font_color", Color(0.5, 0.28, 0.08))
		content_list.add_child(result_label)

	content_list.add_child(_dark_label("Roster (%d/%d)" % [GameState.owned_heroes.size(), GameState.HERO_CAP]))

	for hero_id in GameState.owned_heroes.keys():
		var hero: HeroData = GameData.HEROES[hero_id]
		var row := HBoxContainer.new()

		var info := _dark_label("%s (%s) ★%d" % [hero.display_name, HeroData.HeroClass.keys()[hero.hero_class].capitalize(), GameState.owned_heroes[hero_id]])
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
	var pool: Array = GameData.HEROES.values().filter(func(h): return HeroData.Rarity.keys()[h.rarity].to_lower() == rarity)
	if pool.is_empty():
		pool = GameData.HEROES.values().filter(func(h): return h.rarity == HeroData.Rarity.COMMON)
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
	sfx.play("upgrade")
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
	var prev_star: int = GameState.owned_heroes.get(hero_id, 0)
	if not GameState.buy_hero(hero_id, cost_gold, cost_shard):
		return
	var new_star: int = GameState.owned_heroes.get(hero_id, 0)

	if prev_star == 0:
		_shrine_result_text = "New hero: %s (%s)!" % [hero.display_name, HeroData.Rarity.keys()[hero.rarity].capitalize()]
		hero_acquired.emit(hero_id, building)
	elif new_star > prev_star:
		_shrine_result_text = "%s merged to ★%d!" % [hero.display_name, new_star]
	else:
		_shrine_result_text = "%s already at max ★%d! +%d shards" % [hero.display_name, GameState.MAX_STAR, hero.dupe_shard]
	fx.spawn("pickup_sparkle", global_position + size * 0.5, {"parent": get_parent()})
	fx.popup(_shrine_result_text, global_position + Vector2(size.x * 0.5, -20.0),
			{"parent": get_parent(), "font_size": 20, "color": Color("#ffd23f")})
	sfx.play("summon")

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
