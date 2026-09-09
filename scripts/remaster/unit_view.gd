class_name ArmyUnitView
extends Node2D

var model: Dictionary
var sprite: AnimatedSprite2D
var clock: float = 0.0
var _dead: bool = false
var flash_remaining: float = 0.0

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.unit_frames(model.visual, model.side == 1)
	var frame := sprite.sprite_frames.get_frame_texture("idle", 0)
	#sprite.offset.y = -frame.get_height() * 0.5
	sprite.scale = Vector2.ONE * (0.58 if not model.get("boss", "").is_empty() else 0.4)
	add_child(sprite)
	sprite.play("idle")
	position = model.position

func update_view(delta: float, battle_time: float) -> void:
	clock = battle_time
	flash_remaining = maxf(0.0, flash_remaining - delta)
	position = position.lerp(model.position, minf(1, delta * 24))
	z_index = int(position.y) + 200
	if model.hp <= 0:
		if not _dead:
			_dead = true
			sprite.stop()
			#sprite.rotation = -PI * 0.5
			#sprite.modulate = Color(0.65, 0.65, 0.7, 0.45 if model.side == 0 else 0.0)

			var dust := AnimatedSprite2D.new()
			var frames := SpriteFrames.new()
			frames.add_animation("dust")
			frames.set_animation_loop("dust", false)
			frames.set_animation_speed("dust", 10.0)

			var sheet: Texture2D = preload("res://asset/Tiny Swords (Free Pack)/Particle FX/Dust_02.png")
			var frame_count := 10
			var frame_width := sheet.get_width() / frame_count

			for i in range(frame_count):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(i * frame_width, 0, frame_width, sheet.get_height())
				frames.add_frame("dust", atlas)

			dust.sprite_frames = frames
			dust.animation = "dust"
			get_parent().add_child(dust)
			dust.global_position = global_position
			dust.scale = Vector2(0.5,0.5)
			dust.play("dust")
			var duration := frame_count / 10
			var tween := create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, duration)
			dust.animation_finished.connect(dust.queue_free)
	else:
		_dead = false
		sprite.rotation = 0
		sprite.modulate = Color(1.8, 1.8, 1.6) if flash_remaining > 0 else Color.WHITE
		var desired: String = model.get("action_name", "attack") if model.get("action_until", 0.0) > clock else ("run" if model.get("moving", false) else "idle")
		if sprite.animation != desired or not sprite.is_playing(): sprite.play(desired)
		sprite.flip_h = not model.get("facing_right", model.side == 0)
	queue_redraw()

func _draw() -> void:
	if model.is_empty() or model.hp <= 0: return
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 13, Color(0.06, 0.09, 0.13, 0.3))
	draw_arc(Vector2.ZERO, 14, 0, TAU, 24, TownRules.RARITY_COLORS[int(model.rarity)] if model.side == 0 else Color("c65954"), 2)
	draw_set_transform(Vector2.ZERO)
	if model.hp < model.max_hp:
		draw_rect(Rect2(-17, -44, 34, 4), Color("253241"))
		draw_rect(Rect2(-17, -44, 34 * clampf(model.hp / model.max_hp, 0, 1), 4), Color("96d993") if model.side == 0 else Color("ee8a6c"))
	if model.get("guard_time", 0.0) > 0:
		draw_arc(Vector2(0, -18), 23, 0, TAU, 24, Color(0.55, 0.85, 1, 0.7), 2)
