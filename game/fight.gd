extends RefCounted
## Session-only fight rules. UI and animation never decide rewards.

const BASE_INCOME := 100
const COINS_PER_VICTORY := 5
const COINS_PER_LEVEL := 5
const ARENA_CAPACITIES := [100, 150, 200]
const ARENA_UPGRADE_COSTS := [500, 1000]
const MANA_MAX := 100
const MANA_ON_HIT := 25
const MANA_ON_HURT := 15
const CAST_TIP := 10
const EXCITEMENT_MAX := 100.0
const EXCITEMENT_PER_CAST := 8.0
const EXCITEMENT_PER_SECOND := 1.0
const EXCITEMENT_TIME_CAP := 20.0
const EXCITEMENT_THRESHOLDS := [0.0, 40.0, 80.0]
const EXCITEMENT_MULTIPLIERS := [1.0, 1.25, 2.5]
const EXCITEMENT_NAMES := ["NORMAL", "EXCITED", "WILD"]
const LEVEL_CAP := 10
const XP_PER_FIGHT := 10
const XP_WIN_BONUS := 10
const XP_BASE := 30
const XP_STEP := 20
const STAT_PER_LEVEL := 0.05
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
	{"name": "Bram", "unit": "warrior", "red": false, "level": 1, "xp": 0, "health": 150, "attack": 17, "wins": 0,
		"ranged": false, "skill": {"name": "Heavy Strike", "kind": "strike", "power": 2.0, "description": "Deal 2x attack damage to the nearest enemy within 45 units."}},
	{"name": "Ivo", "unit": "lancer", "red": false, "level": 1, "xp": 0, "health": 132, "attack": 21, "wins": 0,
		"ranged": false, "skill": {"name": "Sweep", "kind": "sweep", "power": 1.0, "description": "Deal attack damage to every enemy within a 90-unit circle."}},
	{"name": "Nia", "unit": "archer", "red": false, "level": 1, "xp": 0, "health": 110, "attack": 18, "wins": 0,
		"ranged": true, "skill": {"name": "Snipe", "kind": "strike", "power": 2.5, "description": "Deal 2.5x attack damage to the nearest enemy within 160 units."}},
	{"name": "Tuck", "unit": "monk", "red": false, "level": 1, "xp": 0, "health": 140, "attack": 13, "wins": 0,
		"ranged": false, "skill": {"name": "Second Wind", "kind": "heal", "power": 0.3, "description": "Restore 30% of maximum HP to yourself."}},
	{"name": "Rook", "unit": "warrior", "red": true, "level": 1, "xp": 0, "health": 105, "attack": 12, "wins": 0,
		"ranged": false, "skill": {"name": "Drain", "kind": "drain", "power": 1.5, "description": "Deal 1.5x attack damage within 45 units. Heal by actual damage dealt."}},
]
var rng := RandomNumberGenerator.new()
var participants: Array[int] = []
var health: Dictionary = {}
var mana: Dictionary = {}
var battle_stats: Dictionary = {}
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
var arena_tier := 0
var completed := 0
var payout := 0
var crowd_tips := 0
var excitement := 0.0
var elapsed := 0.0
var settled_income := 0
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
	return int(income_breakdown(lineup).get("guaranteed", 0))


func income_breakdown(lineup: Array[int]) -> Dictionary:
	if not valid_lineup(lineup):
		return {}
	var victories := 0
	var levels := 0
	for id in lineup:
		victories += int(heroes[id].wins)
		levels += int(heroes[id].level) - 1
	var multiplier := float(arena_capacity()) / ARENA_CAPACITIES[0]
	var level_bonus := levels * COINS_PER_LEVEL
	var victory_bonus := victories * COINS_PER_VICTORY
	return {"base": BASE_INCOME, "levels": level_bonus, "victories": victory_bonus,
		"multiplier": multiplier, "guaranteed": roundi((BASE_INCOME + level_bonus + victory_bonus) * multiplier)}


func arena_capacity() -> int:
	return ARENA_CAPACITIES[arena_tier]


static func excitement_tier(score: float) -> int:
	for tier in range(EXCITEMENT_THRESHOLDS.size() - 1, -1, -1):
		if score >= EXCITEMENT_THRESHOLDS[tier]:
			return tier
	return 0


func income_with_excitement(score: float) -> int:
	return roundi(payout * EXCITEMENT_MULTIPLIERS[excitement_tier(score)])


func arena_upgrade_cost() -> int:
	return ARENA_UPGRADE_COSTS[arena_tier] if arena_tier < ARENA_UPGRADE_COSTS.size() else 0


func upgrade_arena() -> bool:
	var cost := arena_upgrade_cost()
	if cost == 0 or coins < cost:
		return false
	coins -= cost
	arena_tier += 1
	return true


func xp_needed(id: int) -> int:
	return XP_BASE + XP_STEP * (int(heroes[id].level) - 1) if heroes[id].level < LEVEL_CAP else 0


func stats_for(id: int) -> Dictionary:
	var hero: Dictionary = heroes[id]
	var growth := 1.0 + STAT_PER_LEVEL * (int(hero.level) - 1)
	return {"health": roundi(float(hero.health) * growth), "attack": roundi(float(hero.attack) * growth)}


func _award_xp(id: int, amount: int) -> Dictionary:
	var hero: Dictionary = heroes[id]
	var before: int = hero.level
	var gained := amount if before < LEVEL_CAP else 0
	hero.xp += gained
	while hero.level < LEVEL_CAP and hero.xp >= xp_needed(id):
		hero.xp -= xp_needed(id)
		hero.level += 1
	if hero.level == LEVEL_CAP:
		hero.xp = 0
	return {"hero": id, "xp": gained, "before": before, "level": hero.level}


func start(lineup: Array[int]) -> bool:
	if active or not valid_lineup(lineup):
		return false
	participants = lineup.duplicate()
	for state in [health, mana, battle_stats, positions, velocities, targets, target_timers, cooldowns, pauses]:
		state.clear()
	pending_casts.clear()
	action_order.clear()
	crowd_tips = 0
	excitement = 0.0
	elapsed = 0.0
	settled_income = 0
	var remaining := participants.duplicate()
	while not remaining.is_empty():
		action_order.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	for slot in range(action_order.size()):
		var id := action_order[slot]
		# Freeze combat stats for this fight; XP is settled afterward.
		battle_stats[id] = stats_for(id)
		health[id] = battle_stats[id].health
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
	var time_gain := minf(delta, maxf(0.0, EXCITEMENT_TIME_CAP - elapsed))
	elapsed += delta
	excitement = minf(EXCITEMENT_MAX, excitement + time_gain * EXCITEMENT_PER_SECOND)
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
		"origin": positions[attacker], "radius": 0.0, "hits": [], "healing": 0, "tip": 0,
		"excitement_gain": 0.0, "winner": -1, "progression": []}
	pauses[attacker] = ACTION_PAUSE
	if casting:
		# Tips and excitement start with the cast, including a fight-ending cast.
		mana[attacker] = 0
		event.tip = CAST_TIP
		coins += event.tip
		crowd_tips += event.tip
		event.excitement_gain = minf(EXCITEMENT_PER_CAST, EXCITEMENT_MAX - excitement)
		excitement += event.excitement_gain
		var skill: Dictionary = heroes[attacker].skill
		var amount := roundi(float(battle_stats[attacker].attack) * float(skill.power))
		match skill.kind:
			"heal":
				event.healing = _heal(attacker, roundi(float(battle_stats[attacker].health) * float(skill.power)))
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
		var damage := maxi(1, int(battle_stats[attacker].attack) + rng.randi_range(-3, 3))
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
		settled_income = income_with_excitement(excitement)
		coins += settled_income
		heroes[last_winner].wins += 1
		completed += 1
		event.winner = last_winner
		for id in participants:
			velocities[id] = Vector2.ZERO
			event.progression.append(_award_xp(id, XP_PER_FIGHT + (XP_WIN_BONUS if id == last_winner else 0)))
	# Snapshots let the UI consume several same-frame actions in their reward order.
	event.coins = coins
	event.crowd_tips = crowd_tips
	event.excitement = excitement
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
	var restored := mini(int(battle_stats[id].health) - int(health[id]), amount)
	health[id] += restored
	return restored
