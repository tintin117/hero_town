class_name Drawer
extends PanelContainer
## Slide-in panel with a ribbon title and a close button. Put it inside a full-rect Control (it positions
## itself against that parent's size). open()/close() tween; ESC or the button closes and emits `closed`.
## Add your content to get_body(). Signals: opened(), closed().

signal opened
signal closed

enum Edge { RIGHT, LEFT, BOTTOM }

@export var title := "":
	set(v):
		title = v
		if is_node_ready():
			_title.text = v
@export var edge := Edge.RIGHT
@export var panel_size := Vector2(360, 300)
## Gap kept between the drawer and the parent's edges.
@export var margin := 8.0

var is_open := false
var _tween: Tween

@onready var _title: Label = $Column/Header/Ribbon/Title
@onready var _body: VBoxContainer = $Column/Body
@onready var _close: IconButton = $Column/Header/Close


func _ready() -> void:
	_title.text = title
	_close.pressed.connect(close)
	visible = false
	var p := get_parent() as Control
	if p:
		p.resized.connect(_snap)


func get_body() -> VBoxContainer:
	return _body


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	size = panel_size
	_slide(_rest(), true)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_slide(_hidden(), false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _parent_size() -> Vector2:
	var p := get_parent() as Control
	return p.size if p else get_viewport_rect().size


func _rest() -> Vector2:
	var ps := _parent_size()
	match edge:
		Edge.LEFT:
			return Vector2(margin, (ps.y - size.y) / 2)
		Edge.BOTTOM:
			return Vector2((ps.x - size.x) / 2, ps.y - size.y - margin)
		_:
			return Vector2(ps.x - size.x - margin, (ps.y - size.y) / 2)


func _hidden() -> Vector2:
	var ps := _parent_size()
	match edge:
		Edge.LEFT:
			return Vector2(-size.x - 4, _rest().y)
		Edge.BOTTOM:
			return Vector2(_rest().x, ps.y + 4)
		_:
			return Vector2(ps.x + 4, _rest().y)


func _snap() -> void:
	if is_open:
		position = _rest()


func _slide(to: Vector2, showing: bool) -> void:
	if _tween:
		_tween.kill()
	if showing:
		position = _hidden()
	_tween = create_tween()
	_tween.tween_property(self, "position", to, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if showing else Tween.EASE_IN)
	if not showing:
		_tween.tween_callback(func() -> void: visible = false)
