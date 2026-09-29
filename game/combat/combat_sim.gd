class_name CombatSim
extends RefCounted
## Pure, headless, deterministic fight simulation (60 Hz). simulate() runs the whole fight
## and returns {events, result}; the same lineup, seed and mods always give the same fight.
## Only setup, targeting ties and damage draw from the RNG; movement never does.

const STEP := 1.0 / 60.0
const MAX_DURATION := 600.0
const ARENA_RADIUS := 260.0
const BODY_RADIUS := 16.0
const MELEE_RANGE := 45.0
const RANGED_RANGE := 160.0
const RETREAT_RANGE := 110.0
const SWEEP_RANGE := 90.0
const MELEE_SPEED := 90.0
const RANGED_SPEED := 75.0
const ATTACK_INTERVAL := 1.5
const ACTION_PAUSE := 0.2
const TARGET_INTERVAL := 0.25
const DASH_DISTANCE := 110.0
const DASH_DURATION := 0.22
const APPROACH_COOLDOWN := 4.5
const ESCAPE_COOLDOWN := 12.0
const APPROACH_RANGE := 200.0
const ESCAPE_RANGE := 100.0
const PUSHBACK_DISTANCE := 65.0
const PUSHBACK_DURATION := 0.22
const OVERTIME_AFTER := 60.0
const OVERTIME_GROWTH := 0.1
const MANA_MAX := 100
const MANA_ON_HIT := 25
const MANA_ON_HURT := 15
const CAST_TIP := 10
const EXCITEMENT_MAX := 100.0
const EXCITEMENT_PER_CAST := 8.0
const EXCITEMENT_PER_SECOND := 1.0
const EXCITEMENT_TIME_CAP := 20.0
const EXCITEMENT_THRESHOLDS := [0.0, 25.0, 60.0]
const EXCITEMENT_MULTIPLIERS := [1.0, 1.25, 2.5]


class Fighter:
	var id: int
	var ranged: bool
	var skill_kind: String
	var skill_power: float
	var attack: int
	var max_hp: int
	var hp: int
	var damage_mult := 1.0
	var mana := 0
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO  # position at the start of this step's movement
	var target: Fighter
	var target_timer := 0.0
	var cooldown := 0.0
	var pause := 0.0
	var dash_cooldown := 0.5
	var pursuit_until := 0.0
	var motion := {}  # active dash or pushback: kind, origin, destination, elapsed, duration
	var track := PackedVector2Array()

	func reach() -> float:
		return RANGED_RANGE if ranged else MELEE_RANGE

	func is_dashing() -> bool:
		return not motion.is_empty() and motion.kind != "pushback"


var _rng := RandomNumberGenerator.new()
var _fighters: Array[Fighter] = []  # lineup order
var _action_order: Array[Fighter] = []
var _pending_casts: Array[Fighter] = []
var _events: Array[Dictionary] = []
var _skill_mult := 1.0
var _step := 0
var _elapsed := 0.0
var _excitement := 0.0
var _tips := 0
var _active := true


static func simulate(lineup: Array, rng_seed: int, mods: Dictionary = {}) -> Dictionary:
	var sim := CombatSim.new()
	sim._setup(lineup, rng_seed, mods)
	while sim._active and sim._elapsed < MAX_DURATION:
		sim._advance()
	return {"events": sim._events, "result": sim._result()}


static func excitement_tier(score: float) -> int:
	for tier in range(EXCITEMENT_THRESHOLDS.size() - 1, -1, -1):
		if score >= EXCITEMENT_THRESHOLDS[tier]:
			return tier
	return 0


static func excitement_multiplier(score: float) -> float:
	return EXCITEMENT_MULTIPLIERS[excitement_tier(score)]


func _setup(lineup: Array, rng_seed: int, mods: Dictionary) -> void:
	_rng.seed = rng_seed
	_excitement = minf(EXCITEMENT_MAX, float(mods.get("start_excitement", 0.0)))
	_skill_mult = float(mods.get("skill_excitement_mult", 1.0))
	var damage_mult: Dictionary = mods.get("damage_mult", {})
	for entry: Dictionary in lineup:
		var fighter := Fighter.new()
		fighter.id = entry.id
		fighter.ranged = entry.ranged
		fighter.skill_kind = entry.skill.kind
		fighter.skill_power = float(entry.skill.power)
		fighter.attack = int(entry.attack)
		fighter.max_hp = int(entry.health)
		fighter.hp = fighter.max_hp
		fighter.damage_mult = float(damage_mult.get(fighter.id, 1.0))
		_fighters.append(fighter)
	var remaining := _fighters.duplicate()
	while not remaining.is_empty():
		_action_order.append(remaining.pop_at(_rng.randi_range(0, remaining.size() - 1)))
	for slot in range(_action_order.size()):
		var fighter := _action_order[slot]
		fighter.pos = Vector2.from_angle(-PI / 2.0 + TAU * slot / _fighters.size()) * ARENA_RADIUS * 0.72
		fighter.cooldown = _rng.randf_range(0.0, 0.3)
	_record_tracks()


func _result() -> Dictionary:
	var hp_left := {}
	var tracks := {}
	var winner: Fighter = _fighters[0]
	for fighter in _fighters:
		hp_left[fighter.id] = fighter.hp
		tracks[fighter.id] = fighter.track
		if fighter.hp > winner.hp:
			winner = fighter  # on timeout the healthiest fighter wins
	var counts := {"attack": 0, "skill": 0}
	for event in _events:
		if counts.has(event.kind):
			counts[event.kind] += 1
	return {"winner": winner.id, "duration": _elapsed, "excitement": _excitement, "tips": _tips,
		"skills": counts.skill, "attacks": counts.attack, "hp_left": hp_left, "tracks": tracks}


func _advance() -> void:
	_step += 1
	var time_gain := minf(STEP, maxf(0.0, EXCITEMENT_TIME_CAP - _elapsed))
	_elapsed += STEP
	_excitement = minf(EXCITEMENT_MAX, _excitement + time_gain * EXCITEMENT_PER_SECOND)
	for fighter in _survivors():
		fighter.cooldown = maxf(0.0, fighter.cooldown - STEP)
		fighter.pause = maxf(0.0, fighter.pause - STEP)
		fighter.dash_cooldown = maxf(0.0, fighter.dash_cooldown - STEP)
		fighter.target_timer -= STEP
		if fighter.target_timer <= 0.0 or fighter.target == null or fighter.target.hp <= 0:
			_target_for(fighter)
			fighter.target_timer = TARGET_INTERVAL
	_move()
	for fighter in _action_order:
		_queue_ready(fighter)
	_resolve_casts()
	for fighter in _action_order:
		if not _active:
			break
		if fighter.hp <= 0 or fighter.mana == MANA_MAX or fighter.cooldown > 0.0 or fighter.is_dashing():
			continue
		if not _in_range(fighter, _target_for(fighter), fighter.reach()):
			continue
		fighter.cooldown = ATTACK_INTERVAL
		_act(fighter, false)
		_resolve_casts()  # the attacker and surviving defender cast before another normal hit
	_record_tracks()


func _record_tracks() -> void:
	for fighter in _fighters:
		fighter.track.append(fighter.pos)


func _survivors() -> Array[Fighter]:
	var alive: Array[Fighter] = []
	for fighter in _fighters:
		if fighter.hp > 0:
			alive.append(fighter)
	return alive


func _fighter(id: int) -> Fighter:
	for fighter in _fighters:
		if fighter.id == id:
			return fighter
	return null


# --- Movement -------------------------------------------------------------------------------

func _move() -> void:
	var alive := _survivors()
	for fighter in _fighters:
		fighter.prev = fighter.pos
	for fighter in alive:
		if fighter.motion.is_empty() and fighter.pause <= 0.0 and fighter.target != null:
			_try_dash(fighter)
		if not fighter.motion.is_empty():
			_step_motion(fighter)
		elif fighter.target != null and fighter.pause <= 0.0:
			fighter.pos = (fighter.prev + _walk_offset(fighter)).limit_length(ARENA_RADIUS)
	# ponytail: pairwise separation is fine for a handful of fighters, revisit for crowds.
	for a in range(alive.size()):
		for b in range(a + 1, alive.size()):
			_separate(alive[a], alive[b])


func _step_motion(fighter: Fighter) -> void:
	var motion := fighter.motion
	motion.elapsed = minf(motion.duration, motion.elapsed + STEP)
	var progress: float = motion.elapsed / motion.duration
	if motion.kind == "pushback":
		progress = 1.0 - pow(1.0 - progress, 2)
	fighter.pos = motion.origin.lerp(motion.destination, progress).limit_length(ARENA_RADIUS)
	if motion.elapsed >= motion.duration:
		fighter.motion = {}
		fighter.target_timer = 0.0


func _walk_offset(fighter: Fighter) -> Vector2:
	var offset := fighter.target.prev - fighter.prev
	var distance := offset.length()
	if distance > fighter.reach():
		var speed := RANGED_SPEED if fighter.ranged else MELEE_SPEED
		return offset.normalized() * minf(speed * STEP, distance - fighter.reach())
	if fighter.ranged and distance < RETREAT_RANGE:
		var away := -offset.normalized() if distance > 0.001 else Vector2.RIGHT
		var retreat := away * minf(RANGED_SPEED * STEP, RETREAT_RANGE - distance)
		# At the fence, stand and fight instead of circling forever.
		return Vector2.ZERO if (fighter.prev + retreat).length() > ARENA_RADIUS else retreat
	return Vector2.ZERO


func _separate(first: Fighter, second: Fighter) -> void:
	var offset := second.pos - first.pos
	var overlap := BODY_RADIUS * 2.0 - offset.length()
	if overlap <= 0.0:
		return
	var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
	var push := direction * minf(overlap * 0.5, 30.0 * STEP)
	first.pos = (first.pos - push).limit_length(ARENA_RADIUS)
	second.pos = (second.pos + push).limit_length(ARENA_RADIUS)


func _try_dash(fighter: Fighter) -> void:
	if fighter.dash_cooldown > 0.0:
		return
	var destination := fighter.prev
	var kind := "escape" if fighter.ranged else "approach"
	if fighter.ranged:
		destination = _escape_destination(fighter)
	else:
		var offset := fighter.target.prev - fighter.prev
		var distance := offset.length()
		if distance > MELEE_RANGE + 25.0 and distance <= APPROACH_RANGE:
			destination = fighter.prev + offset.normalized() * minf(DASH_DISTANCE, distance - MELEE_RANGE + 4.0)
	if destination.is_equal_approx(fighter.prev):
		return
	destination = destination.limit_length(ARENA_RADIUS)
	fighter.motion = {"kind": kind, "origin": fighter.prev, "destination": destination,
		"elapsed": 0.0, "duration": DASH_DURATION}
	fighter.dash_cooldown = ESCAPE_COOLDOWN if fighter.ranged else APPROACH_COOLDOWN
	if not fighter.ranged:
		fighter.pursuit_until = _elapsed + APPROACH_COOLDOWN  # finish the chase, don't switch targets
	var event := _event(fighter, "move")
	event.move_kind = kind
	event.destination = destination
	event.duration = DASH_DURATION
	_events.append(event)


## Ranged escape: only from a close opponent chasing this fighter; otherwise stay put.
func _escape_destination(fighter: Fighter) -> Vector2:
	var threat: Fighter = null
	var nearest := ESCAPE_RANGE
	for opponent in _survivors():
		var gap := fighter.prev.distance_to(opponent.prev)
		if opponent != fighter and opponent.target == fighter and gap <= nearest:
			threat = opponent
			nearest = gap
	if threat == null:
		return fighter.prev
	var away := (fighter.prev - threat.prev).normalized()
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var best := _clearance(fighter, fighter.prev) + 10.0
	var destination := fighter.prev
	for angle in [0.0, PI / 3, -PI / 3, PI / 2, -PI / 2]:
		var candidate := (fighter.prev + away.rotated(angle) * DASH_DISTANCE).limit_length(ARENA_RADIUS)
		if candidate.distance_to(fighter.prev) < 40.0:
			continue
		var safety := _clearance(fighter, candidate)
		if safety > best:
			best = safety
			destination = candidate
	return destination


func _clearance(fighter: Fighter, point: Vector2) -> float:
	var clearance := INF
	for opponent in _survivors():
		if opponent != fighter:
			clearance = minf(clearance, point.distance_to(opponent.prev))
	return clearance


# --- Actions --------------------------------------------------------------------------------

func _in_range(actor: Fighter, target: Fighter, radius: float) -> bool:
	return target != null and target.hp > 0 and actor.pos.distance_to(target.pos) <= radius + 0.001


func _queue_ready(fighter: Fighter) -> void:
	if fighter.hp > 0 and fighter.mana == MANA_MAX and fighter not in _pending_casts:
		_pending_casts.append(fighter)


func _resolve_casts() -> void:
	if not _active:
		return
	var waiting := _pending_casts.duplicate()
	_pending_casts.clear()
	for fighter: Fighter in waiting:
		if fighter.hp <= 0 or fighter.mana != MANA_MAX:
			continue
		if fighter.is_dashing():
			_pending_casts.append(fighter)
			continue
		var target := _target_for(fighter)
		var radius := SWEEP_RANGE if fighter.skill_kind == "sweep" else fighter.reach()
		if fighter.skill_kind != "heal" and not _in_range(fighter, target, radius):
			_pending_casts.append(fighter)
			continue
		_act(fighter, true)
		if not _active:
			return


func _event(fighter: Fighter, kind: String) -> Dictionary:
	return {"t": _step * STEP, "kind": kind, "attacker": fighter.id, "origin": fighter.pos, "radius": 0.0,
		"hits": [], "healing": 0, "tip": 0, "excitement_gain": 0.0, "winner": -1, "excitement": _excitement}


func _act(attacker: Fighter, casting: bool) -> void:
	var target := _target_for(attacker)
	var event := _event(attacker, "skill" if casting else "attack")
	attacker.pause = ACTION_PAUSE
	if casting:
		_cast(attacker, target, event)
	else:
		_strike(attacker, target, event)
	var alive := _survivors()
	if alive.size() == 1:
		_active = false
		_pending_casts.clear()
		event.winner = alive[0].id
	event.excitement = _excitement
	_events.append(event)


func _strike(attacker: Fighter, target: Fighter, event: Dictionary) -> void:
	var damage := maxi(1, attacker.attack + _rng.randi_range(-3, 3))
	event.hits.append(_hit(attacker, target, damage))
	attacker.mana = mini(MANA_MAX, attacker.mana + MANA_ON_HIT)
	if target.hp > 0:
		target.mana = mini(MANA_MAX, target.mana + MANA_ON_HURT)
	_queue_ready(attacker)
	_queue_ready(target)


func _cast(attacker: Fighter, target: Fighter, event: Dictionary) -> void:
	# Tips and excitement start with the cast, including a fight-ending cast.
	attacker.mana = 0
	event.tip = CAST_TIP
	_tips += CAST_TIP
	event.excitement_gain = minf(EXCITEMENT_PER_CAST * _skill_mult, EXCITEMENT_MAX - _excitement)
	_excitement += event.excitement_gain
	var amount := roundi(float(attacker.attack) * attacker.skill_power)
	match attacker.skill_kind:
		"heal":
			event.healing = _heal(attacker, roundi(float(attacker.max_hp) * attacker.skill_power))
		"sweep":
			event.radius = SWEEP_RANGE
			for opponent in _survivors():
				if opponent != attacker and _in_range(attacker, opponent, SWEEP_RANGE):
					event.hits.append(_hit(attacker, opponent, amount))
		"strike", "drain":
			var hit := _hit(attacker, target, amount)
			event.hits.append(hit)
			if attacker.skill_kind == "drain":
				event.healing = _heal(attacker, hit.damage)
	# Resolve every hit first, then push survivors away from the snapshotted impact.
	for hit in event.hits:
		var victim := _fighter(hit.target)
		if victim.hp > 0:
			var direction: Vector2 = (hit.position - event.origin).normalized()
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			hit.push_to = (hit.position + direction * PUSHBACK_DISTANCE).limit_length(ARENA_RADIUS)
			victim.motion = {"kind": "pushback", "origin": hit.position, "destination": hit.push_to,
				"elapsed": 0.0, "duration": PUSHBACK_DURATION}


## Nearest opponent; ties go to the current target, else to the RNG.
func _target_for(attacker: Fighter) -> Fighter:
	if attacker.pursuit_until > _elapsed and attacker.target != null and attacker.target.hp > 0:
		return attacker.target
	attacker.pursuit_until = 0.0
	var candidates: Array[Fighter] = []
	var best := INF
	for fighter in _survivors():
		if fighter == attacker:
			continue
		var distance := attacker.pos.distance_squared_to(fighter.pos)
		if is_equal_approx(distance, best):
			candidates.append(fighter)
		elif distance < best:
			best = distance
			candidates.assign([fighter])
	if attacker.target not in candidates:
		attacker.target = candidates[_rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null
	return attacker.target


func _hit(attacker: Fighter, target: Fighter, amount: int) -> Dictionary:
	# Mirror healers would otherwise sustain forever, so damage ramps up in overtime.
	var overtime := 1.0 + maxf(0.0, _elapsed - OVERTIME_AFTER) * OVERTIME_GROWTH
	var damage := mini(target.hp, roundi(amount * overtime * attacker.damage_mult))
	target.hp -= damage
	if target.hp == 0:
		target.motion = {}
		target.pursuit_until = 0.0
	return {"target": target.id, "damage": damage, "position": target.pos, "push_to": target.pos}


func _heal(fighter: Fighter, amount: int) -> int:
	var restored := mini(fighter.max_hp - fighter.hp, amount)
	fighter.hp += restored
	return restored
