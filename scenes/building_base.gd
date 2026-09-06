class_name BuildingBase
extends Node2D

signal clicked
signal auto_spawn_requested(enemy_id: String, building: BuildingBase)

const BUILDING_SCALE := 0.4

@export var building_id: String = ""
var is_ghost: bool = false
var current_level: int = 1
var current_cell: Vector2i = Vector2i(-1, -1)
var suppress_next_click: bool = false

## Hero-producing buildings only (see BuildingData.hero_class): which rarity tier
## is currently active, how many copies fight at once, and accumulated stat buffs
## (stat name -> cumulative multiplier) picked from past upgrade rewards.
var tier: int = 0
var squad_count: int = 1
var stat_buffs: Dictionary = {}

var auto_spawn_enemy_ids: Array[String] = []
var active_enemy_count: int = 0
var _spawn_timer: Timer
var _next_spawn_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var grid_system: GridSystem = get_node("../GridSystem")

func get_data() -> BuildingData:
	return GameData.BUILDINGS[building_id]

func upgrade() -> void:
	current_level += 1
	if not auto_spawn_enemy_ids.is_empty():
		_start_spawning(get_data().levels[current_level - 1]["spawn_interval"])
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 1.15, 0.12)
	tween.tween_property(sprite, "scale", sprite.scale, 0.18).set_trans(Tween.TRANS_BACK)

## Toggles whether `enemy_id` is one of the types this building auto-spawns.
## The single shared timer round-robins between every toggled-on type.
func toggle_auto_spawn(enemy_id: String) -> void:
	if auto_spawn_enemy_ids.has(enemy_id):
		auto_spawn_enemy_ids.erase(enemy_id)
	else:
		auto_spawn_enemy_ids.append(enemy_id)
	if auto_spawn_enemy_ids.is_empty():
		_spawn_timer.stop()
	else:
		_start_spawning(get_data().levels[current_level - 1]["spawn_interval"])

## Timer.start() waits a full interval before its first tick -- spawn one now, timer covers the repeats.
func _start_spawning(interval: float) -> void:
	_spawn_timer.start(interval)
	_on_spawn_timer_timeout()

func _on_spawn_timer_timeout() -> void:
	var active_slots: int = get_data().levels[current_level - 1].get("active_slots", 1)
	if active_enemy_count >= active_slots or auto_spawn_enemy_ids.is_empty():
		return
	_next_spawn_index %= auto_spawn_enemy_ids.size()
	var enemy_id: String = auto_spawn_enemy_ids[_next_spawn_index]
	_next_spawn_index += 1
	active_enemy_count += 1
	auto_spawn_requested.emit(enemy_id, self)

func on_enemy_defeated() -> void:
	active_enemy_count = maxi(0, active_enemy_count - 1)

## The hero_id whose class matches this building and whose rarity matches `tier`.
## Empty string if no such hero is authored (shouldn't happen for tier 0).
func active_hero_id() -> String:
	var hero_class: HeroData.HeroClass = get_data().hero_class
	for hero: HeroData in GameData.HEROES.values():
		if hero.hero_class == hero_class and hero.rarity == tier:
			return hero.id
	return ""

func _has_next_tier() -> bool:
	var hero_class: HeroData.HeroClass = get_data().hero_class
	for hero: HeroData in GameData.HEROES.values():
		if hero.hero_class == hero_class and hero.rarity == tier + 1:
			return true
	return false

## Weighted-picks up to 3 distinct rewards from this building's reward_pool,
## dropping "tier_up" once there's no next rarity authored for this class.
func roll_reward_offers() -> Array[Dictionary]:
	var remaining: Array = get_data().reward_pool.filter(
			func(r): return r["type"] != "tier_up" or _has_next_tier())
	var offers: Array[Dictionary] = []
	for i in mini(3, remaining.size()):
		var pick: Dictionary = _weighted_pick(remaining)
		offers.append(pick)
		remaining.erase(pick)
	return offers

func _weighted_pick(pool: Array) -> Dictionary:
	var total := 0
	for entry in pool:
		total += entry.get("weight", 1) as int
	var roll := randi() % maxi(total, 1)
	var acc := 0
	for entry in pool:
		acc += entry.get("weight", 1) as int
		if roll < acc:
			return entry
	return pool.back()

func apply_reward(reward: Dictionary) -> void:
	match reward["type"]:
		"tier_up":
			tier += 1
		"count_up":
			squad_count += 1
		"stat_buff":
			var stat: String = reward["stat"]
			var pct: float = reward["pct"]
			stat_buffs[stat] = stat_buffs.get(stat, 1.0) * (1.0 + pct / 100.0)

func _ready() -> void:
	if building_id == "":
		return
	_build_sprite()
	if is_ghost:
		sprite.modulate = Color(1, 1, 1, 0.55)
		return
	area.input_event.connect(_on_area_input_event)
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	add_to_group("buildings")
	_register_on_grid()
	_play_spawn_pop()

## Buildings are anchored feet-first (bottom-center at the tile origin), same
## convention as Character, so tall buildings rise from their tile instead of
## straddling it.
func _build_sprite() -> void:
	var tex := get_data().sprite_texture
	if tex == null:
		return
	sprite.texture = tex
	sprite.scale = Vector2.ONE * BUILDING_SCALE
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	_fit_collision_to_sprite(tex)

func _fit_collision_to_sprite(tex: Texture2D) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tex.get_width(), tex.get_height()) * BUILDING_SCALE
	area.get_node("CollisionShape2D").shape = shape
	area.get_node("CollisionShape2D").position = Vector2(0, -tex.get_height() * BUILDING_SCALE * 0.5)

func set_ghost_valid(valid: bool) -> void:
	var tint := Color(0.55, 1.0, 0.6, 0.55) if valid else Color(1.0, 0.4, 0.35, 0.55)
	sprite.modulate = tint

func _play_spawn_pop() -> void:
	var final_scale := sprite.scale
	sprite.scale = final_scale * 0.7
	var tween := create_tween()
	tween.tween_property(sprite, "scale", final_scale, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _register_on_grid() -> void:
	var cell := grid_system.world_to_grid(global_position)
	if cell == Vector2i(-1, -1):
		return
	current_cell = cell
	grid_system.occupy(cell, self)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# ponytail: the click that confirms a move re-enables this Area2D's
		# monitoring before physics picking processes that same click, which
		# would otherwise re-fire `clicked` and reopen the popup.
		if suppress_next_click:
			suppress_next_click = false
			return
		clicked.emit()
