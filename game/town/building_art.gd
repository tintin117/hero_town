extends RefCounted
## Building sprites composed from the 16 px Sunnyside sheet at 2x. Each build() returns a Node2D whose origin is
## the footprint's top-left; art may poke a little above it. Level shows as flags, pots and a pip row.

const SHEET := preload("res://asset/Sunnyside_World_Assets/Tileset/spr_tileset_sunnysideworld_16px.png")
const CELL := 32
const SCALE := 2
const PIP_ON := Color("f2c14e")
const PIP_OFF := Color(0.13, 0.1, 0.08, 0.8)
# Sheet regions (px): shopfront columns (awning | wall, 16 px rows from y=400), stalls, and props.
const SHOP_X := {&"blue": 624, &"orange": 672, &"green": 720}
const ROOF_Y := {&"blue": 144, &"green": 272, &"orange": 400}  # shingle strips, one colour set per 128 px
const STALL_X := {&"orange": 662}
const POT := Rect2(835, 511, 13, 16)
const BARREL := Rect2(611, 259, 12, 12)
const CRATE := Rect2(567, 144, 16, 16)
const CRATES := Rect2(567, 144, 16, 32)
const FENCE := Rect2(613, 33, 16, 12)
const FENCE_END := Rect2(677, 33, 6, 12)
const TABLE := Rect2(769, 537, 12, 12)
const POSTER := Rect2(866, 531, 14, 12)
const PENNANT_RED := Color("d24a3e")
const PENNANT_GOLD := Color("f2c14e")
const EAVE := Color("5b3a34")
const SAND := Color("dcbd7c")
const SAND_EDGE := Color("b98b58")
const WOOD := Color("77523d")
const WOOD_LIGHT := Color("b98b58")
const STRAW := Color("ecd38f")
const STRAW_EDGE := Color("8a5e3c")
const BELT := Color("b8503e")


static func build(id: StringName, level: int, footprint: Vector2i) -> Node2D:
	var root := Node2D.new()
	var size := Vector2(footprint * CELL)
	match id:
		&"gym":
			_yard(root, size)
		&"restaurant":
			_house(root, size, &"orange", 3, [[TABLE, 36], [BARREL, 6]])
		&"recruitment_hall":
			_house(root, size, &"green", 2, [[CRATE, 8], [BARREL, 76]])
		_:  # promotion_office and anything unknown
			_house(root, size, &"blue", 3, [[POSTER, 6], [BARREL, 44]])
	if level >= 2:
		_pennant(root, Vector2(size.x - 10, 0), PENNANT_RED)
	if level >= 3:
		_pennant(root, Vector2(6, 0), PENNANT_GOLD)
		_rect(root, Rect2(-4, 28, size.x + 8, 2), PIP_ON)
		_piece(root, POT, Vector2(-8, size.y - 30))
		_piece(root, POT, Vector2(size.x - 18, size.y - 30))
	_pips(root, level, size)
	return root


## Two shingle rows over a shopfront row, tiled to the footprint width, plus a few props in front.
static func _house(parent: Node2D, size: Vector2, color: StringName, wall_row: int, props: Array) -> void:
	var x: int = SHOP_X[color]
	for col in range(-4, int(size.x) + 4, 64):  # roof overhangs the walls by 4 px
		for row in 2:
			_piece(parent, Rect2(416, ROOF_Y[color], minf(32.0, (size.x + 4 - col) / SCALE), 8), Vector2(col, row * 16))
	_rect(parent, Rect2(-4, 30, size.x + 8, 2), EAVE)
	_piece(parent, Rect2(x, 400 + wall_row * 16, 32, 16), Vector2(0, 32))
	if size.x > 64:
		_piece(parent, Rect2(x + 16, 416, 16, 16), Vector2(64, 32))  # plain planks
	for prop: Array in props:
		_piece(parent, prop[0], Vector2(prop[1], size.y - prop[0].size.y * SCALE - 2))


## Open training yard: sand floor, fence along the back, two straw dummies and a weapon crate.
static func _yard(parent: Node2D, size: Vector2) -> void:
	_rect(parent, Rect2(Vector2.ZERO, size), SAND_EDGE)
	_rect(parent, Rect2(2, 2, size.x - 4, size.y - 4), SAND)
	for x in range(0, int(size.x) - 12, 32):
		_piece(parent, FENCE, Vector2(x, 0))
	_piece(parent, FENCE_END, Vector2(size.x - 12, 0))
	for x in [size.x * 0.25, size.x * 0.6]:
		_dummy(parent, Vector2(roundf(x / 2.0) * 2.0, size.y - 8))
	_piece(parent, CRATES, Vector2(size.x - 34, size.y - 62))


## Straw dummy standing at `feet` (2 px grid): post, arms, sack body, head, red target belt.
static func _dummy(parent: Node2D, feet: Vector2) -> void:
	_rect(parent, Rect2(feet + Vector2(-2, -30), Vector2(4, 30)), WOOD)
	_rect(parent, Rect2(feet + Vector2(-14, -24), Vector2(28, 4)), WOOD_LIGHT)
	_rect(parent, Rect2(feet + Vector2(-8, -30), Vector2(16, 18)), STRAW_EDGE)
	_rect(parent, Rect2(feet + Vector2(-6, -28), Vector2(12, 14)), STRAW)
	_rect(parent, Rect2(feet + Vector2(-6, -22), Vector2(12, 4)), BELT)
	_rect(parent, Rect2(feet + Vector2(-6, -42), Vector2(12, 12)), STRAW_EDGE)
	_rect(parent, Rect2(feet + Vector2(-4, -40), Vector2(8, 8)), STRAW)


## Roof pennant: 2 px pole and a stepped flag, standing on the roof line at `at`.
static func _pennant(parent: Node2D, at: Vector2, color: Color) -> void:
	_rect(parent, Rect2(at + Vector2(0, -22), Vector2(2, 24)), WOOD)
	_rect(parent, Rect2(at + Vector2(2, -22), Vector2(10, 4)), color)
	_rect(parent, Rect2(at + Vector2(2, -18), Vector2(6, 4)), color)


static func _pips(parent: Node2D, level: int, size: Vector2) -> void:
	for i in 3:
		_rect(parent, Rect2(size.x / 2.0 - 15 + i * 10, size.y - 8, 8, 6), PIP_ON if i < level else PIP_OFF)


static func _piece(parent: Node2D, region: Rect2, at: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.position = at
	parent.add_child(sprite)


static func _rect(parent: Node2D, rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
