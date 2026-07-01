extends CharacterBody2D

signal stats_changed

enum State { IDLE, PATROL, CHASE, COMBAT }

const PATROL_SPEED := 50.0
const CHASE_SPEED := 90.0
const ATTACK_RANGE := 55.0
var patrol_max_x := 700.0   # set by main.gd based on portal position

const RESPAWN_DELAY := 10.0

var hero_id := "H001"
var level := 1
var max_level := 10

var _data: Dictionary = {}
var max_hp := 100
var hp := 100
var atk := 8
var def := 0
var atk_speed := 1.6
var crit_chance := 0.02

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
	if "id" in hero_data:
		hero_id = hero_data["id"]

func _ready() -> void:
	_apply_stats()
	# Heroes don't physically block each other — combat range is handled by DetectionArea
	collision_mask = 0
	attack_timer.wait_time = atk_speed
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	anim.animation_finished.connect(_on_anim_finished)
	#_setup_animations()
	anim.play("idle")

func _apply_stats() -> void:
	if _data.is_empty():
		return
	var base_hp: int = _data.get("base_hp", _data.get("hp", 100)) as int
	max_hp = base_hp + (level - 1) * 5
	hp = max_hp
	# Derive atk from base_power for heroes defined by power, else legacy field
	var bp: float = _data.get("base_power", 0.0) as float
	var ppl: float = _data.get("power_per_level", 0.0) as float
	atk = roundi(bp + ppl * (level - 1)) if bp > 0 else (_data.get("atk", 8) as int) + (level - 1) * 2
	def = _data.get("def", 0) as int
	atk_speed = _data.get("atk_speed", 1.6) as float
	crit_chance = _data.get("crit_chance", 0.02) as float

#func _setup_animations() -> void:
	#var lib := AnimationLibrary.new()
#
	#var idle := Animation.new()
	#idle.length = 0.6
	#idle.loop_mode = Animation.LOOP_LINEAR
	#var ti := idle.add_track(Animation.TYPE_VALUE)
	#idle.track_set_path(ti, "Visual/Body:position:y")
	#idle.track_insert_key(ti, 0.0, 0.0)
	#idle.track_insert_key(ti, 0.3, -2.0)
	#idle.track_insert_key(ti, 0.6, 0.0)
	#lib.add_animation("idle", idle)
#
	#var walk := Animation.new()
	#walk.length = 0.4
	#walk.loop_mode = Animation.LOOP_LINEAR
	#var wl := walk.add_track(Animation.TYPE_VALUE)
	#walk.track_set_path(wl, "Visual/Leg:rotation")
	#walk.track_insert_key(wl, 0.0, 0.35)
	#walk.track_insert_key(wl, 0.2, -0.35)
	#walk.track_insert_key(wl, 0.4, 0.35)
	#var wl2 := walk.add_track(Animation.TYPE_VALUE)
	#walk.track_set_path(wl2, "Visual/Leg2:rotation")
	#walk.track_insert_key(wl2, 0.0, -0.35)
	#walk.track_insert_key(wl2, 0.2, 0.35)
	#walk.track_insert_key(wl2, 0.4, -0.35)
	#lib.add_animation("walk", walk)
#
	#var attack := Animation.new()
	#attack.length = 0.3
	#attack.loop_mode = Animation.LOOP_NONE
	#var aw := attack.add_track(Animation.TYPE_VALUE)
	#attack.track_set_path(aw, "Visual/Weapon:rotation")
	#attack.track_insert_key(aw, 0.0, -1.05)
	#attack.track_insert_key(aw, 0.2, 0.35)
	#attack.track_insert_key(aw, 0.3, 0.0)
	#lib.add_animation("attack", attack)
#
	#anim.add_animation_library("", lib)

func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			# Start patrolling rightward immediately
			state = State.PATROL
		State.PATROL:
			if not enemies_in_range.is_empty():
				state = State.CHASE
				return
			if global_position.x < patrol_max_x:
				velocity = Vector2(PATROL_SPEED, 0)
				visual.scale.x = 1.0
			else:
				velocity = Vector2.ZERO
			move_and_slide()
			if anim.current_animation != "idle":
				anim.play("idle")
		State.CHASE:
			enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
			if enemies_in_range.is_empty():
				state = State.PATROL
				return
			target = enemies_in_range[0]
			var dist := global_position.distance_to(target.global_position)
			if dist <= ATTACK_RANGE:
				state = State.COMBAT
				attack_timer.wait_time = atk_speed
				attack_timer.start()
				velocity = Vector2.ZERO
			else:
				var dir: float = sign(target.global_position.x - global_position.x)
				velocity = Vector2(dir * CHASE_SPEED, 0)
				visual.scale.x = dir
			move_and_slide()
			if anim.current_animation != "idle":
				anim.play("idle")
		State.COMBAT:
			velocity = Vector2.ZERO
			if anim.current_animation != "attack":
				anim.play("attack")

func _on_attack_timer_timeout() -> void:
	if state != State.COMBAT:
		return
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		state = State.PATROL
		attack_timer.stop()
		return
	target = enemies_in_range[0]
	var dmg := maxi(1, atk - (target.def if "def" in target else 0))
	if randf() < crit_chance:
		dmg *= 2
	target.take_damage(dmg)
	anim.play("attack")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		anim.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		if state == State.PATROL or state == State.IDLE:
			state = State.CHASE

func _on_body_exited(body: Node2D) -> void:
	enemies_in_range.erase(body)
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		state = State.PATROL
		target = null
		attack_timer.stop()

func take_damage(amount: int) -> void:
	var dmg := maxi(1, amount - def)
	hp -= dmg
	health_bar.update_bar(hp, max_hp)
	if hp <= 0:
		_die()

func _die() -> void:
	state = State.PATROL
	attack_timer.stop()
	enemies_in_range.clear()
	target = null
	visual.visible = false
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_instance_valid(self):
		return
	hp = max_hp
	health_bar.update_bar(hp, max_hp)
	visual.visible = true
	anim.play("idle")

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
	var base: float = _data.get("upgrade_gold_base", 20.0) as float
	return roundi(base * pow(level, 1.35))

func upgrade_shard_cost() -> int:
	var base: float = _data.get("upgrade_shard_base", 2.0) as float
	return roundi(base * pow(level, 1.20))
