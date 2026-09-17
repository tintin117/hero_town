class_name ArmyUnitView
extends Node2D

@export_group("Art")
@export var art_library: UnitArtLibrary
## An explicit override takes precedence over the class and faction library.
@export var sprite_frames_override: SpriteFrames
@export var death_effect: PackedScene = preload("res://game/town/death_dust.tscn")
@export var boss_scale_multiplier := 1.45
@export_group("Presentation")
@export var movement_smoothing := 24.0
@export var death_fade_seconds := 1.0
@export var hit_flash_color := Color(1.8, 1.8, 1.6)

var model: Dictionary
@onready var sprite: AnimatedSprite2D = $Sprite
var clock: float = 0.0
var _dead: bool = false
var flash_remaining: float = 0.0
var _authored_tint := Color.WHITE

func _ready() -> void:
	_authored_tint = sprite.modulate
	if model.is_empty(): return
	if sprite_frames_override != null:
		sprite.sprite_frames = sprite_frames_override
	elif art_library != null:
		sprite.sprite_frames = art_library.frames(model.visual, model.side == 1)
	if not model.get("boss", "").is_empty(): sprite.scale *= boss_scale_multiplier
	sprite.play("idle")
	position = model.position

func update_view(delta: float, battle_time: float) -> void:
	clock = battle_time
	flash_remaining = maxf(0.0, flash_remaining - delta)
	position = position.lerp(model.position, minf(1, delta * movement_smoothing))
	z_index = int(position.y) + 200
	if model.hp <= 0:
		if not _dead:
			_dead = true
			sprite.stop()
			if death_effect != null:
				var dust := death_effect.instantiate() as Node2D
				get_parent().add_child(dust)
				dust.global_position = global_position
			create_tween().tween_property(sprite, "modulate:a", 0.0, death_fade_seconds)
	else:
		_dead = false
		sprite.modulate = _authored_tint * hit_flash_color if flash_remaining > 0 else _authored_tint
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
