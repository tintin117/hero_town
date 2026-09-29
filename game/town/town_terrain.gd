extends TileMapLayer
## Deterministic ground: flat grass everywhere, a dirt path on the public row (logical row 7),
## and a child `Details` layer of tufts, flowers and pebbles scattered on top.

const GRASS_PLAIN := Vector2i(1, 1)
const PATH_RIM := Vector2i(5, 8)
const DIRT: Array[Vector2i] = [Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(9, 8), Vector2i(10, 8)]
const COLUMNS := 48
const ROWS := 8
const PATH_ROW := 7
const ARENA_COLUMNS := Vector2i(16, 32)

@onready var details: TileMapLayer = $Details


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if y == PATH_ROW:
				set_cell(cell, 0, DIRT[absi((x * 73856093) ^ (y * 19349663)) % DIRT.size()])
				details.set_cell(cell, 0, PATH_RIM)
			else:
				set_cell(cell, 0, GRASS_PLAIN)
			if y < PATH_ROW and rng.randf() < 0.16 and not (x >= ARENA_COLUMNS.x and x < ARENA_COLUMNS.y):
				details.set_cell(cell, 0, Vector2i(rng.randi_range(27, 35), rng.randi_range(1, 3)))
