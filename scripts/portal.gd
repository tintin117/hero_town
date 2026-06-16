extends Node2D

signal enemy_ready(enemy_id: String)
signal clicked

var level := 1
var _portal_levels: Array = []
var _enemies: Dictionary = {}
var _available_enemies: Array = []
var _enemy_active := false

@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	if has_node("ClickArea"):
		$ClickArea.input_event.connect(_on_click_area_input_event)

func setup(portal_levels: Array, enemies: Dictionary) -> void:
	_portal_levels = portal_levels
	_enemies = enemies
	_refresh_enemy_pool()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start(_get_spawn_time())

func _refresh_enemy_pool() -> void:
	if _portal_levels.is_empty():
		return
	var tier: int = _portal_levels[level - 1]["enemy_tier"] as int
	_available_enemies = []
	for key: String in _enemies:
		if (_enemies[key]["tier"] as int) <= tier:
			_available_enemies.append(key)

func _get_spawn_time() -> float:
	if _available_enemies.is_empty():
		return 5.0
	return _enemies[_pick_enemy_id()]["spawn_time"] as float

func _pick_enemy_id() -> String:
	var best: String = _available_enemies[0]
	for id: String in _available_enemies:
		if (_enemies[id]["tier"] as int) > (_enemies[best]["tier"] as int):
			best = id
	return best

func _on_spawn_timer_timeout() -> void:
	if _enemy_active:
		return
	_enemy_active = true
	emit_signal("enemy_ready", _pick_enemy_id())

func on_enemy_died() -> void:
	_enemy_active = false
	spawn_timer.start(_get_spawn_time())

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func upgrade(current_gold: int) -> int:
	if level >= _portal_levels.size():
		return current_gold
	var cost: int = _portal_levels[level]["cost"] as int
	if current_gold < cost:
		return current_gold
	level += 1
	_refresh_enemy_pool()
	return current_gold - cost
