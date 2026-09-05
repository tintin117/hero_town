extends Node2D

## Decorates the board border/water ring with scattered rocks and a few
## drifting cloud-shadows over the water. Ground/stone/water terrain itself
## is painted by hand on the "Terrain" TileMapLayer sibling.

@onready var grid_system: GridSystem = get_node("../GridSystem")

const BORDER_RING := 1  ## tiles of stone beyond the playable board
const WATER_RING := 2   ## tiles of water beyond the stone ring

var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node2D] = []

func _ready() -> void:
	_rng.seed = 20260901
	_build_rocks()
	_build_clouds()

## Rocks decorate the border/water ring only -- never the playable board.
func _build_rocks() -> void:
	var cols := grid_system.grid_size.x
	var rows := grid_system.grid_size.y
	var outer := BORDER_RING + WATER_RING
	for i in 12:
		var col := _rng.randi_range(-outer, cols + outer - 1)
		var row := _rng.randi_range(-outer, rows + outer - 1)
		if col >= 0 and col < cols and row >= 0 and row < rows:
			continue
		var tex: Texture2D = load(Art.ROCKS[_rng.randi_range(0, Art.ROCKS.size() - 1)])
		var s := Sprite2D.new()
		s.texture = tex
		s.position = grid_system.grid_to_world(Vector2i(col, row)) \
				+ Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-10.0, 10.0))
		s.scale = Vector2.ONE * 0.5
		add_child(s)

func _build_clouds() -> void:
	for i in 5:
		var tex: Texture2D = load(Art.CLOUDS[_rng.randi_range(0, Art.CLOUDS.size() - 1)])
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = Color(1, 1, 1, 0.25)
		s.scale = Vector2.ONE * _rng.randf_range(0.4, 0.7)
		s.position = Vector2(_rng.randf_range(-450.0, 450.0), _rng.randf_range(-190.0, 190.0))
		s.z_index = -1
		add_child(s)
		_clouds.append(s)

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += delta * 6.0
		if cloud.position.x > 500.0:
			cloud.position.x = -500.0
