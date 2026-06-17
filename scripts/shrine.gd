extends Node2D

signal hero_rolled(hero_id: String, is_duplicate: bool, shard_gain: int)
signal clicked

var level := 1
var th_level := 1

var _shrine_levels: Array = []
var _heroes: Dictionary = {}

func _ready() -> void:
	if has_node("ClickArea"):
		$ClickArea.input_event.connect(_on_click_area_input_event)

func setup(shrine_levels: Array, heroes: Dictionary) -> void:
	_shrine_levels = shrine_levels
	_heroes = heroes

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func roll_cost_gold() -> int:
	if _shrine_levels.is_empty():
		return 100
	return _shrine_levels[level - 1].get("roll_gold", 100) as int

func roll_cost_shard() -> int:
	if _shrine_levels.is_empty():
		return 10
	return _shrine_levels[level - 1].get("roll_shard", 10) as int

func next_upgrade_cost() -> int:
	if _shrine_levels.is_empty() or level >= _shrine_levels.size():
		return -1
	return _shrine_levels[level].get("cost", 0) as int

func roll(discovered_heroes: Array) -> void:
	if _shrine_levels.is_empty():
		return
	var weights: Dictionary = _shrine_levels[level - 1].get("weights", {})
	var rarity := _weighted_pick(weights)

	# Build pool: heroes of this rarity unlocked at current TH level
	var pool: Array = []
	for hdata in _heroes.values():
		if (hdata.get("rarity", "") as String).to_lower() == rarity and \
				(hdata.get("th_unlock", 1) as int) <= th_level:
			pool.append(hdata)

	if pool.is_empty():
		# Fallback to common if nothing in pool
		for hdata in _heroes.values():
			if (hdata.get("rarity", "") as String).to_lower() == "common":
				pool.append(hdata)

	if pool.is_empty():
		return

	var chosen: Dictionary = pool[randi() % pool.size()]
	var hero_id: String = chosen["id"] as String
	var is_dupe: bool = hero_id in discovered_heroes
	var shard_gain: int = chosen.get("dupe_shard", 5) as int if is_dupe else 0
	hero_rolled.emit(hero_id, is_dupe, shard_gain)

func upgrade(current_gold: int) -> int:
	if _shrine_levels.is_empty() or level >= _shrine_levels.size():
		return current_gold
	var cost: int = _shrine_levels[level].get("cost", 0) as int
	if current_gold < cost:
		return current_gold
	level += 1
	return current_gold - cost

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
