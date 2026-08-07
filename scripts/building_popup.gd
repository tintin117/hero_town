extends PanelContainer

signal move_requested(building: BuildingBase)
signal spawn_requested(enemy_id: String, building: BuildingBase)

@onready var title_label: Label = $VBox/TitleLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var enemy_list: VBoxContainer = $VBox/EnemyList

var building: BuildingBase = null


func _ready() -> void:
	visible = false


func open(target: BuildingBase) -> void:
	building = target
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
	else:
		for child in enemy_list.get_children():
			child.queue_free()


func _refresh_enemy_list(data: BuildingData) -> void:
	for child in enemy_list.get_children():
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

		enemy_list.add_child(row)


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
