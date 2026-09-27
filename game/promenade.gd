extends Control
## Fixed-size town: scenery scrolls with its native ground cells and buildings.
const TownGrid := preload("res://game/town_grid.gd")
const ROOT := "res://asset/Tiny Swords (Free Pack)/"
const TILES := preload(ROOT + "Terrain/Tileset/Tilemap_color1.png")
const HOUSE := preload(ROOT + "Buildings/Blue Buildings/House1.png")
const BARRACKS := preload(ROOT + "Buildings/Blue Buildings/Barracks.png")
const TREE := preload(ROOT + "Terrain/Resources/Wood/Trees/Tree1.png")
const CLOUD := preload(ROOT + "Terrain/Decorations/Clouds/Clouds_01.png")
const WALKER := preload(ROOT + "Units/Blue Units/Pawn/Pawn_Run.png")
const WORLD_WIDTH := TownGrid.WORLD_WIDTH
const BUILDING_ART := {
	"tavern": {"texture": HOUSE, "size": Vector2(96, 128)},
	"barracks": {"texture": BARRACKS, "size": Vector2(120, 132)},
}

var grid := TownGrid.new()
var tiles := TileMapLayer.new()
var ground_details := Node2D.new()
var building_layer := Node2D.new()
var building_nodes: Dictionary = {}
var preview := Sprite2D.new()
var arranging := false
var selected_building := ""
var preview_cell := Vector2i.ZERO
var clock := 0.0
var redraw_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var image := TILES.get_image().get_region(Rect2i(64, 64, 64, 64))
	image.resize(48, 24, Image.INTERPOLATE_NEAREST)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = TownGrid.CELL_SIZE
	atlas.create_tile(Vector2i.ZERO)
	tiles.name = "GroundCells"
	tiles.tile_set = TileSet.new()
	tiles.tile_set.tile_size = TownGrid.CELL_SIZE
	tiles.tile_set.add_source(atlas, 0)
	tiles.modulate = Color("c1c6a4")
	tiles.collision_enabled = false
	tiles.navigation_enabled = false
	add_child(tiles)
	for y in range(TownGrid.SIZE.y):
		for x in range(TownGrid.SIZE.x):
			tiles.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(ground_details)
	ground_details.draw.connect(_draw_ground)
	building_layer.y_sort_enabled = true
	add_child(building_layer)
	for id in grid.buildings:
		var body := Node2D.new()
		body.name = id.capitalize()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = BUILDING_ART[id].texture
		sprite.centered = false
		sprite.scale = BUILDING_ART[id].size / sprite.texture.get_size()
		sprite.position = -BUILDING_ART[id].size * Vector2(0.5, 1.0)
		body.add_child(sprite)
		var label := Label.new()
		label.text = id.to_upper()
		label.position = Vector2(-39, -18)
		label.size = Vector2(78, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("f4dfac"))
		label.add_theme_color_override("font_outline_color", Color("332e2c"))
		label.add_theme_constant_override("outline_size", 4)
		body.add_child(label)
		building_layer.add_child(body)
		building_nodes[id] = body
	preview.centered = false
	preview.visible = false
	preview.z_index = 1500
	add_child(preview)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	tiles.position = Vector2(0, size.y - 280)
	for id in building_nodes:
		building_nodes[id].position = _feet(id, grid.buildings[id].cell)
	_update_preview()
	queue_redraw()
	ground_details.queue_redraw()


func cell_for_point(point: Vector2) -> Vector2i:
	return tiles.local_to_map(point - tiles.position)


func point_for_cell(cell: Vector2i) -> Vector2:
	return tiles.position + tiles.map_to_local(cell)


func _feet(id: String, cell: Vector2i) -> Vector2:
	return tiles.position + Vector2(cell * TownGrid.CELL_SIZE) + Vector2(grid.buildings[id].size * TownGrid.CELL_SIZE) * Vector2(0.5, 1.0)


func set_arranging(enabled: bool) -> void:
	arranging = enabled
	if not enabled:
		cancel_placement()
	ground_details.queue_redraw()


func cancel_placement() -> void:
	selected_building = ""
	preview.visible = false
	for body in building_nodes.values():
		body.modulate = Color.WHITE
	ground_details.queue_redraw()


func _update_preview() -> void:
	preview.visible = arranging and not selected_building.is_empty()
	if not preview.visible:
		return
	var art: Dictionary = BUILDING_ART[selected_building]
	preview.texture = art.texture
	preview.scale = art.size / preview.texture.get_size()
	preview.position = _feet(selected_building, preview_cell) - art.size * Vector2(0.5, 1.0)
	preview.modulate = Color(0.6, 1.0, 0.7, 0.72) if grid.can_place(selected_building, preview_cell) else Color(1.0, 0.4, 0.35, 0.72)
	ground_details.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not arranging:
		return
	if event is InputEventMouseMotion and not selected_building.is_empty():
		preview_cell = cell_for_point(event.position)
		_update_preview()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not selected_building.is_empty():
				preview_cell = cell_for_point(event.position)
				if grid.try_move(selected_building, preview_cell):
					cancel_placement()
					_layout()
				else:
					_update_preview()
			else:
				var candidates: Array = building_nodes.keys()
				candidates.sort_custom(func(a: String, b: String) -> bool: return building_nodes[a].position.y > building_nodes[b].position.y)
				for id in candidates:
					var art: Vector2 = BUILDING_ART[id].size
					var body: Node2D = building_nodes[id]
					if Rect2(body.position - art * Vector2(0.5, 1.0), art).has_point(event.position) or grid.building_at(cell_for_point(event.position)) == id:
						selected_building = id
						preview_cell = grid.buildings[id].cell
						body.modulate.a = 0.35
						_update_preview()
						break
			accept_event()


func _process(delta: float) -> void:
	clock += delta
	redraw_time += delta
	# ponytail: 12 decorative frames/second suffice; use sprite nodes if this scene grows.
	if redraw_time >= 1.0 / 12.0:
		redraw_time = 0.0
		queue_redraw()
		ground_details.queue_redraw()


func _draw() -> void:
	var ground := size.y - 280.0
	for band in range(16):
		var color := Color("344d65").lerp(Color("8ca8a2"), float(band) / 15.0)
		draw_rect(Rect2(0, size.y * band / 16.0, WORLD_WIDTH, size.y / 16.0 + 1), color)
	for cloud in range(6):
		var x := fmod(cloud * WORLD_WIDTH / 6.0 + clock * 3.0, WORLD_WIDTH + 220.0) - 110.0
		draw_texture_rect(CLOUD, Rect2(x, ground - 90.0 + cloud * 13, 220, 92), false, Color(0.8, 0.9, 0.95, 0.3))
	for i in range(34):
		var x := float(i) * WORLD_WIDTH / 33.0
		var height := 70.0 + sin(i * 2.7) * 18.0
		draw_texture_rect_region(TREE, Rect2(x - 38, ground - height + 24, 76, height), Rect2(0, 0, 192, 256), Color("5b7d7d"))
	for x in range(0, WORLD_WIDTH, 48):
		draw_texture_rect_region(TILES, Rect2(x, size.y - 104, 48, 48), Rect2(384, 192, 64, 64))
		draw_texture_rect_region(TILES, Rect2(x, size.y - 70, 48, 40), Rect2(384, 256, 64, 64))


func _draw_ground() -> void:
	var path_y := tiles.position.y + 180.0
	ground_details.draw_line(Vector2(0, path_y), Vector2(WORLD_WIDTH, path_y), Color("9b8962"), 24.0)
	ground_details.draw_line(Vector2(0, path_y - 1), Vector2(WORLD_WIDTH, path_y - 1), Color("c5b17d"), 20.0)
	for x in range(0, WORLD_WIDTH, 24):
		ground_details.draw_line(Vector2(x, path_y - 7), Vector2(x + 14, path_y - 7), Color("ddd09c"), 2.0)
		ground_details.draw_line(Vector2(x + 6, path_y + 6), Vector2(x + 18, path_y + 6), Color("ae9d71"), 2.0)
	for id in building_nodes:
		ground_details.draw_set_transform(building_nodes[id].position, 0.0, Vector2(1, 0.25))
		ground_details.draw_circle(Vector2.ZERO, BUILDING_ART[id].size.x * 0.43, Color(0.1, 0.2, 0.18, 0.25))
		ground_details.draw_set_transform(Vector2.ZERO)
	for i in range(12):
		var progress := fmod(clock * (9.0 + i) + i * WORLD_WIDTH / 12.0, WORLD_WIDTH + 64.0) - 32.0
		var x := progress if i % 2 == 0 else WORLD_WIDTH - progress
		var dest := Rect2(x - 13, path_y - 22 + (i % 3) * 3, 26, 34)
		if i % 2 != 0:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		ground_details.draw_texture_rect_region(WALKER, dest, Rect2((int(clock * 8) + i) % 6 * 192 + 64, 48, 64, 88))
	if not arranging:
		return
	for y in range(TownGrid.SIZE.y):
		for x in range(TownGrid.SIZE.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(point_for_cell(cell) - Vector2(TownGrid.CELL_SIZE) * 0.5, Vector2(TownGrid.CELL_SIZE))
			if grid.is_protected(cell):
				ground_details.draw_rect(rect, Color(0.4, 0.25, 0.2, 0.22))
			ground_details.draw_rect(rect, Color(0.85, 0.92, 0.73, 0.45), false, 1.0)
	for id in grid.buildings:
		_draw_footprint(id, grid.buildings[id].cell, Color(0.95, 0.8, 0.4, 0.26))
	if not selected_building.is_empty():
		var color := Color(0.3, 0.95, 0.5, 0.5) if grid.can_place(selected_building, preview_cell) else Color(1.0, 0.25, 0.2, 0.5)
		_draw_footprint(selected_building, preview_cell, color)


func _draw_footprint(id: String, cell: Vector2i, color: Color) -> void:
	var footprint := grid.footprint(id, cell)
	var rect := Rect2(tiles.position + Vector2(footprint.position * TownGrid.CELL_SIZE), Vector2(footprint.size * TownGrid.CELL_SIZE))
	ground_details.draw_rect(rect, color)
	ground_details.draw_rect(rect, Color(color, 1.0), false, 2.0)
