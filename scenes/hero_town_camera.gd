extends Node3D
class_name HeroTownCamera

## Tilted board camera with WASD / middle-drag pan and wheel zoom, all smoothed.

const PAN_SPEED := 10.0
const SMOOTHING := 8.0
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.5
const ZOOM_STEP := 0.1
const PAN_MIN := Vector3(-8.0, 0, -3.0)
const PAN_MAX := Vector3(8.0, 0, 4.0)

@onready var camera_3d: Camera3D = $PerspectiveContainer/Camera3D

var _target_pos := Vector3.ZERO
var _target_zoom := 1.0
var _zoom := 1.0
var _base_offset := Vector3.ZERO

func _ready() -> void:
	_base_offset = Vector3(0, 0, CONFIG.CAMERA_DISTANCE) \
			.rotated(Vector3.RIGHT, deg_to_rad(CONFIG.CAMERA_VERTICAL_ANGLE))
	camera_3d.rotation_degrees.x = CONFIG.CAMERA_VERTICAL_ANGLE
	camera_3d.position = _base_offset
	_target_pos = position

func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		pan.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		pan.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		pan.x += 1.0
	_target_pos += pan.normalized() * PAN_SPEED * delta if pan != Vector3.ZERO else Vector3.ZERO
	_target_pos = _target_pos.clamp(PAN_MIN, PAN_MAX)

	position = position.lerp(_target_pos, SMOOTHING * delta)
	_zoom = lerpf(_zoom, _target_zoom, SMOOTHING * delta)
	camera_3d.position = _base_offset * _zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		# Drag pans in screen space: screen x -> world x, screen y -> world z.
		var drag_scale := 0.022 * _zoom
		_target_pos += Vector3(-event.relative.x * drag_scale, 0, -event.relative.y * drag_scale)
		_target_pos = _target_pos.clamp(PAN_MIN, PAN_MAX)
