class_name Character
extends CharacterBody3D

signal died

enum State { MOVE, COMBAT, KNOCKBACK, DEAD }

## Base stats -- not exported, always set from HeroData/EnemyData (see Hero/Enemy._ready()).
var max_hp: float = 100.0
var atk: float = 10.0
var atk_speed: float = 1.5
var mana_per_hit: float = 0.0

const MELEE_ATTACK_RANGE := 1.5
const RANGED_ATTACK_RANGE := 6.0
const PROJECTILE_SPEED := 10.0
const PROJECTILE_HIT_RADIUS := 0.3
const KNOCKBACK_FORCE := 3.0
const KNOCKBACK_DURATION := 0.25
## ponytail: matches Ground4Grid's PlaneMesh (size 60x30, centered on origin) in
## test_3d_prototype.tscn with a small inset. If that ground mesh is resized, update these too.
const PLAYFIELD_MIN_X := -29.0
const PLAYFIELD_MAX_X := 29.0
const PLAYFIELD_MIN_Z := -7.0
const PLAYFIELD_MAX_Z := 7.0
const HITBOX_LAYER := 1 << 2
const SEPARATION_RADIUS := 1.0
const TARGET_LOAD_PENALTY := 2.0

@export var move_speed: float = 2.5
@export var attack_range: float = MELEE_ATTACK_RANGE
@export var skill: SkillData

var is_ranged: bool = false

const SKILL_HIT_SCENE := preload("res://scenes/skill_hit.tscn")

var hp: float
var state: State = State.MOVE
var target: Character = null
var attackers_count: int = 0
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
			global_position.z = clampf(global_position.z, PLAYFIELD_MIN_Z, PLAYFIELD_MAX_Z)
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
			global_position.z = clampf(global_position.z, PLAYFIELD_MIN_Z, PLAYFIELD_MAX_Z)


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
		var to_opponent := opponent.global_position - global_position
		to_opponent.y = 0.0
		var seek := to_opponent.normalized() if to_opponent.length() > 0.01 else Vector3.ZERO
		var steer := seek + _separation_force(get_own_group())
		if steer.length() > 0.01:
			velocity = steer.normalized() * move_speed
		else:
			velocity = Vector3.ZERO
	else:
		_idle_move()


## Virtual: the group this character belongs to ("heroes"/"enemies"), used for separation.
func get_own_group() -> String:
	return ""


## Boids-lite separation: pushes away from same-group allies within SEPARATION_RADIUS.
## ponytail: separation only, no alignment/cohesion -- groups are 1-3 units per side, too
## small for those rules to read as anything but noise. Revisit if roster/enemy caps grow
## well past single digits.
func _separation_force(own_group: String) -> Vector3:
	var push := Vector3.ZERO
	if own_group == "":
		return push
	for node in get_tree().get_nodes_in_group(own_group):
		var ally := node as Character
		if ally == null or ally == self or ally.state == State.DEAD:
			continue
		var offset := global_position - ally.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			push += offset.normalized() * (SEPARATION_RADIUS - dist)
	return push


## Virtual: movement when no opponent exists in the target group.
func _idle_move() -> void:
	velocity = Vector3.ZERO


## Scores candidates by distance plus a penalty per ally already attacking them, so heroes
## spread across multiple active enemies instead of dog-piling the single nearest one.
func _find_nearest_in_group(group_name: String) -> Character:
	var nearest: Character = null
	var nearest_score := INF
	for node in get_tree().get_nodes_in_group(group_name):
		var candidate := node as Character
		if candidate == null or candidate.state == State.DEAD:
			continue
		var score := global_position.distance_to(candidate.global_position) \
				+ candidate.attackers_count * TARGET_LOAD_PENALTY
		if score < nearest_score:
			nearest_score = score
			nearest = candidate
	return nearest


func _enter_combat(with: Character) -> void:
	target = with
	target.attackers_count += 1
	state = State.COMBAT
	_attack_timer.start()
	_on_attack_timeout()  # Timer.start() waits a full atk_speed before its first tick -- hit now, timer covers the repeats.


func _exit_combat() -> void:
	_release_target()
	state = State.MOVE
	_attack_timer.stop()


## Detaches from the current target (if any) without touching `state`, so it's safe to call
## both from a normal combat exit and from this character's own death.
func _release_target() -> void:
	if is_instance_valid(target):
		target.attackers_count = maxi(0, target.attackers_count - 1)
	target = null


func _on_attack_timeout() -> void:
	if state != State.COMBAT or not is_instance_valid(target) or target.state == State.DEAD:
		return
	if global_position.distance_to(target.global_position) <= attack_range:
		if is_ranged:
			_fire_projectile()
		else:
			target.take_damage(atk, self)
			spawn_fx(atk, false, false)
		_charge_mana()


## Fires a travel-time hitbox at `target` for ranged basic attacks (reuses the skill-cast SkillHit).
func _fire_projectile() -> void:
	var hit := SKILL_HIT_SCENE.instantiate() as SkillHit
	hit.damage = atk
	hit.radius = PROJECTILE_HIT_RADIUS
	hit.speed = PROJECTILE_SPEED
	hit.direction = (target.global_position - global_position).normalized()
	hit.lifetime = attack_range / PROJECTILE_SPEED + 0.2
	hit.crit = false
	hit.screen_shake = false
	hit.caster = self
	hit.target_group = "enemies" if is_in_group("heroes") else "heroes"
	hit.position = global_position
	get_tree().current_scene.add_child(hit)


func take_damage(amount: float, attacker: Character) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_update_health_bar()
	if hp <= 0.0:
		_release_target()
		state = State.DEAD
		_on_death()
		died.emit()
		_die()
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


## Virtual: called once when hp reaches 0, after _on_death(). Default permanently
## removes this character. Override to change what "death" means (e.g. a revive).
func _die() -> void:
	queue_free()


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
