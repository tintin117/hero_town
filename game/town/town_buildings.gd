extends Node2D
## One sprite group per built building, in world pixels (cell * 32). Rebuilds only the building whose
## `building_changed` fired. `game` and `events` resolve to the autoloads unless a test injects fakes first.

const BuildingArt := preload("res://game/town/building_art.gd")
const HOVER_TINT := Color(1.25, 1.25, 1.25)

var game: Object
var events: Object
var _groups: Dictionary = {}  ## id -> Node2D
var _hover: StringName = &""


func _ready() -> void:
	y_sort_enabled = true
	if game == null:
		game = get_node_or_null("/root/Game")
	if events == null:
		events = get_node_or_null("/root/Events")
	if game == null or not game.has_method("building_defs"):  # ponytail: building rules not merged yet
		game = null
		return
	if events != null:
		events.building_changed.connect(refresh)
	for def in game.building_defs():
		refresh(def.id, false)


## Cell rect a building covers, or an empty rect when unbuilt.
func rect_of(id: StringName) -> Rect2i:
	if game == null or game.building_level(id) == 0:
		return Rect2i()
	return Rect2i(game.building_cell(id), _footprint(id))


func building_at(cell: Vector2i) -> StringName:
	return game.building_at(cell) if game != null else &""


func group_of(id: StringName) -> Node2D:
	return _groups.get(id)


func set_hover(id: StringName) -> void:
	if _groups.has(_hover):
		_groups[_hover].modulate = Color.WHITE
	_hover = id
	if _groups.has(id):
		_groups[id].modulate = HOVER_TINT


func refresh(id: StringName, animate := true) -> void:
	var level: int = game.building_level(id)
	var old: Node2D = _groups.get(id)
	if old != null and old.get_meta(&"level") == level and old.get_meta(&"cell") == game.building_cell(id):
		return
	if old != null:
		_groups.erase(id)
		old.queue_free()
	if level == 0:
		return
	var cell: Vector2i = game.building_cell(id)
	var group := BuildingArt.build(id, level, _footprint(id))
	group.set_meta(&"level", level)
	group.set_meta(&"cell", cell)
	group.position = Vector2(cell * BuildingArt.CELL)
	add_child(group)
	_groups[id] = group
	if id == _hover:
		group.modulate = HOVER_TINT
	if animate and is_inside_tree():
		_pop_in(group)


func _pop_in(group: Node2D) -> void:
	var rest := group.position
	group.position = rest + Vector2(0, -10)
	group.modulate.a = 0.0
	var tween := group.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(group, "position", rest, 0.25)
	tween.tween_property(group, "modulate:a", 1.0, 0.15)


func _footprint(id: StringName) -> Vector2i:
	for def in game.building_defs():
		if def.id == id:
			return def.footprint
	return Vector2i.ONE
