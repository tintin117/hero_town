@tool
extends McpTestSuite

const GridSystemScript = preload("res://scenes/grid_system.gd")


func suite_name() -> String:
	return "grid_system"


func test_grid_to_world_round_trip() -> void:
	var grid = GridSystemScript.new()
	grid._init_occupancy()
	for row in range(3):
		for col in [0, 4, 9]:
			var world: Vector3 = grid.grid_to_world(row, col)
			var back: Vector2i = grid.world_to_grid(world)
			assert_eq(back, Vector2i(row, col), "round trip failed for (%d,%d)" % [row, col])
	grid.free()


func test_world_to_grid_out_of_bounds() -> void:
	var grid = GridSystemScript.new()
	grid._init_occupancy()
	assert_eq(grid.world_to_grid(Vector3(1000, 0, 1000)), Vector2i(-1, -1))
	grid.free()


func test_occupancy() -> void:
	var grid = GridSystemScript.new()
	grid._init_occupancy()
	assert_true(grid.is_free(1, 2))
	grid.occupy(1, 2, "dummy")
	assert_false(grid.is_free(1, 2))
	grid.clear(1, 2)
	assert_true(grid.is_free(1, 2))
	grid.free()
