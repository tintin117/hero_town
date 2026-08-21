class_name Enemy
extends Character

@export var is_boss: bool = false
@export var enemy_data: EnemyData
@onready var anim_player: AnimationPlayer = $AnimationPlayer

const COIN = preload("res://scenes/coin.tscn")

func _ready() -> void:
	if enemy_data != null:
		max_hp = enemy_data.hp
		atk = enemy_data.atk
	super._ready()
	add_to_group("enemies")


func _update_move(_delta: float) -> void:
	anim_player.play("move")
	_chase_and_engage("heroes")


func _on_death() -> void:
	GameState.add(randi_range(enemy_data.gold_min, enemy_data.gold_max),
			randi_range(enemy_data.shard_min, enemy_data.shard_max))
	spawn_coin()

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
