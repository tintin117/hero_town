class_name Enemy
extends Character

@export var move_direction: Vector3 = Vector3.LEFT
@export var is_boss: bool = false
@export var enemy_data: EnemyData
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const COIN = preload("res://scenes/coin.tscn")

func _ready() -> void:
	super._ready()
	add_to_group("enemies")


func _update_move(_delta: float) -> void:
	anim_player.play("move")
	_chase_and_engage("heroes")


func _idle_move() -> void:
	velocity = move_direction.normalized() * stats.move_speed


func _on_death() -> void:
	if enemy_data == null:
		spawn_coin()
		return
	GameState.add(randi_range(enemy_data.gold_min, enemy_data.gold_max),
			randi_range(enemy_data.shard_min, enemy_data.shard_max))

func spawn_coin() -> void:
	if not is_inside_tree():
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	# Convert 3D position to 2D screen position
	var world_pos = global_position + Vector3(0, 0, 0)
	var screen_pos = camera.unproject_position(world_pos)

	var coin = COIN.instantiate() as Node2D
	if not coin:
		return

	coin.position = screen_pos
	get_tree().current_scene.add_child(coin)
