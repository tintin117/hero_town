class_name Character
extends CharacterBody3D

signal died

enum State { MOVE, COMBAT, KNOCKBACK, DEAD }

@export var stats: UnitStats

const KNOCKBACK_FORCE := 6.0
const KNOCKBACK_DURATION := 0.25
const PLAYFIELD_MIN_X := -28.0
const PLAYFIELD_MAX_X := 10.0

var hp: float
var state: State = State.MOVE
var target: Character = null
var knockback_timer: float = 0.0

var _attack_timer: Timer
@onready var _health_bar_fill: Sprite3D = $HealthBarFill
var _health_bar_full_width: float


func _ready() -> void:
	hp = stats.max_hp
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0

	_attack_timer = Timer.new()
	_attack_timer.wait_time = stats.atk_speed
	_attack_timer.one_shot = false
	_attack_timer.autostart = false
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)

	_health_bar_full_width = _health_bar_fill.scale.x
	_update_health_bar()


func _update_health_bar() -> void:
	var ratio := clampf(hp / stats.max_hp, 0.0, 1.0)
	_health_bar_fill.scale.x = _health_bar_full_width * ratio
	_health_bar_fill.modulate = Color.RED.lerp(Color.GREEN, ratio)


func _physics_process(delta: float) -> void:
	match state:
		State.DEAD:
			return
		State.KNOCKBACK:
			knockback_timer -= delta
			if knockback_timer <= 0.0:
				state = State.MOVE
			move_and_slide()
			global_position.x = clampf(global_position.x, PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)
		State.COMBAT:
			velocity = Vector3.ZERO
			if not is_instance_valid(target) or target.state == State.DEAD:
				_exit_combat()
			elif global_position.distance_to(target.global_position) > stats.attack_range:
				_exit_combat()
			move_and_slide()
		State.MOVE:
			_update_move(delta)
			move_and_slide()
			global_position.x = clampf(global_position.x, PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)


## Virtual: subclasses set `velocity` and call `_enter_combat` when a target is in range.
func _update_move(_delta: float) -> void:
	pass


## Steer toward the nearest Character in `opponent_group`, or engage combat if in range.
func _chase_and_engage(opponent_group: String) -> void:
	var opponent := _find_nearest_in_group(opponent_group)
	if opponent != null and global_position.distance_to(opponent.global_position) <= stats.attack_range:
		_enter_combat(opponent)
		return
	if opponent != null:
		var dir := signf(opponent.global_position.x - global_position.x)
		velocity = Vector3(dir * stats.move_speed, 0.0, 0.0)
	else:
		_idle_move()


## Virtual: movement when no opponent exists in the target group.
func _idle_move() -> void:
	velocity = Vector3.ZERO


func _find_nearest_in_group(group_name: String) -> Character:
	var nearest: Character = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(group_name):
		var candidate := node as Character
		if candidate == null or candidate.state == State.DEAD:
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = candidate
	return nearest


func _enter_combat(with: Character) -> void:
	target = with
	state = State.COMBAT
	_attack_timer.start()


func _exit_combat() -> void:
	state = State.MOVE
	target = null
	_attack_timer.stop()


func _on_attack_timeout() -> void:
	if state != State.COMBAT or not is_instance_valid(target) or target.state == State.DEAD:
		return
	if global_position.distance_to(target.global_position) <= stats.attack_range:
		target.take_damage(stats.atk, self)


func take_damage(amount: float, attacker: Character) -> void:
	if state == State.DEAD:
		return
	spawn_fx(amount)
	hp -= amount
	_update_health_bar()
	if hp <= 0.0:
		state = State.DEAD
		_on_death()
		died.emit()
		queue_free()
		return
	if _should_knockback(attacker):
		_apply_knockback(attacker.global_position)


## Virtual: return whether a hit from `attacker` should knock this character back.
func _should_knockback(_attacker: Character) -> bool:
	return true


## Virtual: called once when hp reaches 0, before this character is freed.
func _on_death() -> void:
	pass


func _apply_knockback(from_position: Vector3) -> void:
	var dir := global_position - from_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	velocity = dir * KNOCKBACK_FORCE
	knockback_timer = KNOCKBACK_DURATION
	state = State.KNOCKBACK
	
func spawn_fx(value:float):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	# Convert 3D top position to 2D screen position
	var text_pos = global_position + Vector3(0, get_character_height()*2.5, 0)
	var impact_pos = global_position + Vector3(0, get_character_height()*2, 0)
	var screen_text_pos = camera.unproject_position(text_pos)
	var screen_impact_pos = camera.unproject_position(impact_pos)
	fx.spawn("impact_spark", screen_impact_pos, {"size": 0.3})
	fx.shake(0.25)
	fx.hitstop(0.06)
	#fx.flash(Color.WHITE, 0.1)
	fx.popup(str(value), screen_text_pos, {"crit": true})

func get_character_height() -> float:
	# change "CollisionShape3D" to your actual node name
	var col = $CollisionShape3D

	if col.shape is CapsuleShape3D:
		return col.shape.height
	elif col.shape is BoxShape3D:
		return col.shape.size.y
	elif col.shape is SphereShape3D:
		return col.shape.radius * 2.0

	return 1.8  # fallback
