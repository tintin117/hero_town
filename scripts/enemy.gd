class_name Enemy
extends Character

@export var move_direction: Vector3 = Vector3.LEFT
@export var is_boss: bool = false
@export var enemy_data: EnemyData


func _ready() -> void:
	super._ready()
	add_to_group("enemies")


func _update_move(_delta: float) -> void:
	_chase_and_engage("heroes")


func _idle_move() -> void:
	velocity = move_direction.normalized() * stats.move_speed


func _on_death() -> void:
	if enemy_data == null:
		return
	GameState.add(randi_range(enemy_data.gold_min, enemy_data.gold_max),
			randi_range(enemy_data.shard_min, enemy_data.shard_max))
