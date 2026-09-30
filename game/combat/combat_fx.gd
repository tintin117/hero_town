extends Node2D
## Floating numbers, hit sparks, skill flourishes and dust. Knows nothing about fights:
## the arena calls these with positions already in its own pixel space.

const IMPACT := preload("res://vfx/effects/impact/impact_spark.tscn")
const BURST := preload("res://vfx/effects/impact/hit_burst.tscn")
const SMOKE := preload("res://vfx/effects/utility/smoke_pop.tscn")
const SPARKLE := preload("res://vfx/effects/ui/pickup_sparkle.tscn")
const SHOCKWAVE := preload("res://vfx/effects/impact/shockwave.tscn")
const FONT := preload("res://fonts/PeaberryBase.ttf")
const DUST := preload("res://resources/effects/death_dust.tres")
const GOLD := Color("f2c771")
const CREAM := Color("fff0cf")
const GREEN := Color("8cf5b6")
const RED := Color("f4768c")
const RING_TIME := 0.55
const MAX_POPUPS := 10
const LIFT := Vector2(0, -23)  # feet to chest

## Floating text is kept inside this rectangle so it never lands on the HUD above the arena.
var bounds := Rect2(0, 0, 512, 256)
var _rings: Array[Dictionary] = []
var _popups: Array = []  # live floating Labels (untyped: freed ones must be filtered out)


func clear() -> void:
	_rings.clear()
	_popups.clear()
	for child in get_children():
		child.queue_free()
	queue_redraw()


## Floating text. Popups never stack on each other (each takes the first free spot around `at`)
## and at most MAX_POPUPS live at once; `life` is how long it floats.
func text(value: String, at: Vector2, color: Color, font_size := 16, life := 0.9) -> void:
	_popups = _popups.filter(func(popup: Variant) -> bool: return is_instance_valid(popup) and not popup.is_queued_for_deletion())
	while _popups.size() >= MAX_POPUPS:
		_popups.pop_front().queue_free()
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("18222f"))
	label.add_theme_constant_override("outline_size", 4)
	var size := label.get_minimum_size()
	label.position = _free_spot(Vector2(at.x - size.x * 0.5, at.y), size)
	add_child(label)
	_popups.append(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 22.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tween.chain().tween_callback(label.queue_free)


func _free_spot(start: Vector2, size: Vector2) -> Vector2:
	var spot := start
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, -1.1), Vector2(1.1, 0), Vector2(-1.1, 0), Vector2(1.1, -1.1), Vector2(-1.1, -1.1), Vector2(0, -2.2), Vector2(2.2, 0), Vector2(-2.2, 0)]:
		spot = start + offset * size
		spot.x = clampf(spot.x, bounds.position.x, bounds.end.x - size.x)
		spot.y = clampf(spot.y, bounds.position.y + 4.0, bounds.end.y - size.y)
		var rect := Rect2(spot, size).grow(1.0)
		if not _popups.any(func(popup: Label) -> bool: return rect.intersects(Rect2(popup.position, popup.get_minimum_size()))):
			break
	return spot


func hit(at: Vector2, big: bool) -> void:
	_spawn(IMPACT, at + LIFT, 0.36 if big else 0.18, GOLD if big else CREAM, {"streak_count": 8 if big else 4})


func firework(at: Vector2, color: Color) -> void:
	_spawn(IMPACT, at, 0.9, color, {"star_points": 8, "streak_count": 18})
	_spawn(SPARKLE, at, 1.2, color, {"star_count": 8})


func sparkle(at: Vector2) -> void:
	_spawn(SPARKLE, at + LIFT, 1.0, GOLD, {"star_count": 7})


func dust(at: Vector2) -> void:
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = DUST
	puff.position = at
	puff.scale = Vector2(1.5, 1.5)
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(puff)
	puff.play(&"dust")
	puff.animation_finished.connect(puff.queue_free)


## Skill flourish by kind (strike / sweep / heal / drain). `radii` is the sweep ellipse in pixels.
func skill(kind: String, from: Vector2, to: Vector2, radii: Vector2) -> void:
	match kind:
		"strike":
			_spawn(BURST, to + LIFT, 0.5, GOLD, {"chunk_count": 12, "smoke_count": 4})
			_spawn(SHOCKWAVE, to, 0.65, GOLD, {"max_radius_px": 50, "squash": 0.5})
		"sweep":
			_rings.append({"at": from, "radii": radii, "age": 0.0})
			_spawn(SHOCKWAVE, from, 1.0, GOLD, {"max_radius_px": roundi(radii.x), "squash": radii.y / radii.x})
		"heal":
			_spawn(SPARKLE, from + LIFT, 1.0, GREEN, {"star_count": 7})
			_spawn(SHOCKWAVE, from, 0.7, GREEN, {"max_radius_px": 50, "squash": 0.4})
		"drain":
			_spawn(SPARKLE, from + LIFT, 0.8, RED, {"star_count": 5})
			_spawn(BURST, to + LIFT, 0.25, RED, {"chunk_count": 6, "smoke_count": 0})


func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	for ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring.age < RING_TIME)
	queue_redraw()


func _draw() -> void:
	for ring in _rings:
		var progress: float = ring.age / RING_TIME
		var radii: Vector2 = ring.radii
		draw_set_transform(ring.at, 0.0, Vector2(1.0, radii.y / radii.x))
		var radius := radii.x * (0.3 + 0.7 * progress)
		draw_circle(Vector2.ZERO, radius, Color(GOLD, 0.16 * (1.0 - progress)))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(CREAM, 1.0 - progress), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _spawn(scene: PackedScene, at: Vector2, effect_size: float, color: Color, settings := {}) -> void:
	var effect: FxEffect = scene.instantiate()
	effect.position = at
	effect.size = effect_size
	effect.speed = 1.2
	effect.color_main = color
	effect.color_accent = color.darkened(0.3)
	for key in settings:
		effect.set(key, settings[key])
	add_child(effect)
