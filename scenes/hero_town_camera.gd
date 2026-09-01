extends Camera2D
class_name HeroTownCamera

## Board-view camera: WASD / middle-drag pan, wheel zoom, all smoothed.
## Camera2D.zoom scales what's drawn directly (displayed_size = native_size *
## zoom), so larger values magnify (zoom in) and smaller values shrink (zoom out).

const PAN_SPEED := 480.0
const SMOOTHING := 8.0
const ZOOM_OUT_LIMIT := 1.0
const ZOOM_IN_LIMIT := 3.0
const ZOOM_STEP := 0.2
const ZOOM_DEFAULT := 2.0
## ponytail: matches the 12x5 board in town_2d.tscn (GridSystem CELL_SIZE=64,
## centered on origin). If the board size changes, update these too.
const PAN_MIN := Vector2(-260.0, -100.0)
const PAN_MAX := Vector2(260.0, 100.0)

var _target_pos := Vector2.ZERO
var _target_zoom := ZOOM_DEFAULT
var _zoom := ZOOM_DEFAULT

func _ready() -> void:
	zoom = Vector2.ONE * _zoom
	_target_pos = position

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		pan.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		_target_pos += pan.normalized() * PAN_SPEED * delta
	_target_pos = _target_pos.clamp(PAN_MIN, PAN_MAX)

	position = position.lerp(_target_pos, SMOOTHING * delta)
	_zoom = lerpf(_zoom, _target_zoom, SMOOTHING * delta)
	zoom = Vector2.ONE * _zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_OUT_LIMIT, ZOOM_IN_LIMIT)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_OUT_LIMIT, ZOOM_IN_LIMIT)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_target_pos -= event.relative / _zoom
		_target_pos = _target_pos.clamp(PAN_MIN, PAN_MAX)
