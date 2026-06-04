extends CharacterBody2D

signal died(gold_reward: int, shard_reward: int)

var speed := 50.0
var max_hp := 30
var hp := 30
var atk := 4
var def := 0
var gold_min := 8
var gold_max := 12
var shard_min := 1
var shard_max := 2
var attack_range := 40.0

var hero: CharacterBody2D = null

@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: Node2D = $HealthBar
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("enemies")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	anim.animation_finished.connect(_on_anim_finished)
	_setup_animations()
	anim.play("idle")

func setup(hero_ref: CharacterBody2D, data: Dictionary) -> void:
	hero = hero_ref
	if data.is_empty():
		return
	max_hp = data["hp"] as int
	hp = max_hp
	atk = data["atk"] as int
	def = data["def"] as int
	gold_min = data["gold_min"] as int
	gold_max = data["gold_max"] as int
	shard_min = data["shard_min"] as int
	shard_max = data["shard_max"] as int
	health_bar.update_bar(hp, max_hp)

func _setup_animations() -> void:
	var lib := AnimationLibrary.new()

	var idle := Animation.new()
	idle.length = 0.6
	idle.loop_mode = Animation.LOOP_LINEAR
	var ti := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(ti, "Visual/Body:position:y")
	idle.track_insert_key(ti, 0.0, -10.0)
	idle.track_insert_key(ti, 0.3, -12.0)
	idle.track_insert_key(ti, 0.6, -10.0)
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
	var aa := attack.add_track(Animation.TYPE_VALUE)
	attack.track_set_path(aa, "Visual/Arm:rotation")
	attack.track_insert_key(aa, 0.0, -0.7)
	attack.track_insert_key(aa, 0.15, 0.5)
	attack.track_insert_key(aa, 0.3, 0.0)
	lib.add_animation("attack", attack)

	anim.add_animation_library("", lib)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(hero):
		return
	var dist := position.distance_to(hero.position)
	if dist > attack_range:
		var dir := (hero.position - position).normalized()
		velocity = dir * speed
		move_and_slide()
		visual.scale.x = 0.4 * sign(dir.x) if dir.x != 0.0 else visual.scale.x
		if anim.current_animation != "walk":
			anim.play("walk")
	else:
		velocity = Vector2.ZERO
		if attack_timer.is_stopped():
			attack_timer.start()
		if anim.current_animation != "attack":
			anim.play("idle")

func _on_attack_timer_timeout() -> void:
	if is_instance_valid(hero):
		var dmg := maxi(1, atk - (hero.def if "def" in hero else 0))
		hero.take_damage(dmg)
		anim.play("attack")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		anim.play("idle")

func take_damage(amount: int) -> void:
	var dmg := maxi(1, amount - def)
	hp -= dmg
	health_bar.update_bar(hp, max_hp)
	if hp <= 0:
		die()

func die() -> void:
	var gold := randi_range(gold_min, gold_max)
	var shard := randi_range(shard_min, shard_max)
	emit_signal("died", gold, shard)
	queue_free()
