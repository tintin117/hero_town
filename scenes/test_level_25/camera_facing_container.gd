extends Node3D

class_name CameraFacingContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SpriteHelper.face_camera(self)
