extends Control
## Square native tiles; saved footprints remain the original 48 by 8 estate.
signal building_clicked(id: String)
signal construction_requested(id: String, cell: Vector2i)
signal building_moved
const TownGrid := preload("res://game/town_grid.gd")
const Actor := preload("res://resources/art/sunnyside_actor.gd")
const TILES := preload("res://asset/Sunnyside_World_Assets/Tileset/spr_tileset_sunnysideworld_16px.png")
const TREE := preload("res://asset/Sunnyside_World_Assets/Elements/Plants/spr_deco_tree_01_strip4.png")
const PINE := preload("res://asset/Sunnyside_World_Assets/Elements/Plants/spr_deco_tree_02_strip4.png")
const SMOKE := preload("res://asset/Sunnyside_World_Assets/Elements/VFX/Chimney Smoke/chimneysmoke_01_strip30.png")
const WORLD_WIDTH := TownGrid.WORLD_WIDTH
const BUILDING_ART := {
	"tavern": {"size": Vector2(64, 88), "roof_y": 448},
	"hall": {"size": Vector2(96, 80), "roof_y": 192},
	"training": {"size": Vector2(96, 72), "roof_y": 416},
	"infirmary": {"size": Vector2(64, 80), "roof_y": 320},
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
	var ground_palette := Shader.new()
	ground_palette.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); if (c.g > c.r * 1.15 && c.g > c.b * 1.3) { c.rgb = mix(vec3(0.27, 0.39, 0.25), vec3(0.52, 0.66, 0.36), c.g); } COLOR = c; }"
	var ground_material := ShaderMaterial.new()
	ground_material.shader = ground_palette
	tiles.material = ground_material
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
	var half_width := width * 0.5
	canvas.draw_rect(Rect2(-half_width, -12, width, 12), Color("425439"))
	canvas.draw_rect(Rect2(-half_width + 4, -8, width - 8, 8), Color("687c49"))
	if id == "training":
		for y in range(2):
			for x in range(3):
				_building_sprite(canvas, Vector2(-48 + x * 32, -64 + y * 32), Rect2(160, 112, 16, 16))
		canvas.draw_rect(Rect2(-46, -60, 92, 6), Color("624b3a"))
		canvas.draw_rect(Rect2(-46, -58, 92, 2), Color("d8b67c"))
		canvas.draw_rect(Rect2(-46, -46, 92, 4), Color("9b714c"))
		for x in [-46, -16, 14, 42]:
			canvas.draw_rect(Rect2(x, -72, 6, 34), Color("624b3a"))
			canvas.draw_rect(Rect2(x, -72, 6, 4), Color("e0be86"))
			canvas.draw_rect(Rect2(x + 2, -66, 2, 24), Color("ad8457"))
		for x in [-22, 22]:
			canvas.draw_rect(Rect2(x - 4, -32, 8, 26), Color("77523d"))
			canvas.draw_rect(Rect2(x - 14, -22, 28, 4), Color("b98b58"))
			# Stepped targets share the world's two-pixel grid.
			for ring in range(4):
				var radius: int = [12, 10, 6, 4][ring]
				var color: Color = [Color("61493b"), Color("e1bc78"), Color("b86748"), Color("f1d9a2")][ring]
				canvas.draw_rect(Rect2(x - radius + 2, -38 - radius, radius * 2 - 4, radius * 2), color)
				canvas.draw_rect(Rect2(x - radius, -38 - radius + 2, radius * 2, radius * 2 - 4), color)
		for x in [-46, 40]:
			canvas.draw_rect(Rect2(x, -34, 6, 30), Color("79583e"))
			canvas.draw_rect(Rect2(x, -34, 6, 4), Color("dcbc84"))
		canvas.draw_rect(Rect2(-46, -8, 24, 4), Color("ae8758"))
		canvas.draw_rect(Rect2(22, -8, 24, 4), Color("ae8758"))
		return
	# Timber walls, stone footings, and atlas shingles all retain a native 2x grid.
	canvas.draw_rect(Rect2(-half_width + 4, -48, width - 8, 44), Color("664c3d"))
	canvas.draw_rect(Rect2(-half_width + 8, -44, width - 16, 36), Color("ddbb84"))
	for y in [-36, -28, -20, -12]:
		canvas.draw_rect(Rect2(-half_width + 8, y, width - 16, 2), Color("bb9564"))
	for x in [-half_width + 8, half_width - 12]:
		canvas.draw_rect(Rect2(x, -44, 4, 38), Color("8b6245"))
	canvas.draw_rect(Rect2(-half_width + 4, -6, width - 8, 4), Color("989a7d"))
	canvas.draw_rect(Rect2(-half_width + 4, -6, width - 8, 2), Color("c4c6a0"))
	for row in range(3):
		var inset := (2 - row) * 4
		var roof_left := -half_width + inset
		var roof_width := width - inset * 2
		var roof_top := -78 + row * 12
		canvas.draw_rect(Rect2(roof_left, roof_top, roof_width, 16), Color("654d41"))
		var segment := 0.0
		while segment < roof_width - 8:
			var part := minf(16, (roof_width - 8 - segment) * 0.5)
			_building_sprite(canvas, Vector2(roof_left + 4 + segment, roof_top + 2), Rect2(256, art.roof_y + row % 2 * 6, part, 6))
			segment += part * 2
		canvas.draw_rect(Rect2(roof_left, roof_top + 2, 4, 12), Color("be9269"))
		canvas.draw_rect(Rect2(-roof_left - 4, roof_top + 2, 4, 12), Color("97704f"))
	canvas.draw_rect(Rect2(-half_width + 8, -80, width - 16, 4), Color("d2ae7d"))
	canvas.draw_rect(Rect2(-half_width, -42, width, 6), Color("624a3d"))
	canvas.draw_rect(Rect2(-half_width, -42, width, 2), Color("d1a46f"))
	canvas.draw_rect(Rect2(-10, -32, 20, 30), Color("624737"))
	canvas.draw_rect(Rect2(-6, -28, 12, 24), Color("9e714c"))
	canvas.draw_rect(Rect2(-4, -26, 8, 6), Color("485e57"))
	canvas.draw_rect(Rect2(2, -14, 2, 2), Color("efd599"))
	canvas.draw_rect(Rect2(-12, -4, 24, 4), Color("bfbea0"))
	for x in [-half_width + 14, half_width - 26]:
		canvas.draw_rect(Rect2(x, -32, 12, 18), Color("735240"))
		canvas.draw_rect(Rect2(x + 2, -30, 8, 12), Color("628e88"))
		canvas.draw_rect(Rect2(x + 2, -30, 2, 10), Color("b3d8bf"))
		canvas.draw_rect(Rect2(x, -18, 12, 4), Color("a4784f"))
	if id == "infirmary":
		canvas.draw_rect(Rect2(-12, -54, 24, 20), Color("735e48"))
		canvas.draw_rect(Rect2(-10, -52, 20, 16), Color("f2e1b5"))
		canvas.draw_rect(Rect2(-2, -50, 4, 12), Color("51855a"))
		canvas.draw_rect(Rect2(-6, -46, 12, 4), Color("51855a"))
		for x in [-30, 14]:
			_building_sprite(canvas, Vector2(x, -22), Rect2(432, 32, 8, 8))
			canvas.draw_rect(Rect2(x, -10, 16, 8), Color("956b4e"))
			canvas.draw_rect(Rect2(x, -10, 16, 2), Color("cfac79"))
			canvas.draw_rect(Rect2(x + 6, -18, 4, 4), Color("c6ca87"))
	elif id == "tavern":
		for stripe in range(7):
			canvas.draw_rect(Rect2(-28 + stripe * 8, -38, 8, 12), Color("e7c892") if stripe % 2 == 0 else Color("ab5d43"))
		canvas.draw_rect(Rect2(-28, -26, 56, 2), Color("694c3b"))
		canvas.draw_rect(Rect2(16, -14, 4, 12), Color("78563d"))
		canvas.draw_rect(Rect2(26, -14, 4, 12), Color("78563d"))
		canvas.draw_rect(Rect2(14, -18, 18, 6), Color("cca16a"))
		canvas.draw_rect(Rect2(18, -20, 6, 2), Color("f1dfb5"))
		canvas.draw_rect(Rect2(-30, -18, 16, 16), Color("77553f"))
		canvas.draw_rect(Rect2(-28, -16, 12, 12), Color("b9915c"))
		canvas.draw_rect(Rect2(-28, -12, 12, 2), Color("77553f"))
		canvas.draw_rect(Rect2(-24, -16, 2, 12), Color("dfbb79"))
		canvas.draw_rect(Rect2(12, -86, 12, 22), Color("785e50"))
		canvas.draw_rect(Rect2(14, -84, 8, 18), Color("ab8a70"))
		canvas.draw_rect(Rect2(10, -88, 16, 4), Color("cfb695"))
		canvas.draw_texture_rect_region(SMOKE, Rect2(2, -156, 30, 74), Rect2(int(clock * 8) % 30 * 15, 0, 15, 37), Color(1, 1, 1, 0.55))
	else:
		canvas.draw_rect(Rect2(-12, -56, 24, 20), Color("70533f"))
		canvas.draw_rect(Rect2(-10, -54, 20, 16), Color("d8bc80"))
		canvas.draw_rect(Rect2(-4, -52, 8, 10), Color("547b8c"))
		canvas.draw_rect(Rect2(-2, -42, 4, 2), Color("547b8c"))
		for x in [-42, 30]:
			canvas.draw_rect(Rect2(x, -34, 12, 26), Color("547b8c"))
			canvas.draw_rect(Rect2(x + 2, -32, 8, 2), Color("d2bb7f"))
			canvas.draw_rect(Rect2(x + 4, -28, 4, 10), Color("d2bb7f"))


func _building_sprite(canvas: CanvasItem, position: Vector2, source: Rect2) -> void:
	canvas.draw_texture_rect_region(TILES, Rect2(position, source.size * 2), source)


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
		actor.position = (tiles.position + Vector2(WORLD_WIDTH - walk_x if actor.flip_h else walk_x, 246 + index % 2 * 4)).snapped(Vector2(2, 2))
	redraw_time += delta
	if redraw_time < 0.125: return
	redraw_time = 0.0
	queue_redraw()
	for body in building_nodes.values(): body.queue_redraw()
	for id in hero_states:
		if hero_states[id] == "training" and int(clock * 8) % 16 == id % 16: hero_nodes[id].play("attack")
		elif hero_nodes[id].animation == &"attack" and not hero_nodes[id].is_playing(): hero_nodes[id].play("idle")


func _draw() -> void:
	var y := tiles.position.y
	var backdrop_width := maxf(size.x, get_viewport_rect().size.x)
	draw_rect(Rect2(0, 0, backdrop_width, size.y), Color("abc4b0"))
	# Stepped distant ridges give taller windows a quiet backdrop behind the HUD.
	for layer in range(3):
		var ridge := PackedVector2Array([Vector2(0, y + 16)])
		for x in range(0, int(backdrop_width) + 32, 32):
			var ridge_y := snappedf(y - 54 - (2 - layer) * 68 - sin(x * 0.006 + layer * 2) * (24 + layer * 8), 8)
			ridge.append(Vector2(x, ridge_y))
			ridge.append(Vector2(x + 32, ridge_y))
		ridge.append(Vector2(backdrop_width + 32, y + 16))
		draw_colored_polygon(ridge, [Color("8fab99"), Color("728f7e"), Color("4d7263")][layer])
	draw_rect(Rect2(0, y - 12, WORLD_WIDTH, 268), Color("607f44"))
	for index in range(66):
		var pine := index % 5 == 0 or index % 7 == 0
		var frame_size := Vector2(28, 43) if pine else Vector2(32, 34)
		var x := index * 24 - 18 + (index * 17 % 7) * 2
		var bottom := y + 2 + (index * 11 % 5) * 2
		draw_texture_rect_region(PINE if pine else TREE, Rect2(Vector2(x, bottom) - Vector2(0, frame_size.y * 2), frame_size * 2), Rect2(Vector2(int(clock * 3 + index) % 4 * frame_size.x, 0), frame_size), Color("becda6") if index % 3 == 0 else Color.WHITE)
	for x in range(0, WORLD_WIDTH, 32): draw_texture_rect_region(TILES, Rect2(x, y + 256, 32, 32), Rect2(144, 48, 16, 16))


func _draw_ground() -> void:
	var origin := tiles.position
	# Local seed: scenery stays fixed and never consumes combat randomness.
	var scenery := RandomNumberGenerator.new()
	scenery.seed = 481516
	var grass_colors := [Color("607f46"), Color("819c53"), Color("91aa60"), Color("5e8249")]
	for index in range(2200):
		var p := origin + Vector2(scenery.randi_range(0, WORLD_WIDTH / 2 - 1) * 2, scenery.randi_range(1, 110) * 2)
		var color: Color = grass_colors[index % grass_colors.size()]
		ground_details.draw_rect(Rect2(p, Vector2(2 + index % 3 * 2, 2)), color)
		if index % 4 == 0:
			ground_details.draw_rect(Rect2(p + Vector2(2, -2), Vector2(2, 2)), color)
	# Pebbles and tiny flower patches collect along the path and forest edges.
	for index in range(100):
		var p := origin + Vector2(scenery.randi_range(2, WORLD_WIDTH / 2 - 4) * 2, scenery.randi_range(4, 18) * 2 if index % 2 == 0 else scenery.randi_range(94, 101) * 2)
		var detail := Rect2(432 + index % 4 * 16, 64, 16, 16)
		if index % 3 == 0: detail = Rect2(496 + index % 4 * 16, 16 + (index % 9) / 3 * 16, 16, 16)
		ground_details.draw_texture_rect_region(TILES, Rect2(p, Vector2(32, 32)), detail)
	# Grass nibbles into the straight public path; a dark verge seats it in the lawn.
	ground_details.draw_rect(Rect2(origin + Vector2(0, 222), Vector2(WORLD_WIDTH, 2)), Color("627548"))
	for x in range(0, WORLD_WIDTH, 8):
		ground_details.draw_rect(Rect2(origin + Vector2(x, 222), Vector2(4, 2 + (x % 3) * 2)), Color("829652"))
	for id in building_nodes:
		var feet: Vector2 = building_nodes[id].position
		var path_y: float = tiles.position.y + 224
		var segment_y: float = feet.y
		while segment_y < path_y:
			ground_details.draw_texture_rect_region(TILES, Rect2(feet.x - 12, segment_y, 24, minf(24, path_y - segment_y)), Rect2(160, 112, 12, minf(12, (path_y - segment_y) / 2)))
			ground_details.draw_rect(Rect2(feet.x - 12, segment_y, 2, minf(24, path_y - segment_y)), Color("b28d64"))
			segment_y += 32
	# Small garden plots furnish the preview land, leaving every owned plot usable.
	for side in [0, 1]:
		var plot := origin + Vector2(64 if side == 0 else 1376, 66)
		ground_details.draw_rect(Rect2(plot + Vector2(-4, -4), Vector2(104, 70)), Color("4f693c"))
		ground_details.draw_rect(Rect2(plot, Vector2(96, 62)), Color("846647"))
		for row in range(3):
			ground_details.draw_rect(Rect2(plot + Vector2(2, row * 20 + 16), Vector2(92, 4)), Color("5f503d"))
			for column in range(5):
				ground_details.draw_texture_rect_region(TILES, Rect2(plot + Vector2(column * 18 + 2, row * 20 - 8), Vector2(24, 32)), Rect2(864 + side * 16, 232, 12, 16))
		for prop in range(3):
			ground_details.draw_texture_rect_region(TILES, Rect2(plot + Vector2(4 + prop * 32, 82), Vector2(32, 32)), Rect2(576 + prop % 2 * 16, 144, 16, 16))
	for x in [0, 38]: ground_details.draw_rect(Rect2(tiles.position + Vector2(x * 32, 0), Vector2(320, 224)), Color(0.12, 0.22, 0.2, 0.16))
	for x in [10, 38]:
		var boundary := tiles.position + Vector2(x * 32, 0)
		for fence_y in range(8, 224, 32):
			ground_details.draw_texture_rect_region(TILES, Rect2(boundary + Vector2(-8, fence_y), Vector2(16, 32)), Rect2(672, 16, 8, 16))
		if arranging: ground_details.draw_line(boundary, boundary + Vector2(0, 224), Color("d7bd78"), 2)
	for x in [5, 42]:
		var pos := tiles.position + Vector2(x * 32, 132)
		ground_details.draw_rect(Rect2(pos + Vector2(-4, 0), Vector2(8, 38)), Color("5b513b"))
		ground_details.draw_rect(Rect2(pos + Vector2(-48, -10), Vector2(96, 34)), Color("554b38"))
		ground_details.draw_rect(Rect2(pos + Vector2(-46, -8), Vector2(92, 28)), Color("a58252"))
		ground_details.draw_rect(Rect2(pos + Vector2(-44, -6), Vector2(88, 2)), Color("d3b475"))
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
