extends Node3D
class_name HeroTownCamera

@onready var perspective_container: Node3D = %PerspectiveContainer
@onready var camera_3d: Camera3D = $PerspectiveContainer/Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_perspective()
	setup_distance()
	setup_angle()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func setup_perspective() -> void:
	perspective_container.rotate_y(CONFIG.CAMERA_PERSPECTIVE_ANGLE)
	
func setup_distance() -> void:
	var vector: Vector3 = Vector3.ZERO
	
	vector.z = CONFIG.CAMERA_DISTANCE
	
	vector = vector.rotated(Vector3(1, 0, 0), deg_to_rad(CONFIG.CAMERA_VERTICAL_ANGLE))
	camera_3d.position += vector

func setup_angle() -> void:
	camera_3d.rotation_degrees.x = CONFIG.CAMERA_VERTICAL_ANGLE
