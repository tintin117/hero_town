extends Control
## Square native tiles; saved footprints remain the original 48 by 8 estate.
signal building_clicked(id: String)
signal construction_requested(id: String, cell: Vector2i)
signal building_moved
const TownGrid := preload("res://game/town_grid.gd")
const Actor := preload("res://resources/art/sunnyside_actor.gd")
const TILES := preload("res://asset/Sunnyside_World_Assets/Tileset/spr_tileset_sunnysideworld_16px.png")
const TREE := preload("res://asset/Sunnyside_World_Assets/Elements/Plants/spr_deco_tree_01_strip4.png")
const SMOKE := preload("res://asset/Sunnyside_World_Assets/Elements/VFX/Chimney Smoke/chimneysmoke_01_strip30.png")
const WORLD_WIDTH := TownGrid.WORLD_WIDTH
const BUILDING_ART := {
	"tavern": {"size": Vector2(64, 112), "roof_y": 552},
	"hall": {"size": Vector2(96, 112), "roof_y": 168},
	"training": {"size": Vector2(96, 68), "roof_y": 424},
	"infirmary": {"size": Vector2(64, 112), "roof_y": 296},
}

var grid := TownGrid.new()
var tiles := TileMapLayer.new()
var ground_details := Node2D.new()
var building_layer := Node2D.new()
var building_nodes: Dictionary = {}
var preview := Node2D.new()
var arranging := false
var constructing := false
var selected_building := ""
var preview_cell := Vector2i.ZERO
var clock := 0.0
var redraw_time := 0.0
var visitors: Array[Node2D] = []
var hero_nodes: Dictionary = {}
var hero_states: Dictionary = {}
var _management_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILES
	atlas.texture_region_size = Vector2i(16, 16)
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(10, 7), Vector2i(11, 7)]: atlas.create_tile(cell)
	tiles.name = "GroundCells"
	tiles.tile_set = TileSet.new()
	tiles.tile_set.tile_size = Vector2i(16, 16)
	tiles.tile_set.add_source(atlas, 0)
	tiles.scale = Vector2(2, 2)
	tiles.collision_enabled = false
	tiles.navigation_enabled = false
	add_child(tiles)
	for y in range(TownGrid.SIZE.y):
		for x in range(TownGrid.SIZE.x):
			var atlas_cell := Vector2i(1, 1)
			if y == 7: atlas_cell = Vector2i(10 + x % 2, 7)
			elif (x * 7 + y * 13) % 11 == 0: atlas_cell = Vector2i(2, 1)
			elif (x * 3 + y * 7) % 13 == 0: atlas_cell = Vector2i(1, 2)
			tiles.set_cell(Vector2i(x, y), 0, atlas_cell)
	add_child(ground_details)
	ground_details.draw.connect(_draw_ground)
	building_layer.y_sort_enabled = true
	add_child(building_layer)
	for index in range(10):
		var actor := Actor.new()
		actor.setup(index, "warrior")
		actor.show_equipment = false
		actor.play("walk")
		building_layer.add_child(actor)
		visitors.append(actor)
	preview.visible = false
	preview.z_index = 1500
	preview.draw.connect(func():
		if not selected_building.is_empty(): _draw_building(preview, selected_building)
	)
	add_child(preview)
	resized.connect(_layout)
	sync_buildings()


func sync_buildings() -> void:
	for id in building_nodes.keys():
		if not grid.buildings.has(id):
			building_nodes[id].queue_free()
			building_nodes.erase(id)
	for id in grid.buildings:
		if building_nodes.has(id): continue
		var body := Node2D.new()
		body.name = id.capitalize()
		body.draw.connect(_draw_building.bind(body, id))
		var label := Label.new()
		label.text = TownGrid.BUILDINGS[id].name.to_upper()
		label.position = Vector2(-70, 1)
		label.size = Vector2(140, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("fff1c8"))
		label.add_theme_color_override("font_outline_color", Color("344235"))
		label.add_theme_constant_override("outline_size", 3)
		body.add_child(label)
		building_layer.add_child(body)
		building_nodes[id] = body
	_layout()


func _draw_building(canvas: CanvasItem, id: String) -> void:
	var art: Dictionary = BUILDING_ART[id]
	var width: float = art.size.x
	canvas.draw_rect(Rect2(-width * 0.5, -36, width, 36), Color("b89460"))
	if id == "training":
		for y in range(2):
			for x in range(3):
				canvas.draw_texture_rect_region(TILES, Rect2(-48 + x * 32, -64 + y * 32, 32, 32), Rect2(160, 112, 16, 16))
		canvas.draw_line(Vector2(-46, -57), Vector2(46, -57), Color("d0a777"), 5)
		canvas.draw_line(Vector2(-46, -49), Vector2(46, -49), Color("9e7450"), 4)
		for x in [-46, -16, 16, 46]:
			canvas.draw_rect(Rect2(x - 2, -68, 5, 28), Color("835b43"))
			canvas.draw_rect(Rect2(x - 2, -68, 5, 5), Color("e1be86"))
		for x in [-24, 24]:
			canvas.draw_rect(Rect2(x - 3, -31, 6, 27), Color("805a3e"))
			canvas.draw_rect(Rect2(x - 14, -26, 28, 5), Color("b78b57"))
			canvas.draw_circle(Vector2(x, -34), 10, Color("67523e"))
			canvas.draw_circle(Vector2(x, -34), 8, Color("dfbd72"))
			canvas.draw_circle(Vector2(x, -34), 5, Color("ad684a"))
			canvas.draw_circle(Vector2(x, -34), 2, Color("f6df9b"))
		return
	# Atlas modules retain their native pixels at exactly 2x.
	canvas.draw_texture_rect_region(TILES, Rect2(-width * 0.5, -48, width, 48), Rect2(16, 144, width * 0.5, 24))
	if id == "hall":
		for offset in [-16, 16]:
			canvas.draw_texture_rect_region(TILES, Rect2(offset - 32, -112, 64, 80), Rect2(520, art.roof_y, 32, 40))
	else:
		canvas.draw_texture_rect_region(TILES, Rect2(-32, -112, 64, 80), Rect2(520, art.roof_y, 32, 40))
	canvas.draw_rect(Rect2(-8, -25, 16, 25), Color("694333"))
	canvas.draw_rect(Rect2(-5, -23, 10, 21), Color("996743"))
	canvas.draw_rect(Rect2(2, -13, 2, 2), Color("f5cf7b"))
	canvas.draw_rect(Rect2(-25, -25, 10, 12), Color("563f37"))
	canvas.draw_rect(Rect2(-23, -23, 6, 8), Color("8fd1cc"))
	canvas.draw_rect(Rect2(15, -25, 10, 12), Color("563f37"))
	canvas.draw_rect(Rect2(17, -23, 6, 8), Color("8fd1cc"))
	if id == "infirmary":
		canvas.draw_rect(Rect2(-8, -48, 16, 12), Color("fff2d1"))
		canvas.draw_rect(Rect2(-2, -47, 4, 10), Color("59a36e"))
		canvas.draw_rect(Rect2(-5, -44, 10, 4), Color("59a36e"))
	elif id == "tavern":
		canvas.draw_rect(Rect2(14, -10, 28, 5), Color("8b623f"))
		canvas.draw_rect(Rect2(17, -20, 4, 20), Color("77513c"))
		canvas.draw_rect(Rect2(35, -20, 4, 20), Color("77513c"))
		canvas.draw_rect(Rect2(12, -22, 32, 9), Color("d0a56b"))
		canvas.draw_circle(Vector2(23, -20), 4, Color("ece4c6"))
		canvas.draw_circle(Vector2(35, -20), 3, Color("a9533f"))
		canvas.draw_rect(Rect2(14, -87, 10, 20), Color("977766"))
		canvas.draw_texture_rect_region(SMOKE, Rect2(4, -151, 30, 74), Rect2(int(clock * 8) % 30 * 15, 0, 15, 37), Color(1, 1, 1, 0.65))
	else:
		canvas.draw_rect(Rect2(34, -29, 3, 29), Color("725242"))
		canvas.draw_rect(Rect2(28, -30, 18, 13), Color("e5ca86"))
		canvas.draw_rect(Rect2(34, -27, 6, 6), Color("527aaa"))


func _layout() -> void:
	tiles.position = Vector2(0, size.y - 340)
	for id in building_nodes: building_nodes[id].position = _feet(id, grid.buildings[id].cell)
	_layout_hero_states()
	_update_preview()
	queue_redraw()
	ground_details.queue_redraw()


func cell_for_point(point: Vector2) -> Vector2i:
	return tiles.local_to_map((point - tiles.position) / 2.0)


func point_for_cell(cell: Vector2i) -> Vector2:
	return tiles.position + tiles.map_to_local(cell) * 2.0


func _feet(id: String, cell: Vector2i) -> Vector2:
	return tiles.position + Vector2(cell * TownGrid.CELL_SIZE) + Vector2(TownGrid.BUILDINGS[id].size * TownGrid.CELL_SIZE) * Vector2(0.5, 1.0)


func begin_construction(id: String) -> void:
	cancel_placement()
	arranging = true
	constructing = true
	selected_building = id
	preview_cell = Vector2i(10, 3)
	for y in [3, 1, 5, 0, 2, 4]:
		for x in range(TownGrid.OWNED.position.x, TownGrid.OWNED.end.x):
			if grid.can_place(id, Vector2i(x, y)):
				preview_cell = Vector2i(x, y)
				_update_preview()
				return
	_update_preview()


func set_arranging(enabled: bool) -> void:
	arranging = enabled
	if not enabled: cancel_placement()
	ground_details.queue_redraw()


func cancel_placement() -> void:
	selected_building = ""
	constructing = false
	preview.visible = false
	for body in building_nodes.values(): body.modulate = Color.WHITE
	ground_details.queue_redraw()


func _update_preview() -> void:
	preview.visible = arranging and not selected_building.is_empty()
	if not preview.visible: return
	preview.position = _feet(selected_building, preview_cell)
	preview.modulate = Color(0.6, 1.0, 0.7, 0.72) if grid.can_place(selected_building, preview_cell) else Color(1.0, 0.4, 0.35, 0.72)
	preview.queue_redraw()
	ground_details.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not arranging:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var id := _building_at_point(event.position)
			if not id.is_empty():
				building_clicked.emit(id)
				accept_event()
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
				if constructing: construction_requested.emit(selected_building, preview_cell)
				elif grid.try_move(selected_building, preview_cell):
					cancel_placement()
					_layout()
					building_moved.emit()
				else: _update_preview()
			else:
				var id := _building_at_point(event.position)
				if not id.is_empty():
					selected_building = id
					preview_cell = grid.buildings[id].cell
					building_nodes[id].modulate.a = 0.35
					_update_preview()
			accept_event()


func _building_at_point(point: Vector2) -> String:
	var candidates: Array = building_nodes.keys()
	candidates.sort_custom(func(a: String, b: String) -> bool: return building_nodes[a].position.y > building_nodes[b].position.y)
	for id in candidates:
		var art: Vector2 = BUILDING_ART[id].size
		if Rect2(building_nodes[id].position - art * Vector2(0.5, 1.0), art).has_point(point): return id
	return grid.building_at(cell_for_point(point))


func sync_management(fight: RefCounted) -> void:
	if not fight.has_method("availability"): return
	var states: Dictionary = {}
	for id in range(fight.heroes.size()):
		var status: Dictionary = fight.availability(id)
		if status.state in ["training", "injured", "resting"]: states[id] = status.state
	var signature := str(states)
	if signature == _management_signature: return
	_management_signature = signature
	hero_states = states
	for id in hero_nodes: hero_nodes[id].visible = states.has(id)
	for id in states:
		if not hero_nodes.has(id):
			var actor := Actor.new()
			actor.setup(id, fight.heroes[id].unit, fight.heroes[id].red)
			var badge := Label.new()
			badge.name = "StateBadge"
			badge.position = Vector2(-10, -47)
			badge.size = Vector2(20, 12)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_outline_color", Color("304532"))
			badge.add_theme_constant_override("outline_size", 3)
			actor.add_child(badge)
			building_layer.add_child(actor)
			hero_nodes[id] = actor
		var actor: Node2D = hero_nodes[id]
		actor.show_equipment = states[id] == "training"
		actor.modulate = Color("d9b0a2") if states[id] == "injured" else Color.WHITE
		actor.get_node("StateBadge").text = "XP" if states[id] == "training" else ("+" if states[id] == "injured" else "zZ")
		actor.play("idle")
		actor.visible = true
	_layout_hero_states()


func _layout_hero_states() -> void:
	var occupied: Dictionary = {}
	for id in hero_states:
		if not hero_nodes.has(id): continue
		var state: String = hero_states[id]
		var building := "training" if state == "training" else ("infirmary" if state == "injured" else "tavern")
		var index: int = occupied.get(building, 0)
		occupied[building] = index + 1
		var base: Vector2 = building_nodes[building].position if building_nodes.has(building) else tiles.position + Vector2(350 if state != "injured" else 1170, 192)
		var position := base + Vector2(-24 + index % 3 * 24, 26 + index / 3 * 24)
		position.y = minf(position.y, tiles.position.y + 250)
		hero_nodes[id].position = position


func _process(delta: float) -> void:
	clock += delta
	for index in range(visitors.size()):
		var actor := visitors[index]
		var walk_x := fmod(clock * (8 + index % 3 * 3) + index * WORLD_WIDTH / 10.0, WORLD_WIDTH + 48) - 24
		actor.flip_h = index % 2 == 1
		actor.position = tiles.position + Vector2(WORLD_WIDTH - walk_x if actor.flip_h else walk_x, 247 + index % 2 * 3)
	redraw_time += delta
	if redraw_time < 0.125: return
	redraw_time = 0.0
	queue_redraw()
	ground_details.queue_redraw()
	for body in building_nodes.values(): body.queue_redraw()
	for id in hero_states:
		if hero_states[id] == "training" and int(clock * 8) % 16 == id % 16: hero_nodes[id].play("attack")
		elif hero_nodes[id].animation == &"attack" and not hero_nodes[id].is_playing(): hero_nodes[id].play("idle")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2c4948"))
	var y := tiles.position.y
	draw_rect(Rect2(0, y - 24, WORLD_WIDTH, 280), Color("64aa49"))
	for index in range(40):
		var x := index * 40 + 12
		draw_texture_rect_region(TREE, Rect2(x, y - 62 + index % 3 * 6, 64, 68), Rect2(int(clock * 3 + index) % 4 * 32, 0, 32, 34), Color("b7d599"))
	for x in range(0, WORLD_WIDTH, 32): draw_texture_rect_region(TILES, Rect2(x, y + 256, 32, 32), Rect2(144, 48, 16, 16))


func _draw_ground() -> void:
	for id in building_nodes:
		var feet: Vector2 = building_nodes[id].position
		var path_y: float = tiles.position.y + 224
		var segment_y: float = feet.y
		while segment_y < path_y:
			ground_details.draw_texture_rect_region(TILES, Rect2(feet.x - 16, segment_y, 32, minf(32, path_y - segment_y)), Rect2(160, 112, 16, minf(16, (path_y - segment_y) / 2)))
			segment_y += 32
	for x in [0, 38]: ground_details.draw_rect(Rect2(tiles.position + Vector2(x * 32, 0), Vector2(320, 224)), Color(0.12, 0.22, 0.2, 0.35))
	for x in [10, 38]:
		var boundary := tiles.position + Vector2(x * 32, 0)
		ground_details.draw_line(boundary, boundary + Vector2(0, 224), Color("d7bd78"), 2)
	for x in [5, 42]:
		var pos := tiles.position + Vector2(x * 32, 132)
		ground_details.draw_rect(Rect2(pos + Vector2(-3, 0), Vector2(6, 38)), Color("73533d"))
		ground_details.draw_rect(Rect2(pos + Vector2(-48, -10), Vector2(96, 34)), Color("b18856"))
		ground_details.draw_string(ThemeDB.fallback_font, pos + Vector2(-37, 5), "FUTURE LAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff0ba"))
	if not arranging: return
	for y in range(TownGrid.SIZE.y):
		for x in range(TownGrid.SIZE.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(point_for_cell(cell) - Vector2(TownGrid.CELL_SIZE) * 0.5, Vector2(TownGrid.CELL_SIZE))
			if grid.is_protected(cell) or not TownGrid.OWNED.has_point(cell): ground_details.draw_rect(rect, Color(0.4, 0.25, 0.2, 0.22))
			ground_details.draw_rect(rect, Color(0.85, 0.92, 0.73, 0.45), false, 1)
	for id in grid.buildings: _draw_footprint(id, grid.buildings[id].cell, Color(0.95, 0.8, 0.4, 0.26))
	if not selected_building.is_empty():
		var color := Color(0.3, 0.95, 0.5, 0.5) if grid.can_place(selected_building, preview_cell) else Color(1.0, 0.25, 0.2, 0.5)
		_draw_footprint(selected_building, preview_cell, color)


func _draw_footprint(id: String, cell: Vector2i, color: Color) -> void:
	var footprint := grid.footprint(id, cell)
	var rect := Rect2(tiles.position + Vector2(footprint.position * TownGrid.CELL_SIZE), Vector2(footprint.size * TownGrid.CELL_SIZE))
	ground_details.draw_rect(rect, color)
	ground_details.draw_rect(rect, Color(color, 1), false, 2)
