extends Control

## Research is an ordinary in-game Control, never a native or embedded Window.
const PANEL_SCENE = preload("res://scenes/class_research_panel.tscn")
var panel: Control
var _compact_state: Dictionary = {}
var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	name = "ResearchOverlay"
	z_index = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.07, 0.05, 0.04, 0.35)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close())
	panel = PANEL_SCENE.instantiate()
	add_child(panel)
	panel.close_requested.connect(close)
	panel.get_node("Layout/Header/Title").mouse_filter = Control.MOUSE_FILTER_STOP
	panel.get_node("Layout/Header/Title").gui_input.connect(_on_header_input)
	get_viewport().size_changed.connect(_layout)
	hide()

func open(building: BuildingBase) -> void:
	# A 120px strip cannot contain a readable research tree. Expand the SAME
	# game window upward while research is open, then restore it on close.
	if get_viewport_rect().size.y < 470 and _compact_state.is_empty():
		var game := get_tree().root
		_compact_state = {"size": game.size, "position": game.position, "scale": game.content_scale_size}
		var usable := DisplayServer.screen_get_usable_rect(game.current_screen)
		var height := mini(664, usable.size.y)
		game.size = Vector2i(game.size.x, height)
		game.position = Vector2i(game.position.x, maxi(usable.position.y, _compact_state.position.y + _compact_state.size.y - height))
		game.content_scale_size = Vector2i(game.content_scale_size.x, height)
	panel.open(building)
	show()
	_layout()
	panel.get_node("Layout/Tabs/Hero").grab_focus()

func close() -> void:
	_dragging = false
	hide()
	if not _compact_state.is_empty():
		var game := get_tree().root
		game.size = _compact_state.size
		game.position = _compact_state.position
		game.content_scale_size = _compact_state.scale
		_compact_state.clear()

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var available := get_viewport_rect().size - Vector2(24, 24)
	panel.size = Vector2(460, clampf(available.y, 470, 640))
	var fit := minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.scale = Vector2.ONE * maxf(0.1, fit)
	panel.position = (get_viewport_rect().size - panel.size * panel.scale) * 0.5

func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_offset = get_global_mouse_position() - panel.position
	elif event is InputEventMouseMotion and _dragging:
		var max_pos := get_viewport_rect().size - panel.size * panel.scale
		panel.position = (get_global_mouse_position() - _drag_offset).clamp(Vector2.ZERO, max_pos.max(Vector2.ZERO))
