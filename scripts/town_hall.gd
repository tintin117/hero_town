extends Node2D

signal level_cap_changed(new_cap: int)
signal clicked

var level := 1
var _th_levels: Array = []

func _ready() -> void:
	if has_node("ClickArea"):
		$ClickArea.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func setup(th_levels: Array) -> void:
	_th_levels = th_levels

func hero_level_cap() -> int:
	if _th_levels.is_empty():
		return 10
	return _th_levels[level - 1]["hero_level_cap"] as int

func upgrade(current_gold: int) -> int:
	if level >= _th_levels.size():
		return current_gold
	var cost: int = _th_levels[level]["cost"] as int
	if current_gold < cost:
		return current_gold
	level += 1
	emit_signal("level_cap_changed", hero_level_cap())
	return current_gold - cost

func next_upgrade_cost() -> int:
	if _th_levels.is_empty() or level >= _th_levels.size():
		return -1
	return _th_levels[level]["cost"] as int

func next_hero_cap() -> int:
	if _th_levels.is_empty() or level >= _th_levels.size():
		return hero_level_cap()
	return _th_levels[level]["hero_level_cap"] as int
