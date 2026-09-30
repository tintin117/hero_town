extends Node2D
## Series props drawn over the pit: fireworks (rockets that pop into vfx bursts above the arena),
## two sweeping spotlights, and the announcer's pulsing megaphone. `start(prop, fx)` at the bell,
## `stop()` when the series ends, `tick(delta)` from the arena. The ringside bar is its own node.

const CENTER := Vector2(256, 140)
const RING := Vector2(150, 84)
const LAMPS := [Vector2(110, -30), Vector2(402, -30)]
const MEGAPHONE_AT := Vector2(132, 62)
const FIREWORK_COLORS := [Color("f2c771"), Color("8cf5b6"), Color("f4768c"), Color("8ee5ff"), Color("ffe6a0")]
const LAUNCH_GAP := Vector2(0.7, 1.5)  # seconds between rockets (min, max)
const RISE_TIME := 0.55

var prop := &""
var _fx: Node2D
var _clock := 0.0
var _next_launch := 0.0
var _rockets: Array[Dictionary] = []  # {from, to, age, color}
var _rng := RandomNumberGenerator.new()


func is_running() -> bool:
	return prop != &""


func start(new_prop: StringName, fx: Node2D) -> void:
	stop()
	prop = new_prop
	_fx = fx
	_clock = 0.0
	_next_launch = 0.0
	queue_redraw()


func stop() -> void:
	prop = &""
	_rockets.clear()
	queue_redraw()


func tick(delta: float) -> void:
	if prop == &"":
		return
	_clock += delta
	if prop == &"fireworks":
		_tick_fireworks(delta)
	queue_redraw()


func _tick_fireworks(delta: float) -> void:
	_next_launch -= delta
	if _next_launch <= 0.0:
		_next_launch = _rng.randf_range(LAUNCH_GAP.x, LAUNCH_GAP.y)
		var x := _rng.randf_range(90.0, 420.0)
		_rockets.append({"from": Vector2(x + _rng.randf_range(-20.0, 20.0), 64.0), "to": Vector2(x, _rng.randf_range(-42.0, 8.0)),
			"age": 0.0, "color": FIREWORK_COLORS[_rng.randi() % FIREWORK_COLORS.size()]})
	for rocket in _rockets:
		rocket.age += delta
		if rocket.age >= RISE_TIME and _fx != null:
			_fx.firework(rocket.to, rocket.color)
	_rockets = _rockets.filter(func(rocket: Dictionary) -> bool: return rocket.age < RISE_TIME)


func _draw() -> void:
	match prop:
		&"fireworks":
			for rocket in _rockets:
				var head: Vector2 = rocket.from.lerp(rocket.to, rocket.age / RISE_TIME)
				var tail: Vector2 = rocket.from.lerp(rocket.to, maxf(0.0, rocket.age / RISE_TIME - 0.25))
				draw_line(tail, head, Color(rocket.color, 0.55), 2.0)
				draw_rect(Rect2(head - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
		&"spotlights":
			for i in LAMPS.size():
				_draw_beam(LAMPS[i], i)
		&"announcer":
			_draw_megaphone()


## One lamp on a mast sweeping its light spot across the sand.
func _draw_beam(lamp: Vector2, index: int) -> void:
	var sweep := _clock * (0.9 + index * 0.25) + index * PI
	var spot := CENTER + Vector2(sin(sweep) * RING.x * 0.75, cos(sweep * 0.7) * RING.y * 0.55)
	draw_colored_polygon(PackedVector2Array([lamp + Vector2(-4, 0), lamp + Vector2(4, 0), spot + Vector2(34, 0), spot + Vector2(-34, 0)]), Color(1.0, 0.95, 0.75, 0.13))
	draw_set_transform(spot, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.95, 0.75, 0.2))
	draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.97, 0.85, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(lamp + Vector2(-6, -4), Vector2(12, 8)), Color("344b43"))
	draw_rect(Rect2(lamp + Vector2(-4, 2), Vector2(8, 3)), Color("fff0cf"))


## Megaphone with sound arcs that pulse.
func _draw_megaphone() -> void:
	var beat := 0.5 + 0.5 * sin(_clock * 7.0)
	draw_set_transform(MEGAPHONE_AT, -0.35, Vector2.ONE * (1.5 + beat * 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(4, -9), Vector2(4, 9), Vector2(-8, 3)]), Color("e0685f"))
	draw_rect(Rect2(-13, -4, 6, 8), Color("59685f"))
	draw_rect(Rect2(4, -10, 3, 20), Color("fff0cf"))
	for ring in 2:
		draw_arc(Vector2(7, 0), 8.0 + ring * 6.0 + beat * 3.0, -0.7, 0.7, 8, Color("f2c771", (1.0 - beat) * 0.9 - ring * 0.25), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
