extends Node
## Presentation only: combat events already contain resolved damage and money.

const IMPACT := preload("res://vfx/effects/impact/impact_spark.tscn")
const BURST := preload("res://vfx/effects/impact/hit_burst.tscn")
const SMOKE := preload("res://vfx/effects/utility/smoke_pop.tscn")
const SPARKLE := preload("res://vfx/effects/ui/pickup_sparkle.tscn")
const SHOCKWAVE := preload("res://vfx/effects/impact/shockwave.tscn")
const FLASH := preload("res://vfx/effects/impact/hit_flash.tscn")
const GOLD := Color("f2c771")
const CREAM := Color("fff0cf")
const GREEN := Color("8cf5b6")
const RED := Color("f4768c")
const SKILL_COLORS := [GOLD, Color("ffe6a0"), Color("8ee5ff"), GREEN, RED]
const SKILL_ROLES := [0, 1, 2, 3, 4, 1, 2, 3]
const SKILL_DURATION := 0.85

var ui: Control
var world := Node2D.new()
var sky := Node2D.new()
var hud := Control.new()
var toast: Label
var toast_tween: Tween
var coin_pulse: Tween
var effects: Array[Dictionary] = []
var fireworks: Array[Dictionary] = []
var gains: Array[Dictionary] = []
var tip_total := 0
var last_tip := -INF
var burst_until := -INF
var pending_celebration := 0
var clock := 0.0


func setup(owner_ui: Control) -> void:
	ui = owner_ui
	world.name = "CombatEffects"
	world.z_index = 700
	sky.name = "Fireworks"
	sky.show_behind_parent = true
	ui.get_node("%Stage").add_child(sky)
	ui.get_node("%Stage").add_child(world)
	world.draw.connect(_draw_actions)
	sky.draw.connect(_draw_fireworks)
	hud.name = "CrowdFeedback"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud_parent := ui.get_node("%Bank").get_parent()
	hud_parent.add_child(hud)
	# Keep buttons and management drawers above these non-interactive overlays.
	hud_parent.move_child(hud, 0)
	toast = _label("", 18, GOLD)
	toast.name = "CrowdTip"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.anchor_left = 1.0
	toast.anchor_right = 1.0
	toast.offset_left = -264
	toast.offset_right = -18
	toast.offset_top = 92
	toast.offset_bottom = 118
	hud.add_child(toast)
	toast.hide()


func reset() -> void:
	effects.clear()
	fireworks.clear()
	gains.clear()
	pending_celebration = 0
	tip_total = 0
	last_tip = -INF
	burst_until = -INF
	for tween in [toast_tween, coin_pulse]:
		if tween and tween.is_valid():
			tween.kill()
	toast.hide()
	toast.modulate = Color.WHITE
	for layer in [world, sky, hud]:
		for child in layer.get_children():
			if child != toast:
				layer.remove_child(child)
				child.queue_free()
	ui.get_node("%Coins").scale = Vector2.ONE
	ui.get_node("%Coins").modulate = Color.WHITE
	world.queue_redraw()
	sky.queue_redraw()


func present(event: Dictionary) -> void:
	var caster: int = event.attacker
	if event.kind == "move":
		effects.append({"event": event, "age": 0.0, "duration": 0.4,
			"trail": true})
		for index in range(3):
			var ghost: Node2D = ui.fighters[caster].sprite.capture_afterimage()
			ghost.position = ui._project(event.origin.lerp(event.destination, index * 0.12))
			ghost.modulate = Color(0.85, 0.95, 1.0, 0.28 - index * 0.05)
			world.add_child(ghost)
			var tween := ghost.create_tween()
			tween.tween_property(ghost, "modulate:a", 0.0, 0.35)
			tween.tween_callback(ghost.queue_free)
		_spawn(SMOKE, ui._project(event.origin), 0.25, Color("d7bc86"), {"puff_count": 4})
		return
	var skill: bool = event.kind == "skill"
	var origin: Vector2 = ui._project(event.origin)
	effects.append({"event": event, "age": 0.0, "duration": SKILL_DURATION if skill else 0.45})
	for hit in event.hits:
		var target: Vector2 = ui._project(hit.position)
		_number(str(hit.damage), target - Vector2(0, 42), 22 if skill else 16, GOLD if skill else CREAM, "damage")
		_spawn(IMPACT, target - Vector2(0, 23), 0.36 if skill else 0.18, GOLD if skill else CREAM, {"streak_count": 8 if skill else 4})
		_recoil(hit.target, (target - origin).normalized(), skill)
		if hit.has("push_to"):
			_spawn(SMOKE, target, 0.18, Color("d7bc86"), {"puff_count": 3})
	if event.healing > 0:
		_number("+%d" % event.healing, origin - Vector2(0, 48), 20, GREEN, "healing")
	if not skill:
		return
	_number(ui.fight.heroes[caster].skill.name, origin - Vector2(0, 76), 13, GOLD, "skill_name")
	_show_tip(event.tip)
	_spawn(FLASH, origin - Vector2(0, 23), 0.65, SKILL_COLORS[SKILL_ROLES[caster]])
	match SKILL_ROLES[caster]:
		0:
			var target: Vector2 = ui._project(event.hits[0].position)
			_spawn(BURST, target - Vector2(0, 18), 0.5, GOLD, {"chunk_count": 12, "smoke_count": 4})
			_spawn(SMOKE, target, 0.4, Color("c3a879"), {"puff_count": 6})
			_spawn(SHOCKWAVE, target, 0.65, GOLD, {"max_radius_px": 64, "squash": ui.GROUND_DEPTH})
		1:
			var radius: float = ui._project(event.origin + Vector2(event.radius, 0)).x - origin.x
			_spawn(SHOCKWAVE, origin, 1.0, GOLD, {"max_radius_px": roundi(radius), "squash": ui.GROUND_DEPTH})
			for index in range(4):
				var edge: Vector2 = ui._project(event.origin + Vector2.from_angle(index * TAU / 4) * event.radius)
				_spawn(SMOKE, edge, 0.18, Color("d7bc86"), {"puff_count": 3})
		2:
			_spawn(IMPACT, ui._project(event.hits[0].position) - Vector2(0, 23), 0.6, SKILL_COLORS[SKILL_ROLES[caster]], {"star_points": 6, "streak_count": 14})
			_spawn(SPARKLE, origin - Vector2(0, 23), 0.55, SKILL_COLORS[SKILL_ROLES[caster]], {"star_count": 3})
		3:
			_spawn(SPARKLE, origin - Vector2(0, 22), 1.0, GREEN, {"star_count": 7})
			_spawn(SHOCKWAVE, origin, 0.7, GREEN, {"max_radius_px": 70, "squash": 0.32})
		4:
			_spawn(SPARKLE, origin - Vector2(0, 22), 0.8, RED, {"star_count": 5})
			_spawn(BURST, ui._project(event.hits[0].position) - Vector2(0, 23), 0.25, RED, {"chunk_count": 6, "smoke_count": 0})
	if event.excitement_gain > 0.0:
		gains.append({"time": event.time, "amount": event.excitement_gain})
		gains = gains.filter(func(gain: Dictionary): return event.time - gain.time <= 2.0)
		var total := 0.0
		for gain in gains:
			total += gain.amount
		if total >= 16.0 and event.time >= burst_until:
			pending_celebration = maxi(pending_celebration, 1)
			burst_until = event.time + 4.0


func tier_crossed(tier: int) -> void:
	pending_celebration = maxi(pending_celebration, tier + 1)


func flush_celebration() -> void:
	if pending_celebration == 0:
		return
	ui.cheer = 1.0
	# One burst per simulation update, even when a rapid sequence crosses a tier.
	fireworks.append({"age": 0.0, "strength": pending_celebration})
	pending_celebration = 0


func _spawn(scene: PackedScene, at: Vector2, scale_amount: float, color: Color, settings: Dictionary = {}) -> void:
	var effect = scene.instantiate()
	effect.position = at
	effect.size = scale_amount
	effect.speed = 1.2
	effect.color_main = color
	effect.color_accent = color.darkened(0.3)
	for key in settings:
		effect.set(key, settings[key])
	world.add_child(effect)


func _recoil(id: int, direction: Vector2, skill: bool) -> void:
	var sprite: Node2D = ui.fighters[id].sprite
	var old: Tween = sprite.get_meta("recoil") if sprite.has_meta("recoil") else null
	if old and old.is_valid():
		old.kill()
	sprite.position = direction * (7.0 if skill else 3.5)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sprite.set_meta("recoil", tween)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("18222f"))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _number(text: String, at: Vector2, font_size: int, color: Color, kind: String) -> void:
	var label := _label(text, font_size, color)
	label.set_meta("feedback_kind", kind)
	label.z_index = 300
	label.size = Vector2(ceilf(label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 8, 26)
	var base := at - label.size * 0.5
	var top: float = ui.get_node("%Bank").get_global_rect().end.y + 38 - world.global_position.y
	var width: float = ui.get_node("%Stage").size.x
	# Fan nearby numbers sideways before stacking them above the HUD boundary.
	for slot in range(25):
		var column := ceili(float(slot) / 3.0) * (1 if slot % 2 == 0 else -1)
		label.position = Vector2(clampf(base.x + column * 30, 0, width - label.size.x), maxf(top, base.y - (slot % 3) * 26))
		var overlaps := false
		for other in world.get_children():
			if other is Label and Rect2(label.position, label.size).intersects(Rect2(other.position, other.size)):
				overlaps = true
				break
		if not overlaps:
			break
	world.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)


func _show_tip(amount: int) -> void:
	tip_total = tip_total + amount if clock - last_tip <= 0.25 else amount
	last_tip = clock
	toast.text = "Crowd tips +%d" % tip_total
	toast.show()
	toast.modulate = Color.WHITE
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = toast.create_tween()
	toast_tween.tween_interval(0.75)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	toast_tween.tween_callback(toast.hide)
	var bank: Label = ui.get_node("%Coins")
	for i in range(3):
		var coin := _label("●", 12, GOLD)
		coin.position = toast.position + Vector2(155 + i * 9, 10)
		hud.add_child(coin)
		var start := coin.position
		var target := hud.get_global_transform().affine_inverse() * bank.get_global_rect().get_center()
		var tween := coin.create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_method(func(progress: float): coin.position = start.lerp(target, progress) - Vector2(0, sin(progress * PI) * 28), 0.0, 1.0, 0.55)
		tween.tween_callback(coin.queue_free)
	if coin_pulse and coin_pulse.is_valid():
		coin_pulse.kill()
	bank.pivot_offset = bank.size * Vector2(0, 0.5)
	bank.scale = Vector2.ONE * 1.12
	bank.modulate = Color(1.5, 1.3, 1.0)
	coin_pulse = bank.create_tween().set_parallel(true)
	coin_pulse.tween_property(bank, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_pulse.tween_property(bank, "modulate", Color.WHITE, 0.4)


func _process(delta: float) -> void:
	clock += delta
	for effect in effects:
		effect.age += delta
	for firework in fireworks:
		firework.age += delta
	effects = effects.filter(func(effect: Dictionary): return effect.age < effect.duration)
	fireworks = fireworks.filter(func(firework: Dictionary): return firework.age < 1.2)
	world.queue_redraw()
	sky.queue_redraw()


func _draw_actions() -> void:
	for effect in effects:
		var event: Dictionary = effect.event
		if event.kind == "move":
			_draw_dash(effect)
			continue
		var progress: float = effect.age / effect.duration
		var alpha := 1.0 - progress
		var origin: Vector2 = ui._project(event.origin)
		if event.kind == "skill":
			_draw_skill(event, progress)
			continue
		for hit in event.hits:
			var start := origin - Vector2(0, 23)
			var target: Vector2 = ui._project(hit.position) - Vector2(0, 23)
			if ui.fight.heroes[event.attacker].ranged:
				world.draw_line(start, target, Color("b9eaff", alpha), 1.5, true)
				world.draw_line(start, target, Color(CREAM, alpha), 1.0, true)
			else:
				var direction := (target - start).angle()
				world.draw_arc(target, 12, direction - 1.8 + progress, direction + 0.7 + progress, 18, Color(CREAM, alpha), 2.0, true)


func _draw_dash(effect: Dictionary) -> void:
	var event: Dictionary = effect.event
	var progress: float = minf(1.0, effect.age / event.duration)
	var alpha: float = 1.0 - effect.age / effect.duration
	var color := Color("8ee5ff") if event.move_kind == "escape" else GOLD
	var start: Vector2 = ui._project(event.origin) - Vector2(0, 23)
	var destination: Vector2 = ui._project(event.destination) - Vector2(0, 23)
	var head := start.lerp(destination, progress)
	var side := (destination - start).normalized().orthogonal()
	for index in range(3):
		var at := start.lerp(destination, maxf(0.0, progress - 0.16 * (index + 1)))
		var offset := side * (index - 1) * 5
		world.draw_line(at + offset, head + offset, Color(color, alpha * 0.7), 1.5, true)


func _draw_skill(event: Dictionary, progress: float) -> void:
	var alpha := 1.0 - progress
	var origin: Vector2 = ui._project(event.origin)
	var start := origin - Vector2(0, 23)
	var color: Color = SKILL_COLORS[SKILL_ROLES[event.attacker]]
	# A brief floor pulse makes the caster readable without covering HP or numbers.
	world.draw_polyline(ui._circle_points(event.origin, 24 + progress * 28), Color(color, alpha * 0.65), 2.0, true)
	match SKILL_ROLES[event.attacker]:
		0:
			var target: Vector2 = ui._project(event.hits[0].position) - Vector2(0, 23)
			var direction := (target - start).angle() + progress * 1.4
			for ribbon in range(3):
				world.draw_arc(target, 26 + ribbon * 7 + progress * 12, direction - 2.2, direction + 0.7, 28, Color(color, alpha * (1.0 - ribbon * 0.25)), 7 - ribbon * 2, true)
			world.draw_line(target - Vector2(16, 26) * alpha, target + Vector2(16, 26) * alpha, Color(CREAM, alpha), 3.0, true)
		1:
			var area: PackedVector2Array = ui._circle_points(event.origin, event.radius)
			world.draw_colored_polygon(area.slice(0, 64), Color(color, alpha * 0.12))
			world.draw_polyline(area, Color(color, alpha), 2.0, true)
			for ribbon in range(3):
				var arc := PackedVector2Array()
				for index in range(24):
					var angle := progress * TAU * 1.5 + ribbon * TAU / 3 + index * 0.075
					arc.append(ui._project(event.origin + Vector2.from_angle(angle) * (event.radius - ribbon * 8)))
				world.draw_polyline(arc, Color(CREAM if ribbon == 0 else color, alpha), 5 - ribbon, true)
		2:
			var target: Vector2 = ui._project(event.hits[0].position) - Vector2(0, 23)
			var side := (target - start).normalized().orthogonal()
			world.draw_line(start, target, Color(color, alpha * 0.18), 16 * alpha + 2, true)
			world.draw_line(start, target, Color(color, alpha), 5 * alpha + 1, true)
			world.draw_line(start, target, Color(CREAM, alpha), 2.0, true)
			for sign_value in [-1, 1]:
				world.draw_line(start + side * 10 * alpha, target + side * 3 * alpha, Color(color, alpha * 0.5), 1.5, true)
			world.draw_arc(target, 10 + progress * 24, 0, TAU, 24, Color(color, alpha), 2.0, true)
		3:
			for ring in range(2):
				var rise := fmod(progress + ring * 0.35, 1.0)
				var points: PackedVector2Array = ui._circle_points(event.origin, 28 + rise * 22)
				for index in range(points.size()):
					points[index].y -= rise * 48
				world.draw_polyline(points, Color(GREEN, alpha * (1.0 - rise)), 3.0, true)
			for mote in range(7):
				var at := origin + Vector2(sin(mote * 2.4) * 28, -8 - fmod(progress + mote * 0.13, 1.0) * 54)
				world.draw_line(at - Vector2(3, 0), at + Vector2(3, 0), Color(GREEN, alpha), 2.0)
				world.draw_line(at - Vector2(0, 3), at + Vector2(0, 3), Color(GREEN, alpha), 2.0)
		4:
			var target: Vector2 = ui._project(event.hits[0].position) - Vector2(0, 23)
			var side := (start - target).normalized().orthogonal()
			for sign_value in [-1, 1]:
				var ribbon := PackedVector2Array()
				for index in range(25):
					var along := index / 24.0
					ribbon.append(target.lerp(start, along) + side * sin(along * PI) * 18 * sign_value)
				world.draw_polyline(ribbon, Color(RED, alpha * 0.25), 8.0, true)
				world.draw_polyline(ribbon, Color(RED, alpha), 2.0, true)
				for mote in range(4):
					var along := fmod(progress * 1.6 + mote * 0.25, 1.0)
					var at: Vector2 = target.lerp(start, along) + side * sin(along * PI) * 18 * sign_value
					world.draw_circle(at, 3.0, Color(CREAM.lerp(RED, 0.6), alpha))
			if event.healing > 0:
				world.draw_arc(start, 15 + progress * 14, 0, TAU, 24, Color(GREEN, alpha * minf(1.0, progress * 4)), 2.0, true)


func _draw_fireworks() -> void:
	# Behind the stands, using deterministic spokes rather than combat RNG.
	for firework in fireworks:
		var progress: float = firework.age / 1.2
		var count: int = firework.strength
		for burst in range(count):
			var base: Vector2 = ui._project(Vector2((burst - (count - 1) * 0.5) * 160, -340)) - Vector2(0, 28)
			var color: Color = [GOLD, Color("9edfff"), Color("ffa0a0")][burst % 3]
			for ray in range(14):
				var direction := Vector2.from_angle(TAU * ray / 14.0 + burst * 0.2)
				var reach := 10.0 + sin(progress * PI * 0.5) * (25 + count * 5)
				var end := base + direction * reach + Vector2(0, progress * progress * 22)
				sky.draw_line(end - direction * 5, end, Color(color, 1.0 - progress), 2.0, true)
