extends CharacterBody2D

signal stats_changed

enum State { IDLE, COMBAT }

const HERO_ID := "H001"

var level := 1
var max_level := 10

var _data: Dictionary = {}
var max_hp := 100
var hp := 100
var atk := 8
var def := 0
var atk_speed := 1.6

var state := State.IDLE
var target: CharacterBody2D = null
var enemies_in_range: Array = []

@onready var attack_timer: Timer = $AttackTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var health_bar: Node2D = $HealthBar
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: Node2D = $Visual

func setup(hero_data: Dictionary) -> void:
	_data = hero_data

func _ready() -> void:
	_apply_stats()
	attack_timer.wait_time = atk_speed
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	anim.animation_finished.connect(_on_anim_finished)
	_setup_animations()
	anim.play("idle")

func _apply_stats() -> void:
	if _data.is_empty():
		return
	max_hp = (_data["hp"] as int) + (level - 1) * 5
	hp = max_hp
	atk = (_data["atk"] as int) + (level - 1) * 2
	def = _data["def"] as int
	atk_speed = _data["atk_speed"] as float

func _setup_animations() -> void:
	var lib := AnimationLibrary.new()

	var idle := Animation.new()
	idle.length = 0.6
	idle.loop_mode = Animation.LOOP_LINEAR
	var ti := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(ti, "Visual/Body:position:y")
	idle.track_insert_key(ti, 0.0, 0.0)
	idle.track_insert_key(ti, 0.3, -2.0)
	idle.track_insert_key(ti, 0.6, 0.0)
	lib.add_animation("idle", idle)

	var walk := Animation.new()
	walk.length = 0.4
	walk.loop_mode = Animation.LOOP_LINEAR
	var wl := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(wl, "Visual/Leg:rotation")
	walk.track_insert_key(wl, 0.0, 0.35)
	walk.track_insert_key(wl, 0.2, -0.35)
	walk.track_insert_key(wl, 0.4, 0.35)
	var wl2 := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(wl2, "Visual/Leg2:rotation")
	walk.track_insert_key(wl2, 0.0, -0.35)
	walk.track_insert_key(wl2, 0.2, 0.35)
	walk.track_insert_key(wl2, 0.4, -0.35)
	lib.add_animation("walk", walk)

	var attack := Animation.new()
	attack.length = 0.3
	attack.loop_mode = Animation.LOOP_NONE
	var aw := attack.add_track(Animation.TYPE_VALUE)
	attack.track_set_path(aw, "Visual/Weapon:rotation")
	attack.track_insert_key(aw, 0.0, -1.05)
	attack.track_insert_key(aw, 0.2, 0.35)
	attack.track_insert_key(aw, 0.3, 0.0)
	lib.add_animation("attack", attack)

	anim.add_animation_library("", lib)

func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if anim.current_animation != "idle":
				anim.play("idle")
		State.COMBAT:
			velocity = Vector2.ZERO
			if anim.current_animation != "attack":
				anim.play("idle")

func _on_attack_timer_timeout() -> void:
	if state != State.COMBAT:
		return
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		state = State.IDLE
		attack_timer.stop()
		return
	target = enemies_in_range[0]
	var dmg := maxi(1, atk - target.def) if "def" in target else atk
	target.take_damage(dmg)
	anim.play("attack")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		anim.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		if state == State.IDLE:
			state = State.COMBAT
			attack_timer.wait_time = atk_speed
			attack_timer.start()

func _on_body_exited(body: Node2D) -> void:
	enemies_in_range.erase(body)
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		state = State.IDLE
		target = null
		attack_timer.stop()

func take_damage(amount: int) -> void:
	var dmg := maxi(1, amount - def)
	hp -= dmg
	health_bar.update_bar(hp, max_hp)
	if hp <= 0:
		hp = max_hp
		health_bar.update_bar(hp, max_hp)

func upgrade_level() -> void:
	if level >= max_level:
		return
	level += 1
	_apply_stats()
	health_bar.update_bar(hp, max_hp)
	emit_signal("stats_changed")

func power() -> int:
	if _data.is_empty():
		return 0
	return roundi((_data["base_power"] as float) + (_data["power_per_level"] as float) * (level - 1))

func upgrade_gold_cost() -> int:
	return roundi(20.0 * pow(level, 1.35))

func upgrade_shard_cost() -> int:
	return roundi(2.0 * pow(level, 1.20))
