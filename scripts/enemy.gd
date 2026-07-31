class_name Enemy
extends Character

@export var move_direction: Vector3 = Vector3.LEFT
@export var is_boss: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("enemies")


func _update_move(_delta: float) -> void:
	var hero := _find_nearest_in_group("heroes")
	if hero != null and global_position.distance_to(hero.global_position) <= attack_range:
		_enter_combat(hero)
		return
	velocity = move_direction.normalized() * move_speed
