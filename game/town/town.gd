extends Control
## Scrollable town strip: 48x8 cells of 32 px (16 px art at 2x) shown through this control.
## Owned land is columns 10-37, the arena reserves 16-31, row 7 is the public path.
## Pure view: it holds no game state. Dim outer land is drawn by oversized rects in `World/Dim`.

signal scrolled(x: float)
signal cell_clicked(cell: Vector2i)
signal pressed(cell: Vector2i)  ## left button down on a cell (for hold gestures)
signal released  ## left button up anywhere
signal placement_confirmed(id: StringName, cell: Vector2i)  ## left click on a valid cell; the mode has ended
signal placement_cancelled  ## right click, Esc or cancel_placement(); the mode has ended

const CELL := 32
const GRID := Vector2i(48, 8)
const WORLD_SIZE := Vector2(GRID * CELL)
const ARENA_CENTER_CELL := 24.0
const WHEEL_STEP := 96.0
const CLICK_SLOP := 4.0

var scroll_x := 0.0
var placing := false  ## true while a building ghost follows the pointer; pressed/released/cell_clicked stay silent
var _user_scrolled := false
var _press_position := Vector2.ZERO
var _pointer := Vector2(-1, -1)  ## last pointer position in this control's coordinates
var _pointer_inside := false
var _place_id: StringName
var _held := false  ## left button is down and `pressed` has been emitted
var _place_pressed := false
var _hover: StringName = &""

@onready var world: Node2D = $World
@onready var bar: HScrollBar = $ScrollBar
@onready var buildings: Node2D = $World/BuildingLayer/TownBuildings
@onready var ghost: Node2D = $World/PlacementGhost


func _ready() -> void:
	bar.value_changed.connect(_on_bar_changed)
	resized.connect(_on_resized)
	scrolled.connect(func(_x: float) -> void: _follow_pointer())
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


## Building whose footprint covers `cell`, or &"" (asks the game through TownBuildings).
func building_id_at(cell: Vector2i) -> StringName:
	return buildings.building_at(cell)


## Show a ghost of `footprint` cells under the pointer (top-left snapped to its cell). `valid` is
## Callable(cell: Vector2i) -> bool. Left click on a valid cell confirms; right click or Esc cancels.
func begin_placement(id: StringName, footprint: Vector2i, valid: Callable) -> void:
	if placing:
		cancel_placement()
	if _held:  # a hold gesture was in progress: let its listeners finish
		_held = false
		released.emit()
	placing = true
	_place_id = id
	_place_pressed = false
	_set_hover(&"")
	ghost.begin(id, footprint, valid)
	_follow_pointer()


func cancel_placement() -> void:
	if placing:
		_end_placement()
		placement_cancelled.emit()


func _end_placement() -> void:
	placing = false
	ghost.end()


func _follow_pointer() -> void:
	var cell := cell_for_point(_pointer) if _pointer_inside else Vector2i(-1, -1)
	if placing:
		ghost.move_to(cell)
	else:
		_set_hover(building_id_at(cell) if Rect2i(Vector2i.ZERO, GRID).has_point(cell) else &"")


func _set_hover(id: StringName) -> void:
	if id != _hover:
		_hover = id
		buildings.set_hover(id)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != &"" else Control.CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_pointer_inside = false
		_follow_pointer()


func _input(event: InputEvent) -> void:
	if placing and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel_placement()


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
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_scroll_by_user(scroll_x - event.relative.x)
		_pointer = event.position
		_pointer_inside = true
		_follow_pointer()
	elif event is InputEventMouseButton:
		if placing and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			_placement_button(event)
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press_position = event.position
					_held = true
					pressed.emit(cell_for_point(event.position))
				else:
					_held = false
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


func _placement_button(event: InputEventMouseButton) -> void:
	accept_event()
	_pointer = event.position
	_pointer_inside = true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			cancel_placement()
	elif event.pressed:
		_place_pressed = true
	elif _place_pressed:
		_place_pressed = false
		ghost.move_to(cell_for_point(event.position))
		if ghost.ok:
			var id := _place_id
			var cell: Vector2i = ghost.cell
			_end_placement()
			placement_confirmed.emit(id, cell)
