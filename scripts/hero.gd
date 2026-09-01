class_name Hero
extends Character

@export var hero_data: HeroData
@export var patrol_start_x: float = 0.0
@export var patrol_end_x: float = 0.0
@export var revive_delay: float = 5.0  ## seconds a downed hero rests before reviving at full hp

const STAR_STAT_MULT := 0.5  # +50% max_hp/atk per star above 1
const PATROL_HALF_RANGE := 3.0
const PATROL_SPEED_MULT := 0.45

const CLASS_MODELS := {
	HeroData.HeroClass.WARRIOR: preload("res://asset/kaykit/adventurers/Knight.glb"),
	HeroData.HeroClass.ROGUE: preload("res://asset/kaykit/adventurers/Rogue.glb"),
	HeroData.HeroClass.MAGE: preload("res://asset/kaykit/adventurers/Mage.glb"),
	HeroData.HeroClass.CLERIC: preload("res://asset/kaykit/adventurers/Barbarian.glb"),
}

var _patrol_dir: int = 1


func _ready() -> void:
	apply_hero_data()
	super._ready()
	add_to_group("heroes")
	# Idle heroes stroll around where they spawned instead of standing frozen.
	if absf(patrol_end_x - patrol_start_x) < 0.01:
		patrol_start_x = clampf(global_position.x - PATROL_HALF_RANGE + randf_range(-0.8, 0.8),
				PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)
		patrol_end_x = clampf(global_position.x + PATROL_HALF_RANGE + randf_range(-0.8, 0.8),
				PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)


func _get_model_scene() -> PackedScene:
	if hero_data == null:
		return CLASS_MODELS[HeroData.HeroClass.WARRIOR]
	return CLASS_MODELS.get(hero_data.hero_class, CLASS_MODELS[HeroData.HeroClass.WARRIOR])


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
		velocity = Vector3.ZERO
		return
	if global_position.x >= patrol_end_x:
		_patrol_dir = -1
	elif global_position.x <= patrol_start_x:
		_patrol_dir = 1
	velocity = Vector3(_patrol_dir * move_speed * PATROL_SPEED_MULT, 0.0, 0.0)


func _should_knockback(attacker: Character) -> bool:
	return attacker is Enemy and attacker.is_boss


## Falls where they stood (Death_A already playing from take_damage), then revives.
func _die() -> void:
	collision_layer = 0
	get_tree().create_timer(revive_delay).timeout.connect(_revive)


func _revive() -> void:
	if not is_instance_valid(self):
		return
	hp = max_hp
	state = State.MOVE
	collision_layer = HITBOX_LAYER
	_update_health_bar()
	_action_lock_until_msec = 0
	if _anim != null:
		_anim.play("Idle")
	if model != null:
		model.scale = Vector3.ONE * MODEL_SCALE * 0.3
		var tween := create_tween()
		tween.tween_property(model, "scale", Vector3.ONE * MODEL_SCALE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		fx.spawn("pickup_sparkle", camera.unproject_position(global_position + Vector3.UP))
