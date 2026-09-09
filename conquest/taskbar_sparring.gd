extends Node2D
## Cosmetic sparring only; never reads or changes the campaign state.
signal restore_requested
signal drag_started
const PACK := "res://asset/Tiny Swords (Free Pack)/"
const VIEW_SIZE := Vector2i(220, 84)
var clock := 0.0
var warrior: Sprite2D
var opponent: Sprite2D
var cleric: Sprite2D
var fireball: Sprite2D
var impact: Sprite2D
var restore: Button
var warrior_idle: Texture2D = preload(PACK + "Units/Blue Units/Warrior/Warrior_Idle.png")
var warrior_guard: Texture2D = preload(PACK + "Units/Blue Units/Warrior/Warrior_Guard.png")
var warrior_attack: Texture2D = preload(PACK + "Units/Blue Units/Warrior/Warrior_Attack1.png")

func _ready() -> void:
	warrior = make_sprite(warrior_idle, Vector2(42, 62), 0.6, 192)
	opponent = make_sprite(warrior_guard, Vector2(108, 62), 0.6, 192)
	opponent.flip_h = true
	cleric = make_sprite(load(PACK + "Units/Blue Units/Monk/Heal.png"), Vector2(176, 62), 0.6, 192)
	cleric.flip_h = true
	fireball = make_sprite(load(PACK + "Particle FX/Fire_02.png"), Vector2(160, 50), 0.5)
	impact = make_sprite(load(PACK + "Particle FX/Explosion_01.png"), Vector2(76, 50), 0.3)
	restore = Button.new()
	restore.text = ""
	restore.tooltip_text = "Click to return to town • drag along the taskbar"
	restore.position = Vector2(10, 22)
	restore.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		restore.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	restore.size = Vector2(200, 62)
	restore.pressed.connect(func(): restore_requested.emit())
	restore.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			drag_started.emit())
	add_child(restore)

func make_sprite(texture: Texture2D, at: Vector2, factor: float, frame_size := 0) -> Sprite2D:
	var actor := Sprite2D.new()
	actor.texture = texture
	actor.hframes = texture.get_width() / (texture.get_height() if frame_size == 0 else frame_size)
	actor.position = at
	actor.scale = Vector2.ONE * factor
	add_child(actor)
	return actor

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	var phase := fmod(clock, 5.0)
	var first_attacks := phase < 2.5
	set_pose(warrior, warrior_attack if first_attacks else warrior_guard)
	set_pose(opponent, warrior_guard if first_attacks else warrior_attack)
	var lunge := sin(fmod(phase, 2.5) / 2.5 * PI) * 12
	warrior.position.x = 42 + (lunge if first_attacks else 0.0)
	opponent.position.x = 108 - (0.0 if first_attacks else lunge)
	fireball.visible = phase >= 1 and phase < 2.1
	fireball.position = Vector2(lerpf(160, 76, clampf((phase - 1) / 1.1, 0, 1)), 46 - sin((phase - 1) * PI) * 12)
	impact.visible = phase >= 2.1 and phase < 2.55
	for actor in [warrior, opponent, cleric, fireball, impact]: actor.frame = int(clock * 10) % actor.hframes

func set_pose(actor: Sprite2D, texture: Texture2D) -> void:
	if actor.texture == texture: return
	actor.frame = 0
	actor.texture = texture
	actor.hframes = texture.get_width() / 192
