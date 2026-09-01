extends Node2D

## Paints the pixel-art board: grass interior, a stone border ring, water beyond,
## scattered rocks, and a few drifting cloud-shadows over the water.

@onready var grid_system: GridSystem = get_node("../GridSystem")

const BORDER_RING := 1  ## tiles of stone beyond the playable board
const WATER_RING := 2   ## tiles of water beyond the stone ring

var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node2D] = []
var _tileset_tex: Texture2D
var _water_tex: Texture2D

func _ready() -> void:
	_rng.seed = 20260901
	_tileset_tex = load(Art.TILESET_IMAGE)
	_water_tex = load(Art.WATER_TILE)
	_build_terrain()
	_build_rocks()
	_build_clouds()

func _make_swatch_tile(swatch_rect: Rect2, cell_pos: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = _tileset_tex
	atlas.region = swatch_rect
	var s := Sprite2D.new()
	s.texture = atlas
	s.position = cell_pos
	add_child(s)

func _build_terrain() -> void:
	var rows := GridSystem.GRID_ROWS
	var cols := grid_system.grid_cols
	var outer := BORDER_RING + WATER_RING
	for row in range(-outer, rows + outer):
		for col in range(-outer, cols + outer):
			var pos := grid_system.grid_to_world(row, col)
			var on_board := row >= 0 and row < rows and col >= 0 and col < cols
			var in_border := row >= -BORDER_RING and row < rows + BORDER_RING \
					and col >= -BORDER_RING and col < cols + BORDER_RING
			if on_board:
				_make_swatch_tile(Art.GRASS_SWATCH, pos)
			elif in_border:
				_make_swatch_tile(Art.STONE_SWATCH, pos)
			else:
				var s := Sprite2D.new()
				s.texture = _water_tex
				s.position = pos
				s.z_index = -1
				add_child(s)

## Rocks decorate the border/water ring only -- never the playable board.
func _build_rocks() -> void:
	var rows := GridSystem.GRID_ROWS
	var cols := grid_system.grid_cols
	var outer := BORDER_RING + WATER_RING
	for i in 12:
		var row := _rng.randi_range(-outer, rows + outer - 1)
		var col := _rng.randi_range(-outer, cols + outer - 1)
		if row >= 0 and row < rows and col >= 0 and col < cols:
			continue
		var tex: Texture2D = load(Art.ROCKS[_rng.randi_range(0, Art.ROCKS.size() - 1)])
		var s := Sprite2D.new()
		s.texture = tex
		s.position = grid_system.grid_to_world(row, col) \
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
