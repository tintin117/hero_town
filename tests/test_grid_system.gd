@tool
extends McpTestSuite

const GridSystemScript = preload("res://scenes/grid_system.gd")


func suite_name() -> String:
	return "grid_system"


## Built standalone (not added to the scene tree) so the test doesn't depend
## on the test runner's own tree state -- tile_map is assigned directly
## instead of relying on GridSystem's @onready sibling lookup.
func _make_grid() -> GridSystem:
	var tile_map := TileMapLayer.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	tile_map.tile_set = tile_set
	var grid: GridSystem = GridSystemScript.new()
	grid.tile_map = tile_map
	return grid


func _free_grid(grid: GridSystem) -> void:
	grid.tile_map.free()
	grid.free()


func test_grid_to_world_round_trip() -> void:
	var grid := _make_grid()
	for row in range(3):
		for col in [0, 4, 9]:
			var cell := Vector2i(col, row)
			var world: Vector2 = grid.grid_to_world(cell)
			var back: Vector2i = grid.world_to_grid(world)
			assert_eq(back, cell, "round trip failed for %s" % cell)
	_free_grid(grid)


func test_world_to_grid_out_of_bounds() -> void:
	var grid := _make_grid()
	assert_eq(grid.world_to_grid(Vector2(10000, 10000)), Vector2i(-1, -1))
	_free_grid(grid)


func test_occupancy() -> void:
	var grid := _make_grid()
	var cell := Vector2i(1, 2)
	assert_true(grid.is_free(cell))
	grid.occupy(cell, "dummy")
	assert_false(grid.is_free(cell))
	grid.clear(cell)
	assert_true(grid.is_free(cell))
	_free_grid(grid)
