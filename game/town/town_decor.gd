extends Node2D
## Scenery scattered with a fixed seed: forest beyond the owned land and hedges on its border. Sprites sit at their feet so the y-sorted parent orders them.

const SHEET := preload("res://asset/Sunnyside_World_Assets/Tileset/spr_tileset_sunnysideworld_16px.png")
const TREES: Array[Texture2D] = [
	preload("res://asset/Sunnyside_World_Assets/Elements/Plants/spr_deco_tree_01_strip4.png"),
	preload("res://asset/Sunnyside_World_Assets/Elements/Plants/spr_deco_tree_02_strip4.png"),
]
const TREE_FRAMES := [32, 28]  # frame widths of the four-frame strips
# Bush regions in the tileset (px).
const BUSHES: Array[Rect2] = [Rect2(787, 20, 26, 25), Rect2(787, 52, 26, 24), Rect2(787, 84, 26, 26)]
const OWNED_X := Vector2(320.0, 1216.0)
const WORLD_W := 1536.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2026
	for y in range(48, 210, 40):
		for edge in [OWNED_X.x - 16.0, OWNED_X.y + 16.0]:
			_add(SHEET, BUSHES[_rng.randi() % BUSHES.size()], Vector2(edge + _rng.randf_range(-4.0, 4.0), y + _rng.randf_range(-6.0, 6.0)))
	for row_y in [64.0, 112.0, 160.0, 208.0]:
		for x in range(16, int(OWNED_X.x) - 40, 44):
			_add_tree(x, row_y)
		for x in range(int(OWNED_X.y) + 60, int(WORLD_W) - 8, 44):
			_add_tree(x, row_y)


func _add_tree(x: int, feet_y: float) -> void:
	var kind := _rng.randi() % TREES.size()
	var tree := Sprite2D.new()
	tree.texture = TREES[kind]
	tree.hframes = 4
	tree.frame = _rng.randi() % 4
	tree.centered = false
	tree.offset = Vector2(-TREE_FRAMES[kind] / 2.0, -tree.texture.get_height())
	tree.scale = Vector2(2, 2)
	tree.position = (Vector2(x + _rng.randf_range(-10.0, 10.0), feet_y + _rng.randf_range(-10.0, 10.0)) / 2.0).round() * 2.0
	add_child(tree)


func _add(sheet: Texture2D, region: Rect2, feet: Vector2) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	sprite.texture = atlas
	sprite.centered = false
	sprite.offset = Vector2(-region.size.x / 2.0, -region.size.y)
	sprite.scale = Vector2(2, 2)
	sprite.position = (feet / 2.0).round() * 2.0
	add_child(sprite)
