extends Node2D
## One fighter in the pit: a layered Sunnyside actor with a shadow, name and HP bar.
## Presentation only. The arena reports what happened; nothing here decides outcomes.

const FONT := preload("res://fonts/PeaberryBase.ttf")
const BLUE_TINT := Color(0.72, 0.86, 1.0)
const RED_TINT := Color(1.0, 0.66, 0.62)
const DEAD_TINT := Color(0.5, 0.5, 0.56)
const HIT_FLASH := Color(1.7, 0.8, 0.7)
const HEAL_FLASH := Color(0.7, 1.6, 0.9)
const BAR_SIZE := Vector2(32, 4)
const BAR_Y := -60.0
const WALK_ABOVE := 8.0  # sim units per second
const RUN_ABOVE := 160.0  # dashes; a normal walk is 75-90

var hero_name := ""
var red := false
var max_hp := 1
var hp := 1
var dead := false
var show_bar := false
var celebrating := false
var name_left := INF  ## seconds the name stays visible (INF = always)
var _tint := BLUE_TINT
var _busy := false  # a one-shot clip (attack, hurt) is playing
var _flash: Tween
@onready var _actor: Node2D = $Actor


func setup(id: int, unit: StringName, is_red: bool, display_name: String, health: int) -> void:
	red = is_red
	hero_name = display_name
	max_hp = maxi(1, health)
	hp = max_hp
	_tint = RED_TINT if is_red else BLUE_TINT
	_actor.setup(id, String(unit), is_red)
	_actor.modulate = _tint
	_actor.animation_finished.connect(_on_clip_finished)


func _process(delta: float) -> void:
	if is_finite(name_left) and name_left > 0.0:
		name_left -= delta
		if name_left <= 0.0:
			queue_redraw()


## Places the fighter and picks idle / walk / run from its speed. `look_dx` is where it faces.
func move(pos: Vector2, speed: float, look_dx: float) -> void:
	position = pos
	if dead or _busy:
		return
	if absf(look_dx) > 1.0:
		_actor.flip_h = look_dx < 0.0
	var clip := &"idle" if speed < WALK_ABOVE else (&"walk" if speed < RUN_ABOVE else &"run")
	if _actor.animation != clip:
		_actor.play(clip)


func attack(toward_dx: float) -> void:
	if dead:
		return
	if absf(toward_dx) > 1.0:
		_actor.flip_h = toward_dx < 0.0
	_busy = true
	_actor.play(&"attack")


func take_hit(damage: int) -> void:
	hp = maxi(0, hp - damage)
	queue_redraw()
	if hp > 0:
		_flash_to(HIT_FLASH, _tint)
		_busy = true
		_actor.play(&"hurt")
		return
	dead = true
	_actor.play(&"death")
	_flash_to(HIT_FLASH, DEAD_TINT)


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	queue_redraw()
	_flash_to(HEAL_FLASH, _tint)


## Winner emote: keep swinging until the arena resets the pit.
func celebrate() -> void:
	if dead:
		return
	celebrating = true
	name_left = INF
	queue_redraw()
	_busy = true
	_actor.play(&"attack")


func _flash_to(flash: Color, rest: Color) -> void:
	if _flash:
		_flash.kill()
	_actor.modulate = flash
	_flash = create_tween()
	_flash.tween_property(_actor, "modulate", rest, 0.4)


func _on_clip_finished() -> void:
	if dead:
		return
	_busy = celebrating
	_actor.play(&"attack" if celebrating else &"idle")


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead:
		return
	if name_left > 0.0:
		_draw_name()
	if not show_bar:
		return
	var origin := Vector2(-BAR_SIZE.x * 0.5, BAR_Y)
	draw_rect(Rect2(origin - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), Color("0b1119"))
	var color := Color("e0685f") if red else Color("6cb8e8")
	draw_rect(Rect2(origin, Vector2(roundf(BAR_SIZE.x * hp / max_hp), BAR_SIZE.y)), color)


func _draw_name() -> void:
	var name_at := Vector2(-40, BAR_Y - 4 if show_bar else BAR_Y + 8)
	draw_string_outline(FONT, name_at, hero_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, 4, Color("18222f"))
	draw_string(FONT, name_at, hero_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color("edf1f7"))
