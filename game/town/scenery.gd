@tool
extends Node2D
## Terrain, paths and props are authored in the three landscape scenes.
@export_enum("Meadow", "Terrace", "Village") var preview_landscape := 0:
	set(value):
		preview_landscape = value
		if Engine.is_editor_hint() and is_inside_tree(): _show_landscape(value)
@export_range(0.0, 20.0, 0.1) var ambient_fps := 5.0

var ambient: Array[Sprite2D] = []
var clock := 0.0
var landscape := 0
# Read-only coverage information derived from the painted tiles.
var ground_top: Array = []
var ground_bottom: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_show_landscape(preview_landscape)
		set_process(false)
		return
	GameState.settings_changed.connect(_refresh_landscape)
	_refresh_landscape()

func _refresh_landscape() -> void:
	_show_landscape(int(GameState.settings.landscape))

func _show_landscape(index: int) -> void:
	landscape = clampi(index, 0, get_child_count() - 1)
	ambient.clear()
	for i in get_child_count():
		var variant := get_child(i) as Node2D
		variant.visible = i == landscape
		if variant.visible:
			for sprite in variant.find_children("*", "Sprite2D", true, false):
				if sprite.hframes > 1: ambient.append(sprite)
	var terrain := get_child(landscape).get_node("Terrain") as TileMapLayer
	var used := terrain.get_used_rect()
	ground_top.resize(maxi(0, used.end.x))
	ground_bottom.resize(maxi(0, used.end.x))
	ground_top.fill(used.end.y)
	ground_bottom.fill(used.position.y)
	for cell in terrain.get_used_cells():
		if cell.x < 0: continue
		ground_top[cell.x] = mini(ground_top[cell.x], cell.y)
		ground_bottom[cell.x] = maxi(ground_bottom[cell.x], cell.y + 1)

func _process(delta: float) -> void:
	if GameState.settings.reduced_effects: return
	clock += delta
	for i in ambient.size(): ambient[i].frame = (int(clock * ambient_fps) + i * 2) % ambient[i].hframes
