extends CharacterBody2D

signal died(gold_reward: int)

var speed := 50.0
var attack_damage := 5
var max_hp := 30
var hp := 30
var gold_reward := 5
var attack_range := 40.0

var hero: CharacterBody2D = null

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	add_to_group("enemies")
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func setup(hero_ref: CharacterBody2D) -> void:
	hero = hero_ref

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(hero):
		return
	var dist := position.distance_to(hero.position)
	if dist > attack_range:
		var dir := (hero.position - position).normalized()
		velocity = dir * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if attack_timer.is_stopped():
			attack_timer.start()

func _on_attack_timer_timeout() -> void:
	if is_instance_valid(hero):
		hero.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	emit_signal("died", gold_reward)
	queue_free()
