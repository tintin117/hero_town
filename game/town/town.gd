extends Control
## Scrollable town strip: 48x8 cells of 32 px (16 px art at 2x) shown through this control.
## Owned land is columns 10-37, the arena reserves 16-31, row 7 is the public path.
## Pure view: it holds no game state. Dim outer land is drawn by oversized rects in `World/Dim`.

signal scrolled(x: float)
signal cell_clicked(cell: Vector2i)
signal pressed(cell: Vector2i)  ## left button down on a cell (for hold gestures)
signal released  ## left button up anywhere

const CELL := 32
const GRID := Vector2i(48, 8)
const WORLD_SIZE := Vector2(GRID * CELL)
const ARENA_CENTER_CELL := 24.0
const WHEEL_STEP := 96.0
const CLICK_SLOP := 4.0

var scroll_x := 0.0
var _user_scrolled := false
var _press_position := Vector2.ZERO

@onready var world: Node2D = $World
@onready var bar: HScrollBar = $ScrollBar


func _ready() -> void:
	bar.value_changed.connect(_on_bar_changed)
	resized.connect(_on_resized)
	center_on_arena()


func max_scroll() -> float:
	return maxf(0.0, WORLD_SIZE.x - size.x)


func center_on(cell_x: float) -> void:
	_user_scrolled = false
	_scroll_to(cell_x * CELL - size.x / 2.0)


func center_on_arena() -> void:
	center_on(ARENA_CENTER_CELL)


## Cell under a point given in this control's coordinates (may lie outside the grid).
func cell_for_point(p: Vector2) -> Vector2i:
	return Vector2i(((p - world.position) / CELL).floor())


## Centre of a cell in this control's coordinates.
func point_for_cell(c: Vector2i) -> Vector2:
	return world.position + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _scroll_to(x: float) -> void:
	scroll_x = clampf(roundf(x), 0.0, max_scroll())
	# A control wider than the strip centres it; otherwise the strip slides under the clip.
	var x_pos := -scroll_x if max_scroll() > 0.0 else floorf((size.x - WORLD_SIZE.x) / 2.0)
	world.position = Vector2(x_pos, floorf((size.y - WORLD_SIZE.y) / 2.0))
	bar.visible = max_scroll() > 0.0
	bar.max_value = WORLD_SIZE.x
	bar.page = minf(size.x, WORLD_SIZE.x)
	bar.set_value_no_signal(scroll_x)
	scrolled.emit(scroll_x)


func _scroll_by_user(x: float) -> void:
	_user_scrolled = true
	_scroll_to(x)


func _on_bar_changed(value: float) -> void:
	_scroll_by_user(value)


func _on_resized() -> void:
	if _user_scrolled:
		_scroll_to(scroll_x)
	else:
		center_on_arena()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_scroll_by_user(scroll_x - event.relative.x)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press_position = event.position
					pressed.emit(cell_for_point(event.position))
				else:
					released.emit()
					if event.position.distance_to(_press_position) <= CLICK_SLOP:
						var cell := cell_for_point(event.position)
						if Rect2i(Vector2i.ZERO, GRID).has_point(cell):
							cell_clicked.emit(cell)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				if event.pressed and (event.shift_pressed or event.button_index == MOUSE_BUTTON_WHEEL_LEFT):
					_scroll_by_user(scroll_x - WHEEL_STEP)
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				if event.pressed and (event.shift_pressed or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT):
					_scroll_by_user(scroll_x + WHEEL_STEP)
