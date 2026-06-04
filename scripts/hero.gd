extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }

var speed := 80.0
var attack_damage := 10
var max_hp := 100
var hp := 100
var patrol_left := 100.0
var patrol_right := 600.0
var patrol_direction := 1.0

var state := State.PATROL
var target: CharacterBody2D = null
var enemies_in_range: Array = []

@onready var attack_timer: Timer = $AttackTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var health_bar: Node2D = $HealthBar
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: Node2D = $Visual

func _ready() -> void:
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	anim.animation_finished.connect(_on_anim_finished)
	_setup_animations()
	anim.play("idle")

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
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase()
		State.ATTACK:
			velocity = Vector2.ZERO
			if anim.current_animation != "attack":
				anim.play("idle")

func _do_patrol() -> void:
	velocity = Vector2(speed * patrol_direction, 0.0)
	move_and_slide()
	visual.scale.x = 0.4 * patrol_direction
	if anim.current_animation != "walk":
		anim.play("walk")
	if position.x >= patrol_right:
		patrol_direction = -1.0
	elif position.x <= patrol_left:
		patrol_direction = 1.0

func _do_chase() -> void:
	if not is_instance_valid(target):
		_pick_target()
		return
	var dist := position.distance_to(target.position)
	if dist <= 40.0:
		state = State.ATTACK
		velocity = Vector2.ZERO
		if attack_timer.is_stopped():
			attack_timer.start()
		return
	var dir := (target.position - position).normalized()
	velocity = dir * speed
	move_and_slide()
	visual.scale.x = 0.4 * sign(dir.x) if dir.x != 0.0 else visual.scale.x
	if anim.current_animation != "walk":
		anim.play("walk")

func _on_attack_timer_timeout() -> void:
	if state != State.ATTACK:
		return
	if not is_instance_valid(target):
		_pick_target()
		return
	if position.distance_to(target.position) > 50.0:
		state = State.CHASE
		attack_timer.stop()
		return
	target.take_damage(attack_damage)
	anim.play("attack")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		anim.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		_pick_target()

func _on_body_exited(body: Node2D) -> void:
	enemies_in_range.erase(body)
	if enemies_in_range.is_empty():
		state = State.PATROL
		target = null
		attack_timer.stop()
	else:
		_pick_target()

func _pick_target() -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		state = State.PATROL
		target = null
		attack_timer.stop()
		return
	target = enemies_in_range[0]
	state = State.CHASE

func take_damage(amount: int) -> void:
	hp -= amount
	health_bar.update_bar(hp, max_hp)
	if hp <= 0:
		hp = max_hp
		health_bar.update_bar(hp, max_hp)
