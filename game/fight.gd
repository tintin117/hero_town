extends RefCounted
## Session-only fight rules. UI and animation never decide rewards.

const BASE_INCOME := 100
const COINS_PER_VICTORY := 5
const MANA_MAX := 100
const MANA_ON_HIT := 25
const MANA_ON_HURT := 15
const CAST_TIP := 10
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

var heroes: Array[Dictionary] = [
	{"name": "Bram", "unit": "warrior", "red": false, "stars": 3, "health": 150, "attack": 17, "wins": 0,
		"ranged": false, "skill": {"name": "Heavy Strike", "kind": "strike", "power": 2.0, "description": "Deal 2x attack damage to the nearest enemy within 45 units."}},
	{"name": "Ivo", "unit": "lancer", "red": false, "stars": 3, "health": 132, "attack": 21, "wins": 0,
		"ranged": false, "skill": {"name": "Sweep", "kind": "sweep", "power": 1.0, "description": "Deal attack damage to every enemy within a 90-unit circle."}},
	{"name": "Nia", "unit": "archer", "red": false, "stars": 2, "health": 110, "attack": 18, "wins": 0,
		"ranged": true, "skill": {"name": "Snipe", "kind": "strike", "power": 2.5, "description": "Deal 2.5x attack damage to the nearest enemy within 160 units."}},
	{"name": "Tuck", "unit": "monk", "red": false, "stars": 2, "health": 140, "attack": 13, "wins": 0,
		"ranged": false, "skill": {"name": "Second Wind", "kind": "heal", "power": 0.3, "description": "Restore 30% of maximum HP to yourself."}},
	{"name": "Rook", "unit": "warrior", "red": true, "stars": 1, "health": 105, "attack": 12, "wins": 0,
		"ranged": false, "skill": {"name": "Drain", "kind": "drain", "power": 1.5, "description": "Deal 1.5x attack damage within 45 units. Heal by actual damage dealt."}},
]
var rng := RandomNumberGenerator.new()
var participants: Array[int] = []
var health: Dictionary = {}
var mana: Dictionary = {}
var positions: Dictionary = {}
var velocities: Dictionary = {}
var targets: Dictionary = {}
var target_timers: Dictionary = {}
var cooldowns: Dictionary = {}
var pauses: Dictionary = {}
var pending_casts: Array[int] = []
var action_order: Array[int] = []
var active := false
var coins := 0
var completed := 0
var payout := 0
var crowd_tips := 0
var last_winner := -1


func valid_lineup(lineup: Array[int]) -> bool:
	if lineup.size() != 3:
		return false
	var unique := {}
	for id in lineup:
		if id < 0 or id >= heroes.size() or unique.has(id):
			return false
		unique[id] = true
	return true


func income_for(lineup: Array[int]) -> int:
	if not valid_lineup(lineup):
		return 0
	var victories := 0
	for id in lineup:
		victories += int(heroes[id].wins)
	return BASE_INCOME + victories * COINS_PER_VICTORY


func start(lineup: Array[int]) -> bool:
	if active or not valid_lineup(lineup):
		return false
	participants = lineup.duplicate()
	for state in [health, mana, positions, velocities, targets, target_timers, cooldowns, pauses]:
		state.clear()
	pending_casts.clear()
	action_order.clear()
	crowd_tips = 0
	var remaining := participants.duplicate()
	while not remaining.is_empty():
		action_order.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	for slot in range(action_order.size()):
		var id := action_order[slot]
		health[id] = int(heroes[id].health)
		mana[id] = 0
		positions[id] = Vector2.from_angle(-PI / 2.0 + TAU * slot / 3.0) * ARENA_RADIUS * 0.72
		velocities[id] = Vector2.ZERO
		targets[id] = -1
		target_timers[id] = 0.0
		cooldowns[id] = rng.randf_range(0.0, 0.3)
		pauses[id] = 0.0
	payout = income_for(participants)
	last_winner = -1
	active = true
	return true


func survivors() -> Array[int]:
	var alive: Array[int] = []
	for id in participants:
		if health[id] > 0:
			alive.append(id)
	return alive


func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not active or delta <= 0.0 or not is_finite(delta):
		return events
	for id in survivors():
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
		pauses[id] = maxf(0.0, pauses[id] - delta)
		target_timers[id] -= delta
		if target_timers[id] <= 0.0 or health.get(targets[id], 0) <= 0:
			_target_for(id)
			target_timers[id] = TARGET_INTERVAL
	_move(delta)
	for id in action_order:
		_queue_ready(id)
	_resolve_casts(events)
	for id in action_order:
		if not active:
			break
		if health[id] <= 0 or mana[id] == MANA_MAX or cooldowns[id] > 0.0:
			continue
		var target := _target_for(id)
		if not _in_range(id, target, attack_range(id)):
			continue
		cooldowns[id] = ATTACK_INTERVAL
		events.append(_act(id, false))
		# A hit's attacker and surviving defender cast before another normal hit.
		_resolve_casts(events)
	return events


func attack_range(id: int) -> float:
	return RANGED_RANGE if heroes[id].ranged else MELEE_RANGE


func _move(delta: float) -> void:
	var before := positions.duplicate()
	var alive := survivors()
	for id in alive:
		var target: int = targets[id]
		if target < 0 or pauses[id] > 0.0:
			continue
		var offset: Vector2 = before[target] - before[id]
		var distance := offset.length()
		var movement := Vector2.ZERO
		if distance > attack_range(id):
			var speed := RANGED_SPEED if heroes[id].ranged else MELEE_SPEED
			movement = offset.normalized() * minf(speed * delta, distance - attack_range(id))
		elif heroes[id].ranged and distance < RETREAT_RANGE:
			var away := -offset.normalized() if distance > 0.001 else Vector2.RIGHT
			movement = away * minf(RANGED_SPEED * delta, RETREAT_RANGE - distance)
			# At the fence, stand and fight instead of circling forever.
			if (before[id] + movement).length() > ARENA_RADIUS:
				movement = Vector2.ZERO
		positions[id] = (before[id] + movement).limit_length(ARENA_RADIUS)
	# ponytail: pairwise separation is sufficient for three heroes; revisit for large crowds.
	for a in range(alive.size()):
		for b in range(a + 1, alive.size()):
			var first := alive[a]
			var second := alive[b]
			var offset: Vector2 = positions[second] - positions[first]
			var overlap := BODY_RADIUS * 2.0 - offset.length()
			if overlap <= 0.0:
				continue
			var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
			var push := direction * minf(overlap * 0.5, 30.0 * delta)
			positions[first] = (positions[first] - push).limit_length(ARENA_RADIUS)
			positions[second] = (positions[second] + push).limit_length(ARENA_RADIUS)
	for id in participants:
		velocities[id] = (positions[id] - before[id]) / delta if health[id] > 0 else Vector2.ZERO


func _in_range(actor: int, target: int, radius: float) -> bool:
	return target >= 0 and health[target] > 0 and positions[actor].distance_to(positions[target]) <= radius + 0.001


func _queue_ready(id: int) -> void:
	if health[id] > 0 and mana[id] == MANA_MAX and id not in pending_casts:
		pending_casts.append(id)


func _resolve_casts(events: Array[Dictionary]) -> void:
	if not active:
		return
	var waiting := pending_casts.duplicate()
	pending_casts.clear()
	for id in waiting:
		if health[id] <= 0 or mana[id] != MANA_MAX:
			continue
		var target := _target_for(id)
		var skill: Dictionary = heroes[id].skill
		var radius := SWEEP_RANGE if skill.kind == "sweep" else attack_range(id)
		if skill.kind != "heal" and not _in_range(id, target, radius):
			pending_casts.append(id)
			continue
		events.append(_act(id, true))
		if not active:
			return


func _act(attacker: int, casting: bool) -> Dictionary:
	var target := _target_for(attacker)
	var event := {"kind": "skill" if casting else "attack", "attacker": attacker,
		"origin": positions[attacker], "radius": 0.0, "hits": [], "healing": 0, "tip": 0, "winner": -1}
	pauses[attacker] = ACTION_PAUSE
	if casting:
		# Pay at cast start; settlement only pays the guaranteed booking income.
		mana[attacker] = 0
		coins += CAST_TIP
		crowd_tips += CAST_TIP
		event.kind = "skill"
		event.tip = CAST_TIP
		var skill: Dictionary = heroes[attacker].skill
		var amount := roundi(float(heroes[attacker].attack) * float(skill.power))
		match skill.kind:
			"heal":
				event.healing = _heal(attacker, roundi(float(heroes[attacker].health) * float(skill.power)))
			"sweep":
				event.radius = SWEEP_RANGE
				for opponent in survivors():
					if opponent != attacker and _in_range(attacker, opponent, SWEEP_RANGE):
						event.hits.append(_hit(opponent, amount))
			"strike", "drain":
				var hit := _hit(target, amount)
				event.hits.append(hit)
				if skill.kind == "drain":
					event.healing = _heal(attacker, hit.damage)
	else:
		var damage := maxi(1, int(heroes[attacker].attack) + rng.randi_range(-3, 3))
		event.hits.append(_hit(target, damage))
		mana[attacker] = mini(MANA_MAX, int(mana[attacker]) + MANA_ON_HIT)
		if health[target] > 0:
			mana[target] = mini(MANA_MAX, int(mana[target]) + MANA_ON_HURT)
		for id in [attacker, target]:
			_queue_ready(id)
	var alive := survivors()
	if alive.size() == 1:
		active = false
		pending_casts.clear()
		last_winner = alive[0]
		coins += payout
		heroes[last_winner].wins += 1
		completed += 1
		event.winner = last_winner
		for id in participants:
			velocities[id] = Vector2.ZERO
	# Snapshots let the UI consume several same-frame actions in their reward order.
	event.coins = coins
	event.crowd_tips = crowd_tips
	return event


func _target_for(attacker: int) -> int:
	var candidates: Array[int] = []
	var best := INF
	for id in survivors():
		if id == attacker:
			continue
		var distance: float = positions[attacker].distance_squared_to(positions[id])
		if is_equal_approx(distance, best):
			candidates.append(id)
		elif distance < best:
			best = distance
			candidates.assign([id])
	var target: int = targets.get(attacker, -1)
	if target not in candidates:
		target = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else -1
	targets[attacker] = target
	return target


func _hit(target: int, amount: int) -> Dictionary:
	var damage := mini(int(health[target]), amount)
	health[target] -= damage
	return {"target": target, "damage": damage, "position": positions[target]}


func _heal(id: int, amount: int) -> int:
	var restored := mini(int(heroes[id].health) - int(health[id]), amount)
	health[id] += restored
	return restored
