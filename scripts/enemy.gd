class_name Enemy
extends Character

@export var is_boss: bool = false
@export var enemy_data: EnemyData

const COIN = preload("res://scenes/coin.tscn")
const BOSS_SCALE := 1.4
const SPAWN_FREEZE := 0.5  # seconds standing still right after spawning


func _ready() -> void:
	if enemy_data != null:
		max_hp = enemy_data.hp
		atk = enemy_data.atk
	super._ready()
	add_to_group("enemies")
	if is_boss and sprite != null:
		sprite.scale *= BOSS_SCALE
	# Brief freeze so simultaneously-spawned enemies don't all lunge on frame 1.
	velocity = Vector2.ZERO
	knockback_timer = SPAWN_FREEZE
	state = State.KNOCKBACK


func _get_sprite_frames() -> SpriteFrames:
	var tier: int = enemy_data.tier if enemy_data != null else 1
	return Art.enemy_sprite_frames(tier)


func _update_move(_delta: float) -> void:
	_chase_and_engage("heroes")


func get_own_group() -> String:
	return "enemies"


func _on_death() -> void:
	GameState.add(randi_range(enemy_data.gold_min, enemy_data.gold_max),
			randi_range(enemy_data.shard_min, enemy_data.shard_max))
	spawn_coin()
	fx.spawn("hit_burst", global_position + Vector2(0, -50.0))
	fx.flash(Color.WHITE, 0.1, 0.08)


## Fades and sinks away, then frees.
func _die() -> void:
	collision_layer = 0
	var tween := create_tween()
	if sprite != null:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 12.0, 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func spawn_coin() -> void:
	if not is_inside_tree():
		return
	var canvas_layer := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas_layer == null:
		return
	# Coin animates in screen/canvas space (it flies to a HUD icon), so its
	# spawn position is converted from world space once, up front.
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * global_position
	var coin := COIN.instantiate() as Node2D
	if not coin:
		return
	coin.position = screen_pos
	canvas_layer.add_child(coin)
