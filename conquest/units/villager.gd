class_name ConquestVillager
extends Node2D

@export var villager_id := ""
@export var display_name := "Villager"
@export var initial_spot_id := ""
@export_range(1.0, 1000.0) var move_speed := 65.0
var destination: ConquestResourceSpot
var home: Vector2

func _ready() -> void:
	home = position

func _process(delta: float) -> void:
	var target: Vector2 = get_parent().to_global(home)
	if is_instance_valid(destination): target = destination.get_node("WorkPosition").global_position
	var moving := global_position.distance_to(target) > 1.0
	if moving:
		$Visual.flip_h = target.x < global_position.x
		global_position = global_position.move_toward(target, move_speed * delta)
	moving = global_position.distance_to(target) > 1.0
	var job: String = destination.gathering.resource_type if is_instance_valid(destination) else "wood"
	$Visual.play("walk_" + job if moving else ("work_" + job if is_instance_valid(destination) else "idle"))
