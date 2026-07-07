extends Node3D

const BuildingBase = preload("res://scenes/building_base.tscn")

var camera: Camera3D
var ghost: Node3D

func _ready() -> void:
	get_viewport().physics_object_picking = true
	camera = get_viewport().get_camera_3d()
