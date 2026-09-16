extends Node2D
## Cosmetic sparring only; never reads or changes the campaign state.
signal restore_requested
signal drag_started
const PACK := "res://asset/Tiny Swords (Free Pack)/"
const VIEW_SIZE := Vector2i(220, 84)
@export var warrior_guard: Texture2D = preload(PACK + "Units/Blue Units/Warrior/Warrior_Guard.png")
@export var warrior_attack: Texture2D = preload(PACK + "Units/Blue Units/Warrior/Warrior_Attack1.png")
@export_range(0.5, 20, 0.1) var duel_seconds := 5.0
@export_range(1, 30, 1) var animation_fps := 10.0
@export var lunge_distance := 12.0
@export var fireball_arc_height := 12.0
var clock := 0.0
@onready var warrior: Sprite2D = $Warrior
@onready var opponent: Sprite2D = $Opponent
@onready var cleric: Sprite2D = $Cleric
@onready var fireball: Sprite2D = $Fireball
@onready var impact: Sprite2D = $Impact
@onready var restore: Button = $Restore
var homes: Dictionary = {}

func _ready() -> void:
	for actor in [warrior,opponent,cleric,fireball,impact]: homes[actor] = actor.position
	restore.pressed.connect(func(): restore_requested.emit())
	restore.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			drag_started.emit())

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	# Normalize the choreography so one duration knob keeps the duel synchronized.
	var phase := fposmod(clock, maxf(0.5,duel_seconds)) / maxf(0.5,duel_seconds) * 5.0
	var first_attacks := phase < 2.5
	set_pose(warrior, warrior_attack if first_attacks else warrior_guard)
	set_pose(opponent, warrior_guard if first_attacks else warrior_attack)
	var lunge := sin(fmod(phase, 2.5) / 2.5 * PI) * lunge_distance
	warrior.position = homes[warrior] + Vector2(lunge if first_attacks else 0.0,0)
	opponent.position = homes[opponent] - Vector2(0.0 if first_attacks else lunge,0)
	fireball.visible = phase >= 1 and phase < 2.1
	fireball.position = Vector2(homes[fireball]).lerp(Vector2(homes[impact]),clampf((phase-1)/1.1,0,1)) + Vector2(0,-4-sin((phase-1)*PI)*fireball_arc_height)
	impact.visible = phase >= 2.1 and phase < 2.55
	for actor in [warrior, opponent, cleric, fireball, impact]: actor.frame = int(clock * animation_fps) % actor.hframes

func set_pose(actor: Sprite2D, texture: Texture2D) -> void:
	if actor.texture == texture or texture == null: return
	var frame_width := actor.texture.get_width()/actor.hframes
	actor.frame = 0
	actor.texture = texture
	actor.hframes = maxi(1,texture.get_width()/frame_width)
