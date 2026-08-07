extends PanelContainer

signal move_requested(building: BuildingBase)

@onready var title_label: Label = $VBox/TitleLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var upgrade_btn: Button = $VBox/UpgradeButton

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
