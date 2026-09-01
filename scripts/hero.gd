class_name Hero
extends Character

@export var hero_data: HeroData
@export var patrol_start_x: float = 0.0
@export var patrol_end_x: float = 0.0
@export var revive_delay: float = 5.0  ## seconds a downed hero rests before reviving at full hp

const STAR_STAT_MULT := 0.5  # +50% max_hp/atk per star above 1
const PATROL_HALF_RANGE := 100.0  # px
const PATROL_SPEED_MULT := 0.45

var _patrol_dir: int = 1


func _ready() -> void:
	apply_hero_data()
	super._ready()
	add_to_group("heroes")
	# Idle heroes stroll around where they spawned instead of standing frozen.
	if absf(patrol_end_x - patrol_start_x) < 0.01:
		patrol_start_x = clampf(global_position.x - PATROL_HALF_RANGE + randf_range(-25.0, 25.0),
				PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)
		patrol_end_x = clampf(global_position.x + PATROL_HALF_RANGE + randf_range(-25.0, 25.0),
				PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)


func _get_sprite_frames() -> SpriteFrames:
	var hero_class := hero_data.hero_class if hero_data != null else HeroData.HeroClass.WARRIOR
	return Art.hero_sprite_frames(hero_class)


## Applies hero_data's base stats, then this hero's class buff if active.
## Resets to hero_data's raw values first, so re-running never stacks a buff twice.
## Safe to call anytime after spawn (e.g. on roster changes) without touching current hp.
func apply_hero_data() -> void:
	if hero_data == null:
		return
	var star: int = GameState.owned_heroes.get(hero_data.id, 1)
	var star_mult := 1.0 + (star - 1) * STAR_STAT_MULT
	max_hp = hero_data.base_hp * star_mult
	atk = hero_data.base_power * star_mult
	atk_speed = hero_data.atk_speed
	mana_per_hit = hero_data.mana_per_hit
	is_ranged = hero_data.unit_type == HeroData.UnitType.RANGED
	attack_range = RANGED_ATTACK_RANGE if is_ranged else MELEE_ATTACK_RANGE
	if GameState.has_class_buff(hero_data.hero_class):
		var buff: Dictionary = GameState.CLASS_BUFFS.get(hero_data.hero_class, {})
		if buff.has("stat"):
			set(buff["stat"], get(buff["stat"]) * buff["mult"])


func _update_move(_delta: float) -> void:
	_chase_and_engage("enemies")


func get_own_group() -> String:
	return "heroes"


func _idle_move() -> void:
	_patrol()


func _patrol() -> void:
	if absf(patrol_end_x - patrol_start_x) < 0.01:
		velocity = Vector2.ZERO
		return
	if global_position.x >= patrol_end_x:
		_patrol_dir = -1
	elif global_position.x <= patrol_start_x:
		_patrol_dir = 1
	velocity = Vector2(_patrol_dir * move_speed * PATROL_SPEED_MULT, 0.0)


func _should_knockback(attacker: Character) -> bool:
	return attacker is Enemy and attacker.is_boss


## Falls, plays dead a moment, then revives.
func _die() -> void:
	collision_layer = 0
	if sprite != null:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
		sprite.rotation = deg_to_rad(-90.0)
	get_tree().create_timer(revive_delay).timeout.connect(_revive)


func _revive() -> void:
	if not is_instance_valid(self):
		return
	hp = max_hp
	state = State.MOVE
	collision_layer = HITBOX_LAYER
	_update_health_bar()
	_action_lock_until_msec = 0
	if sprite != null:
		sprite.rotation = 0.0
		sprite.modulate = Color.WHITE
		sprite.play("idle")
		sprite.scale = Vector2.ONE * SPRITE_SCALE * 0.3
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fx.spawn("pickup_sparkle", global_position + Vector2(0, -60.0))
