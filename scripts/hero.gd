class_name Hero
extends Character

@export var patrol_start_x: float = 0.0
@export var patrol_end_x: float = 0.0

var _patrol_dir: int = 1


func _ready() -> void:
	super._ready()
	add_to_group("heroes")


func _update_move(_delta: float) -> void:
	var enemy := _find_nearest_in_group("enemies")
	if enemy != null and global_position.distance_to(enemy.global_position) <= attack_range:
		_enter_combat(enemy)
		return
	if enemy != null:
		var dir := signf(enemy.global_position.x - global_position.x)
		velocity = Vector3(dir * move_speed, 0.0, 0.0)
	else:
		_patrol()


func _patrol() -> void:
	if absf(patrol_end_x - patrol_start_x) < 0.01:
		velocity = Vector3.ZERO
		return
	if global_position.x >= patrol_end_x:
		_patrol_dir = -1
	elif global_position.x <= patrol_start_x:
		_patrol_dir = 1
	velocity = Vector3(_patrol_dir * move_speed, 0.0, 0.0)


func _should_knockback(attacker: Character) -> bool:
	return attacker is Enemy and attacker.is_boss
