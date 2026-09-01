extends Node3D

## Procedurally lays the hex diorama: board tiles, a decorated border ring, a
## water ring, a few distant islands, and drifting clouds. Deterministic seed so
## the town looks the same every run.

const TILE_GRASS := preload("res://asset/kaykit/hexagon/tiles/hex_grass.gltf")
const TILE_WATER := preload("res://asset/kaykit/hexagon/tiles/hex_water.gltf")

const BORDER_DECOR: Array = [
	preload("res://asset/kaykit/hexagon/nature/tree_single_A.gltf"),
	preload("res://asset/kaykit/hexagon/nature/tree_single_B.gltf"),
	preload("res://asset/kaykit/hexagon/nature/trees_A_medium.gltf"),
	preload("res://asset/kaykit/hexagon/nature/trees_B_small.gltf"),
	preload("res://asset/kaykit/hexagon/nature/hill_single_A.gltf"),
	preload("res://asset/kaykit/hexagon/nature/rock_single_B.gltf"),
]
const WATER_DECOR: Array = [
	preload("res://asset/kaykit/hexagon/nature/waterlily_A.gltf"),
	preload("res://asset/kaykit/hexagon/nature/waterplant_A.gltf"),
]
const ISLAND_DECOR: Array = [
	preload("res://asset/kaykit/hexagon/nature/mountain_A_grass_trees.gltf"),
	preload("res://asset/kaykit/hexagon/nature/hills_A_trees.gltf"),
	preload("res://asset/kaykit/hexagon/nature/mountain_B_grass.gltf"),
	preload("res://asset/kaykit/hexagon/nature/trees_A_large.gltf"),
]
const CLOUDS: Array = [
	preload("res://asset/kaykit/hexagon/nature/cloud_big.gltf"),
	preload("res://asset/kaykit/hexagon/nature/cloud_small.gltf"),
]

@onready var grid_system: GridSystem = get_node("../GridSystem")

var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []

func _ready() -> void:
	_rng.seed = 20260901
	_build_board()
	_build_islands()
	_build_clouds()

func _hex_pos(row: int, col: int) -> Vector3:
	return grid_system.grid_to_world(row, col)

func _place(scene: PackedScene, pos: Vector3, rot_steps: int = -1, parent: Node3D = self) -> Node3D:
	var node: Node3D = scene.instantiate()
	node.position = pos
	if rot_steps < 0:
		rot_steps = _rng.randi_range(0, 5)
	node.rotation.y = rot_steps * PI / 3.0
	parent.add_child(node)
	return node

func _build_board() -> void:
	var rows := GridSystem.GRID_ROWS
	var cols := grid_system.grid_cols
	# ring 0 = playable board, ring 1 = grassy border, ring 2 = water edge
	for row in range(-2, rows + 2):
		for col in range(-2, cols + 2):
			var ring := maxi(0, maxi(maxi(-row, row - (rows - 1)), maxi(-col, col - (cols - 1))))
			var pos := _hex_pos(row, col)
			match ring:
				0:
					_place(TILE_GRASS, pos)
				1:
					pos.y = -0.12 - _rng.randf() * 0.08
					_place(TILE_GRASS, pos)
					if _rng.randf() < 0.55:
						_place(BORDER_DECOR[_rng.randi_range(0, BORDER_DECOR.size() - 1)], pos)
				2:
					pos.y = -0.45
					_place(TILE_WATER, pos)
					if _rng.randf() < 0.12:
						_place(WATER_DECOR[_rng.randi_range(0, WATER_DECOR.size() - 1)], pos)

func _build_islands() -> void:
	# A few floating hexes drifting past the board edges for depth.
	var spots := [
		Vector3(-18.5, -1.2, -8.0), Vector3(17.0, -1.8, -9.5), Vector3(-16.0, -2.2, 8.5),
		Vector3(19.5, -1.0, 6.0), Vector3(0.5, -2.6, -11.5), Vector3(7.5, -2.0, 10.5),
	]
	for pos in spots:
		var tile := _place(TILE_GRASS, pos)
		tile.scale = Vector3.ONE * _rng.randf_range(0.9, 1.4)
		_place(ISLAND_DECOR[_rng.randi_range(0, ISLAND_DECOR.size() - 1)], pos)

func _build_clouds() -> void:
	for i in 7:
		var pos := Vector3(_rng.randf_range(-20, 20), _rng.randf_range(9.0, 13.0), _rng.randf_range(-16, -4))
		var cloud := _place(CLOUDS[_rng.randi_range(0, 1)], pos)
		cloud.scale = Vector3.ONE * _rng.randf_range(0.6, 1.1)
		_clouds.append(cloud)

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += delta * 0.25
		if cloud.position.x > 24.0:
			cloud.position.x = -24.0
