extends Node3D

const BuildingBase = preload("res://scenes/building_base.tscn")

var camera: Camera3D
var ghost: Node3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	ghost = BuildingBase.instantiate()
	add_child(ghost)
	ghost.position = Vector3(1, 2, 0)

func _process(_delta: float) -> void:
	if not camera or not ghost:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var world_x := mouse_to_ground_x(mouse_pos)
	ghost.position.x = world_x
	print(ghost.is_overlapping())

func mouse_to_ground_x(mouse_pos: Vector2) -> float:
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var t := -ray_origin.y / ray_dir.y
	return ray_origin.x + t * ray_dir.x
