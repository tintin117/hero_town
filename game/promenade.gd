extends Control
## Decorative promenade, using the same Tiny Swords pack as the heroes.
const ROOT := "res://asset/Tiny Swords (Free Pack)/"
const TILES := preload(ROOT + "Terrain/Tileset/Tilemap_color1.png")
const HOUSE := preload(ROOT + "Buildings/Blue Buildings/House1.png")
const BARRACKS := preload(ROOT + "Buildings/Blue Buildings/Barracks.png")
const TREE := preload(ROOT + "Terrain/Resources/Wood/Trees/Tree1.png")
const BUSH := preload(ROOT + "Terrain/Decorations/Bushes/Bushe1.png")
const CLOUD := preload(ROOT + "Terrain/Decorations/Clouds/Clouds_01.png")
const WALKER := preload(ROOT + "Units/Blue Units/Pawn/Pawn_Run.png")
var clock := 0.0
var redraw_time := 0.0


func _process(delta: float) -> void:
	clock += delta
	redraw_time += delta
	# ponytail: 12 decorative frames/second suffice; use sprite nodes if this scene grows.
	if redraw_time >= 1.0 / 12.0:
		redraw_time = 0.0
		queue_redraw()


func _draw() -> void:
	var ground := size.y - 272.0
	for band in range(16):
		var color := Color("344d65").lerp(Color("8ca8a2"), float(band) / 15.0)
		draw_rect(Rect2(0, size.y * band / 16.0, size.x, size.y / 16.0 + 1), color)
	for cloud in range(3):
		var x := fmod(cloud * size.x / 3.0 + clock * 3.0, size.x + 220.0) - 110.0
		draw_texture_rect(CLOUD, Rect2(x, ground - 90.0 + cloud * 13, 220, 92), false, Color(0.8, 0.9, 0.95, 0.3))
	# A quiet treeline behind the grounds; buildings and combat keep the stronger contrast.
	for i in range(19):
		var x := float(i) * size.x / 18.0
		var height := 70.0 + sin(i * 2.7) * 18.0
		draw_texture_rect_region(TREE, Rect2(x - 38, ground - height + 24, 76, height), Rect2(0, 0, 192, 256), Color("5b7d7d"))
	for y in range(int(ground), int(size.y - 80), 48):
		for x in range(0, int(size.x), 48):
			draw_texture_rect_region(TILES, Rect2(x, y, 48, 48), Rect2(64, 64, 64, 64), Color("c1c6a4"))
	for x in range(0, int(size.x), 48):
		draw_texture_rect_region(TILES, Rect2(x, size.y - 104, 48, 48), Rect2(384, 192, 64, 64))
		draw_texture_rect_region(TILES, Rect2(x, size.y - 70, 48, 40), Rect2(384, 256, 64, 64))
	var path_y := size.y - 112.0
	draw_line(Vector2(0, path_y), Vector2(size.x, path_y), Color("9b8962"), 30.0)
	draw_line(Vector2(0, path_y - 2), Vector2(size.x, path_y - 2), Color("c5b17d"), 23.0)
	for x in range(0, int(size.x), 24):
		draw_line(Vector2(x, path_y - 9), Vector2(x + 14, path_y - 9), Color("ddd09c"), 2.0)
		draw_line(Vector2(x + 6, path_y + 6), Vector2(x + 18, path_y + 6), Color("ae9d71"), 2.0)
	var building_scale := minf(1.0, size.x / 1280.0)
	var left := Vector2(size.x * 0.075, path_y - 85)
	var right := Vector2(size.x * 0.925, path_y - 85)
	# Two small town blocks leave six visible plots clear for future buildings.
	for side in [-1, 1]:
		for column in [0.075, 0.18]:
			var x: float = size.x * (column if side < 0 else 1.0 - column)
			draw_line(Vector2(x, path_y - 112), Vector2(x, path_y), Color("9b8962"), 14.0)
			draw_line(Vector2(x, path_y - 112), Vector2(x, path_y), Color("c5b17d"), 10.0)
			_plot(Vector2(x, path_y - 39), Vector2(98 * building_scale, 44))
			if column > 0.1:
				_plot(Vector2(x, path_y - 113), Vector2(98 * building_scale, 44))
	_building(HOUSE, left, Vector2(96, 128) * building_scale, "TAVERN")
	_building(BARRACKS, right, Vector2(120, 132) * building_scale, "BARRACKS")
	for side in [-1, 1]:
		var x := size.x * (0.025 if side < 0 else 0.975)
		draw_texture_rect_region(TREE, Rect2(x - 25, ground - 55, 50, 84), Rect2(int(clock * 5) % 8 * 192, 0, 192, 256))
		draw_texture_rect_region(BUSH, Rect2(x - 24, path_y + 4, 48, 32), Rect2(int(clock * 4) % 8 * 128, 0, 128, 128))
	# Visitors stay on the public path, outside the simulated combat floor.
	for i in range(7):
		var progress := fmod(clock * (9.0 + i) + i * size.x / 7.0, size.x + 64.0) - 32.0
		var x := progress if i % 2 == 0 else size.x - progress
		var dest := Rect2(x - 13, path_y - 22 + (i % 3) * 3, 26, 34)
		if i % 2 != 0:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		draw_texture_rect_region(WALKER, dest, Rect2((int(clock * 8) + i) % 6 * 192 + 64, 48, 64, 88))
	# A slow chimney puff makes the quiet world feel inhabited.
	for puff in range(3):
		var phase := fmod(clock * 0.2 + puff / 3.0, 1.0)
		draw_circle(left + Vector2((-16 + phase * 12) * building_scale, -96 * building_scale - phase * 24), 3 + phase * 4, Color(0.86, 0.9, 0.9, (1.0 - phase) * 0.25))


func _plot(center: Vector2, dimensions: Vector2) -> void:
	var plot := Rect2(center - dimensions * 0.5, dimensions)
	draw_rect(plot, Color("9aa868"))
	draw_rect(plot, Color("c4c98b"), false, 1.0)
	for corner in [plot.position, Vector2(plot.end.x, plot.position.y), plot.end, Vector2(plot.position.x, plot.end.y)]:
		draw_line(corner, corner - Vector2(0, 7), Color("705737"), 3.0)
		draw_line(corner - Vector2(1, 7), corner + Vector2(2, -7), Color("d6bc84"), 2.0)
	draw_string(ThemeDB.fallback_font, plot.position + Vector2(0, dimensions.y * 0.5 + 4), "OPEN PLOT", HORIZONTAL_ALIGNMENT_CENTER, dimensions.x, 10, Color("4d603f"))


func _building(texture: Texture2D, feet: Vector2, dimensions: Vector2, title: String) -> void:
	draw_set_transform(feet, 0.0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, dimensions.x * 0.43, Color(0.1, 0.2, 0.18, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(texture, Rect2(feet - Vector2(dimensions.x * 0.5, dimensions.y), dimensions), false)
	var sign_width := minf(78.0, dimensions.x)
	var sign := Rect2(feet + Vector2(-sign_width * 0.5, -18), Vector2(sign_width, 18))
	draw_rect(sign.grow(2), Color("453b30"))
	draw_rect(sign, Color("c5a875"))
	draw_string(ThemeDB.fallback_font, sign.position + Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_CENTER, sign_width, 10, Color("332e2c"))
