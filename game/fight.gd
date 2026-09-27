extends RefCounted
## Session-only fight rules. UI and animation never decide rewards.

const BASE_INCOME := 100
const COINS_PER_VICTORY := 5
const MANA_MAX := 100
const MANA_ON_HIT := 25
const MANA_ON_HURT := 15
const CAST_TIP := 10
const TARGET_LABELS := {
	"attack": "Highest attack", "health": "Highest current HP",
	"weak": "Lowest current HP", "random": "Random opponent",
	"revenge": "Last attacker (random if unavailable)",
}

var heroes: Array[Dictionary] = [
	{"name": "Bram", "unit": "warrior", "red": false, "stars": 3, "health": 150, "attack": 17, "wins": 0,
		"target": "attack", "skill": {"name": "Heavy Strike", "kind": "strike", "power": 2.0, "description": "Deal 2x attack damage to the preferred target."}},
	{"name": "Ivo", "unit": "lancer", "red": false, "stars": 3, "health": 132, "attack": 21, "wins": 0,
		"target": "health", "skill": {"name": "Sweep", "kind": "sweep", "power": 1.0, "description": "Deal attack damage to every living opponent."}},
	{"name": "Nia", "unit": "archer", "red": false, "stars": 2, "health": 110, "attack": 18, "wins": 0,
		"target": "weak", "skill": {"name": "Snipe", "kind": "strike", "power": 2.5, "description": "Deal 2.5x attack damage to the preferred target."}},
	{"name": "Tuck", "unit": "monk", "red": false, "stars": 2, "health": 140, "attack": 13, "wins": 0,
		"target": "random", "skill": {"name": "Second Wind", "kind": "heal", "power": 0.3, "description": "Restore 30% of maximum HP to yourself."}},
	{"name": "Rook", "unit": "warrior", "red": true, "stars": 1, "health": 105, "attack": 12, "wins": 0,
		"target": "revenge", "skill": {"name": "Drain", "kind": "drain", "power": 1.5, "description": "Deal 1.5x attack damage. Heal by actual damage dealt."}},
]
var rng := RandomNumberGenerator.new()
var participants: Array[int] = []
var health: Dictionary = {}
var mana: Dictionary = {}
var last_attacker: Dictionary = {}
var pending_casts: Array[int] = []
var turn_order: Array[int] = []
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
	health.clear()
	mana.clear()
	last_attacker.clear()
	pending_casts.clear()
	turn_order.clear()
	crowd_tips = 0
	for id in participants:
		health[id] = int(heroes[id].health)
		mana[id] = 0
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


func step() -> Dictionary:
	if not active:
		return {}
	var caster := -1
	while not pending_casts.is_empty():
		var candidate: int = pending_casts.pop_front()
		if health[candidate] > 0 and mana[candidate] == MANA_MAX:
			caster = candidate
			break
	var attacker := caster if caster >= 0 else _next_attacker()
	var event := {"kind": "attack", "attacker": attacker, "hits": [], "healing": 0, "tip": 0, "winner": -1}
	if caster >= 0:
		# Pay at cast start; settlement only pays the guaranteed booking income.
		mana[caster] = 0
		coins += CAST_TIP
		crowd_tips += CAST_TIP
		event.kind = "skill"
		event.tip = CAST_TIP
		var skill: Dictionary = heroes[caster].skill
		var amount := roundi(float(heroes[caster].attack) * float(skill.power))
		match skill.kind:
			"heal":
				event.healing = _heal(caster, roundi(float(heroes[caster].health) * float(skill.power)))
			"sweep":
				for target in survivors():
					if target != caster:
						event.hits.append(_hit(caster, target, amount))
			"strike", "drain":
				var hit := _hit(caster, _target_for(caster), amount)
				event.hits.append(hit)
				if skill.kind == "drain":
					event.healing = _heal(caster, hit.damage)
	else:
		var target := _target_for(attacker)
		var damage := maxi(1, int(heroes[attacker].attack) + rng.randi_range(-3, 3))
		event.hits.append(_hit(attacker, target, damage))
		mana[attacker] = mini(MANA_MAX, int(mana[attacker]) + MANA_ON_HIT)
		if health[target] > 0:
			mana[target] = mini(MANA_MAX, int(mana[target]) + MANA_ON_HURT)
		for id in [attacker, target]:
			if health[id] > 0 and mana[id] == MANA_MAX:
				pending_casts.append(id)
	var alive := survivors()
	if alive.size() == 1:
		active = false
		pending_casts.clear()
		last_winner = alive[0]
		coins += payout
		heroes[last_winner].wins += 1
		completed += 1
		event.winner = last_winner
	return event


func _next_attacker() -> int:
	while not turn_order.is_empty():
		var id: int = turn_order.pop_front()
		if health[id] > 0:
			return id
	# Each living hero gets one turn per round, in a random order.
	var remaining := survivors()
	while not remaining.is_empty():
		turn_order.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	return turn_order.pop_front()


func _target_for(attacker: int) -> int:
	var candidates := survivors()
	candidates.erase(attacker)
	var preference: String = heroes[attacker].target
	if preference == "revenge" and last_attacker.get(attacker, -1) in candidates:
		return last_attacker[attacker]
	if preference in ["attack", "health", "weak"]:
		var preferred: Array[int] = []
		var best := -INF
		for id in candidates:
			var score: float = heroes[id].attack if preference == "attack" else health[id]
			if preference == "weak":
				score = -score
			if score > best:
				best = score
				preferred.clear()
			if score == best:
				preferred.append(id)
		candidates = preferred
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _hit(attacker: int, target: int, amount: int) -> Dictionary:
	var damage := mini(int(health[target]), amount)
	health[target] -= damage
	last_attacker[target] = attacker
	return {"target": target, "damage": damage}


func _heal(id: int, amount: int) -> int:
	var restored := mini(int(heroes[id].health) - int(health[id]), amount)
	health[id] += restored
	return restored
