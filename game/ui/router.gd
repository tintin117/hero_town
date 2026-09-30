class_name DrawerRouter
extends Node
## One drawer open at a time. Drawers are Drawer-component scenes registered by key and loaded lazily into `host`
## (a full-rect Control). Opening one closes the other; ESC or a right click closes; opening never pauses the sim.
## `context` entries (e.g. game, events) are set as properties on each drawer before it enters the tree.

signal drawer_changed(key: StringName)  ## the open drawer's key, or &"" when none is open

var host: Control
var registry := {}  ## key -> scene path
var context := {}
var current := &""

var _drawers := {}  ## key -> Drawer, instanced on first use


func register(key: StringName, path: String) -> void:
	registry[key] = path


func has_drawer(key: StringName) -> bool:
	return registry.has(key) and ResourceLoader.exists(registry[key])


func open(key: StringName) -> bool:
	if not has_drawer(key):
		return false
	if key == current:
		return true
	var previous := current
	current = key  # set first so the old drawer's `closed` does not read as "nothing open"
	if previous != &"":
		_drawers[previous].close()
	_drawer(key).open()
	drawer_changed.emit(key)
	return true


## The drawer instance for `key` (created on first use), or null when it is not registered.
func get_drawer(key: StringName) -> Drawer:
	return _drawer(key) if has_drawer(key) else null


func close() -> void:
	if current != &"":
		_drawers[current].close()  # its `closed` signal clears `current`


func _drawer(key: StringName) -> Drawer:
	if not _drawers.has(key):
		var drawer := (load(registry[key]) as PackedScene).instantiate() as Drawer
		for property: String in context:
			drawer.set(property, context[property])
		host.add_child(drawer)
		drawer.closed.connect(_on_closed.bind(key))
		_drawers[key] = drawer
	return _drawers[key]


func _on_closed(key: StringName) -> void:
	if current == key:
		current = &""
		drawer_changed.emit(&"")


func _unhandled_input(event: InputEvent) -> void:
	if current == &"":
		return
	var right_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if right_click or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
