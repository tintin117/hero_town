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
const TEAM_RED := Color("e0685f")
const TEAM_BLUE := Color("6cb8e8")
const CROWN_GOLD := Color("f2c94c")
const DEAD_FADE_AFTER := 0.7  # a fallen fighter fades from here ...
const DEAD_LIFETIME := 1.2  # ... and is removed by the arena at this age
const NAME_TIME := 2.5  # names show when a bout starts, then only the bars remain
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
var home := Vector2.ZERO  ## idle spot the arena walks the fighter back to between bouts
var crowned := false  ## the series winner: gold ring and crown
var gone := false  ## a dead fighter that has faded out; the arena removes it
var _dead_time := 0.0
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


## Driven by the arena: name timeout and the fade-out of a fallen fighter.
func tick(delta: float) -> void:
	if is_finite(name_left) and name_left > 0.0:
		name_left -= delta
		if name_left <= 0.0:
			queue_redraw()
	if dead:
		_dead_time += delta
		modulate.a = clampf(1.0 - (_dead_time - DEAD_FADE_AFTER) / (DEAD_LIFETIME - DEAD_FADE_AFTER), 0.0, 1.0)
		gone = _dead_time >= DEAD_LIFETIME


func fade_in() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


## Back to a clean, living fighter for the next bout (or the idle pit).
func reset(health: int, bar: bool) -> void:
	max_hp = maxi(1, health)
	hp = max_hp
	dead = false
	gone = false
	_dead_time = 0.0
	modulate.a = 1.0
	crowned = false
	show_bar = bar
	name_left = NAME_TIME if bar else INF
	calm()
	_actor.modulate = _tint
	queue_redraw()


## Stops the victory swings and returns to the idle / walk clips.
func calm() -> void:
	celebrating = false
	if dead:
		return
	_busy = false
	_actor.play(&"idle")


func crown() -> void:
	crowned = true
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
	if dead:
		return
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


func team_color() -> Color:
	return TEAM_RED if red else TEAM_BLUE


func _draw() -> void:
	var ring := CROWN_GOLD if crowned else team_color()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.3))
	if not dead:  # team ring: red or blue floor disc, gold for the series winner
		draw_circle(Vector2.ZERO, 20.0, Color(ring, 0.34))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, ring, 4.0 if crowned else 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead:
		return
	if crowned:
		_draw_crown()
	if name_left > 0.0:
		_draw_name()
	if not show_bar:
		return
	var origin := Vector2(-BAR_SIZE.x * 0.5, BAR_Y)
	draw_rect(Rect2(origin - Vector2(2, 2), BAR_SIZE + Vector2(4, 4)), team_color())  # team-coloured frame
	draw_rect(Rect2(origin - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), Color("0b1119"))
	draw_rect(Rect2(origin, Vector2(roundf(BAR_SIZE.x * hp / max_hp), BAR_SIZE.y)), team_color().lightened(0.1))


func _draw_name() -> void:
	var name_at := Vector2(-40, BAR_Y - 6 if show_bar else BAR_Y + 8)
	var width := FONT.get_string_size(hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(FONT, name_at, hero_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, 4, Color("18222f"))
	draw_string(FONT, name_at, hero_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, team_color().lightened(0.55))
	draw_rect(Rect2(-width * 0.5 - 1, name_at.y + 3, width + 2, 3), Color("18222f"))  # name plate underline
	draw_rect(Rect2(-width * 0.5, name_at.y + 4, width, 2), team_color())


func _draw_crown() -> void:
	var base := Vector2(0, BAR_Y - (24.0 if show_bar or name_left > 0.0 else 4.0))
	var points := PackedVector2Array([Vector2(-9, 0), Vector2(-9, -9), Vector2(-4, -4), Vector2(0, -12), Vector2(4, -4), Vector2(9, -9), Vector2(9, 0)])
	for i in points.size():
		points[i] = points[i] * 1.4 + base
	draw_colored_polygon(points, CROWN_GOLD)
	draw_polyline(points + PackedVector2Array([points[0]]), Color("8a5a12"), 1.0)
	draw_rect(Rect2(base + Vector2(-12.6, -4.2), Vector2(25.2, 4.2)), Color("e28f2a"))
