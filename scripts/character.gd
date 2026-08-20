class_name Character
extends CharacterBody3D

signal died

enum State { MOVE, COMBAT, KNOCKBACK, DEAD }

@export var max_hp: float = 100.0
@export var atk: float = 10.0
@export var atk_speed: float = 1.5
@export var move_speed: float = 2.5
@export var attack_range: float = 1.5
@export var mana_per_hit: float = 0.0
@export var skill: SkillData

const KNOCKBACK_FORCE := 3.0
const KNOCKBACK_DURATION := 0.25
const PLAYFIELD_MIN_X := -28.0
const PLAYFIELD_MAX_X := 10.0
const HITBOX_LAYER := 1 << 2

const SKILL_HIT_SCENE := preload("res://scenes/skill_hit.tscn")

var hp: float
var state: State = State.MOVE
var target: Character = null
var knockback_timer: float = 0.0
var mana: float = 0.0
var _skill_cooldown: float = 0.0

var _attack_timer: Timer
@onready var _health_bar_fill: Sprite3D = $CameraFacingContainer/HealthBarFill
var _health_bar_full_width: float


func _ready() -> void:
	hp = max_hp
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = HITBOX_LAYER
	collision_mask = 0

	_attack_timer = Timer.new()
	_attack_timer.wait_time = atk_speed
	_attack_timer.one_shot = false
	_attack_timer.autostart = false
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)

	_health_bar_full_width = _health_bar_fill.scale.x
	_update_health_bar()


func _update_health_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_health_bar_fill.scale.x = _health_bar_full_width * ratio
	_health_bar_fill.modulate = Color.RED.lerp(Color.GREEN, ratio)


func _physics_process(delta: float) -> void:
	if _skill_cooldown > 0.0:
		_skill_cooldown -= delta

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
			elif global_position.distance_to(target.global_position) > attack_range:
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
	if opponent != null and global_position.distance_to(opponent.global_position) <= attack_range:
		_enter_combat(opponent)
		return
	if opponent != null:
		var dir := signf(opponent.global_position.x - global_position.x)
		velocity = Vector3(dir * move_speed, 0.0, 0.0)
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
	if global_position.distance_to(target.global_position) <= attack_range:
		target.take_damage(atk, self)
		spawn_fx(atk, false, false)
		_charge_mana()


func take_damage(amount: float, attacker: Character) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_update_health_bar()
	if hp <= 0.0:
		state = State.DEAD
		_on_death()
		died.emit()
		queue_free()
		return
	_charge_mana()
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


## Charges mana on dealing or taking a hit; casts and resets once full.
func _charge_mana() -> void:
	if skill == null:
		return
	mana += mana_per_hit
	if mana >= skill.mana_cost and _skill_cooldown <= 0.0:
		mana = 0.0
		_skill_cooldown = skill.cooldown
		_cast_skill()


## Spawns the generic skill-hit box at this character's position, aimed at
## whichever group opposes it. AOE stays put; a projectile flies at `target`.
func _cast_skill() -> void:
	print("%s casts skill (%s)" % [name, skill.resource_path.get_file()])
	var hit := SKILL_HIT_SCENE.instantiate() as SkillHit
	hit.damage = skill.damage
	hit.radius = skill.radius
	hit.lifetime = skill.duration
	hit.tick_interval = skill.tick_interval
	hit.caster = self
	hit.target_group = "enemies" if is_in_group("heroes") else "heroes"
	if skill.shape == SkillData.Shape.PROJECTILE:
		hit.speed = skill.projectile_speed
		hit.direction = (target.global_position - global_position).normalized() if is_instance_valid(target) else Vector3.FORWARD
	hit.position = global_position
	get_tree().current_scene.add_child(hit)

func spawn_fx(value:float, crit:bool, screen_shake:bool):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	# Convert 3D top position to 2D screen position
	var text_pos = global_position + Vector3(0, get_character_height()*3, 0)
	var impact_pos = global_position + Vector3(0, get_character_height()*2, 0)
	var screen_text_pos = camera.unproject_position(text_pos)
	var screen_impact_pos = camera.unproject_position(impact_pos)
	fx.spawn("impact_spark", screen_impact_pos, {"size": 0.3})
	if screen_shake:
		fx.shake(0.2, 0.1)
	fx.hitstop(0.06)
	#fx.flash(Color.WHITE, 0.1)
	fx.popup(str(value), screen_text_pos, {"crit": crit})

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
