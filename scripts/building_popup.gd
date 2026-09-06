extends Control

signal move_requested(building: BuildingBase)
signal spawn_requested(enemy_id: String, building: BuildingBase)
signal hero_building_changed(building: BuildingBase)

@onready var title_label: Label = $"../BuildingPopup/VBoxContainer/LabelControl/Label"
@onready var level_label: Label = $"../BuildingPopup/VBoxContainer/LevelControl/Level"
@onready var upgrade_btn: TextureButton = $"../BuildingPopup/VBoxContainer/ActionButton/HBoxContainer/Upgrade"
@onready var content_list: VBoxContainer = $"../BuildingPopup/VBoxContainer/SelectionGrid/ScrollContainer/GridContainer"

var building: BuildingBase = null
var _reward_offers: Array[Dictionary] = []
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
	_reward_offers = []
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
	elif building.building_id == "barracks":
		_refresh_hero_building_content(data)
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


## Shows the building's current active hero/tier, squad size, accumulated stat
## buffs, and (once an upgrade has just been paid for) the 3 reward choices.
func _refresh_hero_building_content(data: BuildingData) -> void:
	for child in content_list.get_children():
		child.queue_free()

	var hero: HeroData = GameData.HEROES.get(building.active_hero_id())
	if hero != null:
		content_list.add_child(_dark_label(
				"%s (%s)" % [hero.display_name, HeroData.Rarity.keys()[hero.rarity].capitalize()], 250.0))
	content_list.add_child(_dark_label("Squad size: %d" % building.squad_count))
	for stat in building.stat_buffs:
		var pct := roundi((building.stat_buffs[stat] - 1.0) * 100.0)
		content_list.add_child(_dark_label("%s +%d%%" % [str(stat).capitalize(), pct]))

	if not _reward_offers.is_empty():
		content_list.add_child(_dark_label("Choose a reward:", 250.0))
		for reward in _reward_offers:
			var btn := Button.new()
			btn.text = _describe_reward(reward)
			btn.pressed.connect(_on_reward_picked.bind(reward))
			content_list.add_child(btn)


func _describe_reward(reward: Dictionary) -> String:
	match reward["type"]:
		"tier_up":
			return "Unlock next tier"
		"count_up":
			return "+1 squad size"
		"stat_buff":
			return "+%d%% %s" % [reward["pct"], str(reward["stat"]).capitalize()]
		_:
			return "?"


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
	if building.building_id == "barracks":
		_reward_offers = building.roll_reward_offers()
	_refresh()


func _on_move_button_pressed() -> void:
	move_requested.emit(building)
	close()


func _on_close_button_pressed() -> void:
	visible = false


func _on_reward_picked(reward: Dictionary) -> void:
	building.apply_reward(reward)
	_reward_offers = []
	hero_building_changed.emit(building)
	fx.spawn("pickup_sparkle", global_position + size * 0.5, {"parent": get_parent()})
	sfx.play("summon")
	_refresh()
