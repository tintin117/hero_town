extends RefCounted
## Session-only fight rules. UI and animation never decide rewards.

const BASE_INCOME := 100
const COINS_PER_VICTORY := 5

var heroes: Array[Dictionary] = [
	{"name": "Bram", "unit": "warrior", "red": false, "stars": 3, "health": 150, "attack": 17, "wins": 0},
	{"name": "Ivo", "unit": "lancer", "red": false, "stars": 3, "health": 132, "attack": 21, "wins": 0},
	{"name": "Nia", "unit": "archer", "red": false, "stars": 2, "health": 110, "attack": 18, "wins": 0},
	{"name": "Tuck", "unit": "monk", "red": false, "stars": 2, "health": 140, "attack": 13, "wins": 0},
	{"name": "Rook", "unit": "warrior", "red": true, "stars": 1, "health": 105, "attack": 12, "wins": 0},
]
var rng := RandomNumberGenerator.new()
var participants: Array[int] = []
var health: Dictionary = {}
var turn_order: Array[int] = []
var active := false
var coins := 0
var completed := 0
var payout := 0
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
	turn_order.clear()
	for id in participants:
		health[id] = int(heroes[id].health)
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
	var alive := survivors()
	# Each living hero gets one turn per round, in a random order.
	if turn_order.is_empty():
		var remaining := alive.duplicate()
		while not remaining.is_empty():
			turn_order.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	var attacker: int = turn_order.pop_front()
	while health[attacker] <= 0:
		if turn_order.is_empty():
			return step()
		attacker = turn_order.pop_front()
	alive.erase(attacker)
	var target: int = alive[rng.randi_range(0, alive.size() - 1)]
	var damage := maxi(1, int(heroes[attacker].attack) + rng.randi_range(-3, 3))
	health[target] = maxi(0, int(health[target]) - damage)
	var event := {"attacker": attacker, "target": target, "damage": damage, "winner": -1}
	alive = survivors()
	if alive.size() == 1:
		active = false
		last_winner = alive[0]
		coins += payout
		heroes[last_winner].wins += 1
		completed += 1
		event.winner = last_winner
	return event
