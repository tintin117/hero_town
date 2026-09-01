class_name Enemy
extends Character

@export var is_boss: bool = false
@export var enemy_data: EnemyData

const COIN = preload("res://scenes/coin.tscn")
const BOSS_SCALE := 1.4
const SPAWN_FREEZE := 1.1  # seconds standing still while the spawn animation plays

const TIER_MODELS := {
	1: preload("res://asset/kaykit/skeletons/Skeleton_Minion.glb"),
	2: preload("res://asset/kaykit/skeletons/Skeleton_Minion.glb"),
	3: preload("res://asset/kaykit/skeletons/Skeleton_Rogue.glb"),
	4: preload("res://asset/kaykit/skeletons/Skeleton_Warrior.glb"),
	5: preload("res://asset/kaykit/skeletons/Skeleton_Mage.glb"),
}


func _ready() -> void:
	if enemy_data != null:
		max_hp = enemy_data.hp
		atk = enemy_data.atk
	super._ready()
	add_to_group("enemies")
	if is_boss and model != null:
		model.scale *= BOSS_SCALE
	# Rise-from-the-ground entrance; KNOCKBACK with zero velocity holds them in place.
	_play_action("Spawn_Ground_Skeletons")
	velocity = Vector3.ZERO
	knockback_timer = SPAWN_FREEZE
	state = State.KNOCKBACK


func _get_model_scene() -> PackedScene:
	var tier: int = enemy_data.tier if enemy_data != null else 1
	return TIER_MODELS.get(clampi(tier, 1, 5), TIER_MODELS[1])


func _update_move(_delta: float) -> void:
	_chase_and_engage("heroes")


func get_own_group() -> String:
	return "enemies"


func _on_death() -> void:
	GameState.add(randi_range(enemy_data.gold_min, enemy_data.gold_max),
			randi_range(enemy_data.shard_min, enemy_data.shard_max))
	spawn_coin()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		fx.spawn("hit_burst", camera.unproject_position(global_position + Vector3.UP * 0.8))
	fx.flash(Color.WHITE, 0.1, 0.08)


## Death_A plays (started by take_damage), then the corpse sinks away and frees.
func _die() -> void:
	collision_layer = 0
	var tween := create_tween()
	tween.tween_interval(1.0)
	if model != null:
		tween.tween_property(model, "position:y", -1.4, 0.7) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func spawn_coin() -> void:
	if not is_inside_tree():
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var screen_pos = camera.unproject_position(global_position)
	var coin = COIN.instantiate() as Node2D
	if not coin:
		return
	coin.position = screen_pos
	get_tree().current_scene.add_child(coin)
