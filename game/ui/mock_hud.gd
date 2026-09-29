extends Control
## Arrangement reference for the real HUD: top bar (gold, fame, hype, seats), bottom bar (3 hero cards, Book,
## Roster/Build/Stories). Composed only from ui/components. The fake values below just make the widgets move.

@export var animate := true

var _hype := 42.0
var _t := 0.0

@onready var _hype_gauge: HypeGauge = $TopBar/Row/Hype
@onready var _gold: StatPill = $TopBar/Row/Gold
@onready var _excitement: ExcitementGauge = $Excitement


func _ready() -> void:
	var star: Array[Texture2D] = [load("res://resources/ui/icons/star.png"), load("res://resources/ui/icons/flame.png")]
	var mega: Array[Texture2D] = [load("res://resources/ui/icons/megaphone.png")]
	var fire: Array[Texture2D] = [load("res://resources/ui/icons/fireworks.png"), load("res://resources/ui/icons/spotlight.png")]
	$BottomBar/Row/Hero1.set_traits(star, PackedStringArray(["Showman", "Brawler"]))
	$BottomBar/Row/Hero2.set_traits(mega, PackedStringArray(["Crowd Pleaser"]))
	$BottomBar/Row/Hero3.set_traits(fire, PackedStringArray(["Underdog", "Grudge Holder"]))


func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	_hype += (100.0 - _hype) / 30.0 * delta * 4.0
	if _hype > 97.0:
		_hype = 12.0
		_gold.set_value(_gold.value + 238)
	_hype_gauge.set_value(_hype)
	var e := 50.0 + 45.0 * sin(_t * 0.5)
	_excitement.set_value(e)
	_excitement.set_multiplier("x2.5" if e >= 60 else ("x1.25" if e >= 25 else "x1"))


func _draw() -> void:
	# placeholder arena backdrop: grass, sand oval, stone ring
	draw_rect(Rect2(Vector2.ZERO, size), Color("7fae5a"))
	draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color("74a352"))
	var c := size / 2 + Vector2(0, 8)
	var r := Vector2(minf(size.x * 0.32, 380.0), minf(size.y * 0.3, 120.0))
	draw_set_transform(c, 0.0, Vector2(1, r.y / r.x))
	draw_circle(c * 0.0, r.x + 8, Color("8f8a86"))
	draw_circle(c * 0.0, r.x, Color("e2c88f"))
	draw_set_transform(Vector2.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
