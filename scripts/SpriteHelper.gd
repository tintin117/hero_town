class_name SpriteHelper

static func face_camera(node: Node3D) -> void:
	node.rotation = Vector3(
		deg_to_rad(CONFIG.CAMERA_VERTICAL_ANGLE),
		deg_to_rad(CONFIG.CAMERA_PERSPECTIVE_ANGLE),
		0
	)

static func rotate_to_camera(node: Node3D) -> void:
	node.rotation = Vector3(
		0,
		deg_to_rad(CONFIG.CAMERA_PERSPECTIVE_ANGLE),
		0
	)
