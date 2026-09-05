class_name Character
extends CharacterBody2D

signal died

enum State { MOVE, COMBAT, KNOCKBACK, DEAD }

## Base stats -- not exported, always set from HeroData/EnemyData (see Hero/Enemy._ready()).
var max_hp: float = 100.0
var atk: float = 10.0
var atk_speed: float = 1.5
var mana_per_hit: float = 0.0

const MELEE_ATTACK_RANGE := 70.0
const RANGED_ATTACK_RANGE := 260.0
const PROJECTILE_SPEED := 420.0
const PROJECTILE_HIT_RADIUS := 12.0
const KNOCKBACK_FORCE := 160.0
const KNOCKBACK_DURATION := 0.25
## ponytail: matches the 12x5 board in town_2d.tscn (Terrain TileMapLayer,
## 64px tiles, centered on origin) with a small inset. If the board size changes, update these too.
const PLAYFIELD_MIN_X := -370.0
const PLAYFIELD_MAX_X := 370.0
const PLAYFIELD_MIN_Y := -145.0
const PLAYFIELD_MAX_Y := 145.0
const HITBOX_LAYER := 1 << 2
const SEPARATION_RADIUS := 40.0
const TARGET_LOAD_PENALTY := 80.0
const CRIT_CHANCE := 0.10
const CRIT_MULT := 2.0
const SPRITE_SCALE := 0.34
const FLASH_DURATION := 0.15
## World-unit-to-pixel scale for skill data (radius/projectile_speed were authored
## against the old 3D board where one grid hex was ~2 world units == 64px here).
const SKILL_UNIT_TO_PX := 32.0

@export var move_speed: float = 90.0
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
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health_bar_fill: ColorRect = $HealthBar/Fill
@onready var _health_bar_bg: ColorRect = $HealthBar/Bg
var _health_bar_full_width: float

var _facing_right: bool = true
var _flash_tween: Tween
var _squash_tween: Tween
var _action_lock_until_msec: int = 0


func _ready() -> void:
	hp = max_hp
	collision_layer = HITBOX_LAYER
	collision_mask = 0

	_attack_timer = Timer.new()
	_attack_timer.wait_time = atk_speed
	_attack_timer.one_shot = false
	_attack_timer.autostart = false
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)

	_setup_sprite()
	_health_bar_full_width = _health_bar_fill.size.x
	_update_health_bar()


## Virtual: subclasses return the SpriteFrames for their unit.
func _get_sprite_frames() -> SpriteFrames:
	return null


func _setup_sprite() -> void:
	var frames := _get_sprite_frames()
	if frames == null:
		return
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	sprite.play("idle")
	# Anchor feet at the node origin (tile center) instead of the sprite's visual
	# center -- frame heights vary per unit (Lancer is 320px, others 192px), so
	# this is computed from the actual frame rather than a fixed offset.
	var first_frame := frames.get_frame_texture("idle", 0)
	if first_frame != null:
		sprite.offset = Vector2(0, -first_frame.get_height() * 0.5)


## Plays a looping state animation unless a one-shot action is still holding the rig.
func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames == null or Time.get_ticks_msec() < _action_lock_until_msec:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


## Plays a one-shot action (attack/cast) and locks state anims while it runs.
func _play_action(anim_name: String, max_lock: float = 10.0) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	sprite.play(anim_name)
	var frame_count := sprite.sprite_frames.get_frame_count(anim_name)
	var fps := sprite.sprite_frames.get_animation_speed(anim_name)
	var length := float(frame_count) / fps if fps > 0.0 else 0.3
	var lock := minf(length, max_lock)
	_action_lock_until_msec = Time.get_ticks_msec() + int(lock * 1000.0)


func _update_visuals(_delta: float) -> void:
	if sprite == null:
		return
	var face_dir := 0.0
	if state == State.COMBAT and is_instance_valid(target):
		face_dir = target.global_position.x - global_position.x
	elif absf(velocity.x) > 1.0:
		face_dir = velocity.x
	if absf(face_dir) > 1.0:
		_facing_right = face_dir > 0.0
	sprite.flip_h = not _facing_right
	match state:
		State.MOVE:
			_play_anim("run" if velocity.length_squared() > 4.0 else "idle")
		State.COMBAT:
			_play_anim("idle")
		_:
			pass


func _play_hit_react() -> void:
	if sprite == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	sprite.modulate = Color(4, 4, 4)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, FLASH_DURATION)

	if _squash_tween != null:
		_squash_tween.kill()
	var base_scale := Vector2.ONE * SPRITE_SCALE
	sprite.scale = base_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", Vector2(1.15, 0.82) * SPRITE_SCALE, 0.06)
	_squash_tween.tween_property(sprite, "scale", base_scale, 0.12)


func _set_health_bar_visible(shown: bool) -> void:
	_health_bar_fill.visible = shown
	_health_bar_bg.visible = shown


func _update_health_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_health_bar_fill.size.x = _health_bar_full_width * ratio
	_health_bar_fill.color = Color.RED.lerp(Color.GREEN, ratio)
	_set_health_bar_visible(ratio < 0.999 and state != State.DEAD)


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
			global_position.y = clampf(global_position.y, PLAYFIELD_MIN_Y, PLAYFIELD_MAX_Y)
		State.COMBAT:
			velocity = Vector2.ZERO
			if not is_instance_valid(target) or target.state == State.DEAD:
				_exit_combat()
			elif global_position.distance_to(target.global_position) > attack_range:
				_exit_combat()
			move_and_slide()
		State.MOVE:
			_update_move(delta)
			move_and_slide()
			global_position.x = clampf(global_position.x, PLAYFIELD_MIN_X, PLAYFIELD_MAX_X)
			global_position.y = clampf(global_position.y, PLAYFIELD_MIN_Y, PLAYFIELD_MAX_Y)
	_update_visuals(delta)


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
		var seek := to_opponent.normalized() if to_opponent.length() > 0.01 else Vector2.ZERO
		var steer := seek + _separation_force(get_own_group())
		if steer.length() > 0.01:
			velocity = steer.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		_idle_move()


## Virtual: the group this character belongs to ("heroes"/"enemies"), used for separation.
func get_own_group() -> String:
	return ""


## Boids-lite separation: pushes away from same-group allies within SEPARATION_RADIUS.
## ponytail: separation only, no alignment/cohesion -- groups are 1-3 units per side, too
## small for those rules to read as anything but noise. Revisit if roster/enemy caps grow
## well past single digits.
func _separation_force(own_group: String) -> Vector2:
	var push := Vector2.ZERO
	if own_group == "":
		return push
	for node in get_tree().get_nodes_in_group(own_group):
		var ally := node as Character
		if ally == null or ally == self or ally.state == State.DEAD:
			continue
		var offset := global_position - ally.global_position
		var dist := offset.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			push += offset.normalized() * (SEPARATION_RADIUS - dist)
	return push


## Virtual: movement when no opponent exists in the target group.
func _idle_move() -> void:
	velocity = Vector2.ZERO


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
		var crit := randf() < CRIT_CHANCE
		var damage := atk * (CRIT_MULT if crit else 1.0)
		if is_ranged:
			_fire_projectile(damage, crit)
		else:
			target.take_damage(damage, self)
			spawn_fx(damage, crit, crit)
		_play_action("attack", atk_speed)
		_charge_mana()


## Fires a travel-time hitbox at `target` for ranged basic attacks (reuses the skill-cast SkillHit).
func _fire_projectile(damage: float, crit: bool) -> void:
	var hit := SKILL_HIT_SCENE.instantiate() as SkillHit
	hit.damage = damage
	hit.radius = PROJECTILE_HIT_RADIUS
	hit.speed = PROJECTILE_SPEED
	hit.direction = (target.global_position - global_position).normalized()
	hit.lifetime = attack_range / PROJECTILE_SPEED + 0.2
	hit.crit = crit
	hit.screen_shake = false
	hit.caster = self
	hit.target_group = "enemies" if is_in_group("heroes") else "heroes"
	hit.global_position = global_position
	get_tree().current_scene.add_child(hit)


func take_damage(amount: float, attacker: Character) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	if hp <= 0.0:
		_release_target()
		state = State.DEAD
		_attack_timer.stop()
		_set_health_bar_visible(false)
		_action_lock_until_msec = 0
		_on_death()
		died.emit()
		_die()
		return
	_update_health_bar()
	_play_hit_react()
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


func _apply_knockback(from_position: Vector2) -> void:
	var dir := global_position - from_position
	dir = dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
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
	_play_action("attack")
	var hit := SKILL_HIT_SCENE.instantiate() as SkillHit
	hit.crit = false
	hit.damage = skill.damage
	hit.radius = skill.radius * SKILL_UNIT_TO_PX
	hit.lifetime = skill.duration
	hit.tick_interval = skill.tick_interval
	hit.caster = self
	hit.target_group = "enemies" if is_in_group("heroes") else "heroes"
	if skill.shape == SkillData.Shape.PROJECTILE:
		hit.speed = skill.projectile_speed * SKILL_UNIT_TO_PX
		hit.direction = (target.global_position - global_position).normalized() if is_instance_valid(target) else Vector2.DOWN
	hit.global_position = global_position
	get_tree().current_scene.add_child(hit)


## opts positions are plain world positions now (no camera/viewport conversion --
## the 2D world root and its effect children already share one coordinate space).
func spawn_fx(value: float, crit: bool, screen_shake: bool) -> void:
	var text_pos := global_position + Vector2(0, -70.0)
	var impact_pos := global_position + Vector2(0, -40.0)
	fx.spawn("impact_spark", impact_pos, {"size": 0.3})
	if screen_shake:
		fx.shake(3.0, 0.1)
	fx.hitstop(0.06)
	fx.popup(str(roundi(value)), text_pos, {"crit": crit})
	sfx.play("crit" if crit else "hit")
