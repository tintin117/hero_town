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

func _ready() -> void:
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	match state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase()
		State.ATTACK:
			velocity = Vector2.ZERO

func _do_patrol() -> void:
	velocity = Vector2(speed * patrol_direction, 0.0)
	move_and_slide()
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
	if hp <= 0:
		hp = max_hp
