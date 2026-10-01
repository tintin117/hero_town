class_name DesktopStrip
extends Node
## Opaque, borderless desktop dock. The HUD collapses to its top bar; drag the bar to re-dock
## at the nearer screen edge. Avoid mouse_passthrough_polygon: on Windows it also clips rendering.

var hud: Control
var town: Control
var covering: Callable  ## () -> bool: a menu or drawer needs the expanded window
var dock_top := false
var collapsed := false

var _window: Window
var _bar: Control
var _full_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
var _drag_from := -1  ## pointer y minus window y while the bar is being dragged, -1 otherwise


static func supported() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


## Where the strip sits in `usable` (the screen minus the taskbar): centred, at most `width` wide, on the chosen edge.
static func strip_rect(usable: Rect2i, width: int, height: int, top: bool) -> Rect2i:
	var w := mini(width, usable.size.x)
	var y := usable.position.y if top else usable.end.y - height
	return Rect2i(usable.position.x + (usable.size.x - w) / 2, y, w, height)


func _ready() -> void:
	_window = get_window()
	_bar = hud.get_node("Layout/TopBar")
	_window.min_size = Vector2i.ZERO
	_window.borderless = true
	_window.always_on_top = true
	_window.transparent = false
	_window.mouse_passthrough_polygon = PackedVector2Array()
	get_viewport().transparent_bg = false
	_bar.gui_input.connect(_on_bar_input)
	apply()


func toggle_collapse() -> void:
	collapsed = not collapsed
	if collapsed:
		hud.router.close()
		town.cancel_placement()
	apply()


func apply() -> void:
	hud.set_collapse_state(collapsed, dock_top)
	town.visible = not collapsed
	var height := ceili(_bar.get_combined_minimum_size().y) if collapsed else _full_height
	var usable := DisplayServer.screen_get_usable_rect(_window.current_screen)
	var rect := strip_rect(usable, int(town.WORLD_SIZE.x), height, dock_top)
	_window.size = rect.size
	_window.position = rect.position


func _process(_delta: float) -> void:
	var covered: bool = covering.call()
	if collapsed and covered:  # the pause menu needs the full strip
		toggle_collapse()


# ponytail: re-docks on the window's current screen; dragging onto another monitor needs screen_get_usable_rect per screen.
func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = DisplayServer.mouse_get_position().y - _window.position.y
		elif _drag_from >= 0:
			_drag_from = -1
			var usable := DisplayServer.screen_get_usable_rect(_window.current_screen)
			dock_top = _window.position.y + _window.size.y / 2 < usable.get_center().y
			apply()
	elif event is InputEventMouseMotion and _drag_from >= 0:
		_window.position.y = DisplayServer.mouse_get_position().y - _drag_from
