extends Node2D
## The ringside bar prop: a small awning stall beside the ring with bubbling drinks. When the
## concessions are paid (a bout settled) coins float up from it. Hidden unless the prop is active.

const SIZE := Vector2(48, 30)
const MAX_COINS := 8
const COIN_LIFE := 1.3

var _clock := 0.0
var _coins: Array[Dictionary] = []  # {x, age}


func _ready() -> void:
	hide()


func is_running() -> bool:
	return visible


func start() -> void:
	_clock = 0.0
	_coins.clear()
	show()


func stop() -> void:
	_coins.clear()
	hide()


## `amount` = gold paid; a handful of coins float up, more for a bigger payout.
func pay(amount: int) -> void:
	for i in clampi(2 + amount / 20, 2, MAX_COINS):
		_coins.append({"x": randf_range(-14.0, 14.0), "age": -i * 0.12})


func tick(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	for coin in _coins:
		coin.age += delta
	_coins = _coins.filter(func(coin: Dictionary) -> bool: return coin.age < COIN_LIFE)
	queue_redraw()


func _draw() -> void:
	# counter and posts
	draw_rect(Rect2(-22, -8, 44, 16), Color("654b39"))
	draw_rect(Rect2(-22, -8, 44, 4), Color("dfb373"))
	draw_rect(Rect2(-22, -24, 3, 16), Color("805d3e"))
	draw_rect(Rect2(19, -24, 3, 16), Color("805d3e"))
	# striped awning
	for i in 8:
		draw_rect(Rect2(-24 + i * 6, -32, 6, 9), Color("e0685f") if i % 2 == 0 else Color("fff0cf"))
	draw_rect(Rect2(-24, -24, 48, 2), Color("59685f"))
	# mugs with foam and bubbles
	for i in 3:
		var mug := Vector2(-12 + i * 12, -8)
		draw_rect(Rect2(mug + Vector2(-3, -7), Vector2(6, 7)), Color("f2c771"))
		draw_rect(Rect2(mug + Vector2(-3, -9), Vector2(6, 2)), Color.WHITE)
		var rise := fposmod(_clock * 0.9 + i * 0.37, 1.0)
		draw_circle(mug + Vector2(sin(_clock * 3.0 + i) * 2.0, -10.0 - rise * 9.0), 1.5, Color(1, 1, 1, 1.0 - rise))
	for coin in _coins:
		if coin.age < 0.0:
			continue
		var t: float = coin.age / COIN_LIFE
		var at := Vector2(coin.x, -30.0 - t * 30.0)
		draw_circle(at, 4.0, Color("18222f", 1.0 - t))
		draw_circle(at, 3.0, Color("f2c771", 1.0 - t))
		draw_rect(Rect2(at + Vector2(-1, -2), Vector2(1, 3)), Color(1, 1, 0.8, 1.0 - t))
