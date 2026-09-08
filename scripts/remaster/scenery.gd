extends Node2D
## Authored scenery only. All existing placement and simulation coordinates stay valid.
const PACK := "res://asset/Tiny Swords (Free Pack)/"
const TOP := [-2,-3,-4,-4,-5,-5,-5,-5,-5,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-3,-3,-3,-4,-4,-5,-5,-5,-5,-4,-4,-4,-4,-4,-3,-3,-3,-3,-3,-2,-1]
const BOTTOM := [2,3,4,4,4,5,5,5,5,5,5,5,5,5,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,4,4,4,4,3,2]
var ambient: Array[Sprite2D] = []
var clock := 0.0
var landscape := 0
var ground_top: Array = []
var ground_bottom: Array = []

func _ready() -> void:
	z_index = -30
	landscape = int(GameState.settings.landscape)
	ground_top = TOP.duplicate()
	ground_bottom = BOTTOM.duplicate()
	if landscape == 1:
		ground_top = [-2,-3,-4,-4,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-5,-4,-4,-4,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-4,-3,-3,-3,-3,-2,-1]
		ground_bottom = [2,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,3,2]
	elif landscape == 2:
		ground_top = [-2,-3,-4,-4,-4,-5,-5,-4,-4,-4,-5,-5,-4,-4,-5,-5,-4,-4,-4,-3,-3,-3,-4,-4,-5,-5,-5,-4,-4,-4,-5,-5,-4,-4,-3,-3,-3,-3,-2,-1]
		ground_bottom = [2,3,4,4,4,4,5,5,4,4,4,4,5,5,4,4,4,4,4,4,4,4,4,4,4,4,5,5,4,4,4,4,5,5,4,4,4,4,3,2]
	var map := TileMapLayer.new()
	map.position = Vector2(-640, 0)
	map.z_index = -1
	map.scale = Vector2(0.5, 0.5)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	source.texture = load(PACK + "Terrain/Tileset/Tilemap_color%d.png" % (landscape + 1))
	source.texture_region_size = Vector2i(64, 64)
	# The inspected sheet's upper-left 3 x 3 is the complete grass edge set.
	for x in 3:
		for y in 3: source.create_tile(Vector2i(x, y))
	tiles.add_source(source, 0)
	map.tile_set = tiles
	for x in ground_top.size():
		for y in range(ground_top[x], ground_bottom[x]):
			var left: bool = x == 0 or y < ground_top[x - 1] or y >= ground_bottom[x - 1]
			var right: bool = x == ground_top.size() - 1 or y < ground_top[x + 1] or y >= ground_bottom[x + 1]
			map.set_cell(Vector2i(x, y), 0, Vector2i(0 if left else (2 if right else 1), 0 if y == ground_top[x] else (2 if y == ground_bottom[x] - 1 else 1)))
	add_child(map)
	var water := Polygon2D.new()
	water.z_index = -2
	water.polygon = PackedVector2Array([Vector2(-480,120), Vector2(260,110), Vector2(320,158), Vector2(238,174), Vector2(114,190), Vector2(-112,181), Vector2(-280,185), Vector2(-470,158)])
	water.texture = load(PACK + "Terrain/Tileset/Water Background color.png")
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(water)
	water.visible = landscape == 0
	# Scenery stays outside the complete legal placement grid and battle corridor.
	_prop("Buildings/Blue Buildings/Castle.png", Vector2(-554, 0), 0.40)
	if landscape == 1:
		_terrace()
		_prop("Buildings/Blue Buildings/Tower.png", Vector2(-445,-128), 0.28)
		_prop("Buildings/Blue Buildings/Castle.png", Vector2(-305,-128), 0.29)
		_prop("Buildings/Blue Buildings/Tower.png", Vector2(-188,-128), 0.28)
	else:
		_prop("Buildings/Blue Buildings/House1.png", Vector2(-445, -108), 0.46)
		_prop("Buildings/Blue Buildings/House2.png", Vector2(-305, -112), 0.40)
		_prop("Buildings/Blue Buildings/House3.png", Vector2(-188, -113), 0.38)
		if landscape == 2:
			_prop("Buildings/Yellow Buildings/House1.png", Vector2(155,-112), 0.40)
			_prop("Buildings/Yellow Buildings/House2.png", Vector2(325,-109), 0.37)
	_prop("Buildings/Red Buildings/Tower.png", Vector2(550, -35), 0.37)
	for p in [Vector2(-550,-100), Vector2(-370,-123), Vector2(-75,-111), Vector2(120,-115), Vector2(175,-126), Vector2(416,-88), Vector2(590,83)]:
		_prop("Terrain/Resources/Wood/Trees/Tree1.png", p, 0.35, 8)
	for p in [Vector2(-590,100), Vector2(-428,140), Vector2(-85,112), Vector2(350,135), Vector2(560,-65)]:
		_prop("Terrain/Decorations/Bushes/Bushe1.png", p, 0.50, 8)
	for p in [Vector2(-450,144), Vector2(220,142), Vector2(410,140)]:
		_prop("Terrain/Decorations/Rocks/Rock2.png", p, 0.50)
	_prop("Terrain/Resources/Meat/Sheep/Sheep_Idle.png", Vector2(-335,139), 0.47, 6)
	_prop("Terrain/Resources/Meat/Sheep/Sheep_Idle.png", Vector2(-287,148), 0.41, 6)
	if landscape == 0: _prop("Terrain/Decorations/Rubber Duck/Rubber duck.png", Vector2(10,165), 0.9, 3)
	queue_redraw()

func _prop(path: String, at: Vector2, factor: float, frames: int = 1) -> void:
	if landscape != 0 and at.y > 100: at.y = 110
	var sprite := Sprite2D.new()
	sprite.texture = load(PACK + path)
	sprite.hframes = frames
	sprite.position = at
	sprite.scale = Vector2.ONE * factor
	# Animated pack sheets include transparent padding; ground anchors are authored.
	sprite.offset.y = -sprite.texture.get_height() * (0.10 if path.contains("Sheep") or path.contains("duck") or path.contains("Bushe") else (0.44 if frames > 1 else 0.5))
	sprite.z_as_relative = false
	sprite.z_index = int(at.y) + 190
	add_child(sprite)
	if frames > 1: ambient.append(sprite)

func _process(delta: float) -> void:
	if GameState.settings.reduced_effects: return
	clock += delta
	for i in ambient.size(): ambient[i].frame = (int(clock * 5) + i * 2) % ambient[i].hframes

func _draw() -> void:
	for p in ([Vector2(-160,158), Vector2(-90,166), Vector2(55,152), Vector2(126,171), Vector2(185,146)] if landscape == 0 else []):
		draw_line(p, p + Vector2(22,0), Color("89d1c5"), 2)
	if landscape == 2:
		for x in [155,325]: draw_line(Vector2(x,-104), Vector2(x,40), Color("b0ae75"), 8)
	if landscape == 1:
		for step in 6: draw_line(Vector2(-314,-126 + step * 5), Vector2(-296,-126 + step * 5), Color("b3c1a8"), 3)
	# A quiet road links homes and the frontier; no collision or tactical effect.
	var road := PackedVector2Array([Vector2(-568,22), Vector2(-420,30), Vector2(-276,12), Vector2(-116,25), Vector2(72,18), Vector2(240,40), Vector2(410,27), Vector2(550,38)])
	draw_polyline(road, Color("73975d"), 16, false)
	draw_polyline(road, Color("b0ae75"), 10, false)
	for x in [-445, -305, -188]:
		draw_line(Vector2(x,-104), Vector2(x,24), Color("b0ae75"), 8)

func _terrace() -> void:
	# Inspected right-hand atlas: grass lip and cliff face, kept above the battle corridor.
	for index in 10:
		var cliff := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load(PACK + "Terrain/Tileset/Tilemap_color2.png")
		atlas.region = Rect2(320 if index == 0 else (448 if index == 9 else 384), 192, 64, 128)
		cliff.texture = atlas
		cliff.scale = Vector2(0.5,0.25)
		cliff.position = Vector2(-448 + index * 32, -112)
		add_child(cliff)
