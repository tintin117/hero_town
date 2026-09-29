extends Node2D
## Seating wings and spectators. One draw pass, no nodes per spectator.
## set_seats(seats) picks how many bench rows exist (a bigger arena tier shows more rows),
## set_attendance(n) how many of the seats are taken, cheer(strength) makes them jump.

const BASE := preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/base_idle_strip9.png")
const HAIRS := [
	preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/mophair_idle_strip9.png"),
	preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/curlyhair_idle_strip9.png"),
	preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/shorthair_idle_strip9.png"),
]
const HAIR_COLORS := [Color("dca583"), Color("ffdf99"), Color("766776"), Color("bf653e"), Color("302b45")]
const SKIN_COLORS := [Color("ead8bc"), Color.WHITE, Color("f3c9a5"), Color("d9b48f")]
const FRAME := Vector2(96, 64)
const CROP := Rect2(32, 13, 32, 40)  # body area of an idle frame
const FOOT_IN_CROP := Vector2(16, 26)
const SCALE := 0.75
const COLUMNS := 4
const COLUMN_STEP := 23.0
const ROW_STEP := 26.0
const SEATS_PER_ROW := 25  # 100 / 150 / 200 seats show 4 / 6 / 8 rows per wing
const WING_WIDTH := 100.0
const CENTER_Y := 140.0
const RIGHT_EDGE := 512.0
const GROW_SPEED := 40.0  # spectators per second while the crowd fills

var _rows := 0
var _slots := PackedVector2Array()  # spectator feet, row by row, left wing then right wing
var _style := PackedInt32Array()  # per slot: hair * 16 + hair colour * 4 + skin
var _rank := PackedInt32Array()  # a slot is taken while its rank < _shown
var _phase := PackedFloat32Array()
var _target := 0.0
var _shown := 0.0
var _cheer := 0.0
var _clock := 0.0
var _last_frame := -1


func set_seats(seats: int) -> void:
	var rows := maxi(2, seats / SEATS_PER_ROW)
	if rows != _rows:
		_rows = rows
		_build()
	queue_redraw()


func set_attendance(attendance: int, seats: int) -> void:
	_target = float(_slots.size()) * clampf(float(attendance) / maxf(1.0, seats), 0.0, 1.0)


func cheer(strength: float) -> void:
	_cheer = clampf(_cheer + strength, 0.0, 2.0)


func visible_spectators() -> int:
	return int(_shown)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4  # fixed look, independent from the fight RNG
	_slots.clear()
	_style.clear()
	_phase.clear()
	var top := CENTER_Y - _rows * ROW_STEP * 0.5 + ROW_STEP
	for mirrored in [false, true]:
		for row in _rows:
			for column in COLUMNS:
				var x := 14.0 + column * COLUMN_STEP + (row % 2) * 5.0
				_slots.append(Vector2(RIGHT_EDGE - x if mirrored else x, top + row * ROW_STEP))
				_style.append(rng.randi_range(0, 2) * 16 + rng.randi_range(0, 3) * 4 + rng.randi_range(0, 3))
				_phase.append(rng.randf() * TAU)
	_rank.resize(_slots.size())
	for i in _rank.size():
		_rank[i] = i
	for i in range(_rank.size() - 1, 0, -1):  # shuffle: seats fill in a scattered order
		var j := rng.randi_range(0, i)
		var swap := _rank[i]
		_rank[i] = _rank[j]
		_rank[j] = swap
	_shown = minf(_shown, _slots.size())


func _process(delta: float) -> void:
	_clock += delta
	_cheer = maxf(0.0, _cheer - delta * 0.8)
	var before := int(_shown)
	_shown = move_toward(_shown, _target, GROW_SPEED * delta)
	var frame := int(_clock * 6.0)
	if _cheer > 0.0 or int(_shown) != before or frame != _last_frame:
		_last_frame = frame
		queue_redraw()


func _draw() -> void:
	if _rows == 0:
		return
	var height := _rows * ROW_STEP + 22.0
	var top := CENTER_Y - height * 0.5
	for left in [0.0, RIGHT_EDGE - WING_WIDTH]:
		_draw_wing(Rect2(left, top, WING_WIDTH, height))
	var taken := int(_shown)
	for i in _slots.size():
		var foot := _slots[i]
		draw_rect(Rect2(foot.x - 12, foot.y - 1, 24, 5), Color("70523a"))
		draw_rect(Rect2(foot.x - 12, foot.y - 1, 24, 2), Color("dfb373"))
	for i in _slots.size():
		if _rank[i] < taken:
			_draw_spectator(i)


func _draw_wing(area: Rect2) -> void:
	draw_rect(area.grow(2), Color("344b43"))
	draw_rect(area, Color("654b39"))
	draw_rect(area.grow(-3), Color("aa7c49"))
	for plank in range(int(area.size.y / 16.0)):
		draw_rect(Rect2(area.position.x + 3, area.position.y + 8 + plank * 16, area.size.x - 6, 2), Color("805d3e"))


func _draw_spectator(i: int) -> void:
	var style := _style[i]
	var bounce := maxf(0.0, sin(_clock * 8.0 + _phase[i])) * minf(_cheer, 1.0) * 5.0
	var foot := _slots[i] - Vector2(0, bounce)
	var frame := (int(_clock * 6.0) + i) % 9
	var source := Rect2(frame * FRAME.x + CROP.position.x, CROP.position.y, CROP.size.x, CROP.size.y)
	var size := CROP.size * SCALE
	var flip := i >= _slots.size() / 2  # the right wing faces the ring
	draw_set_transform(Vector2(foot.x, 0.0), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var area := Rect2(Vector2(-size.x * 0.5, foot.y - FOOT_IN_CROP.y * SCALE), size)
	draw_texture_rect_region(BASE, area, source, SKIN_COLORS[style % 4])
	draw_texture_rect_region(HAIRS[style / 16], area, source, HAIR_COLORS[(style / 4) % 4])
