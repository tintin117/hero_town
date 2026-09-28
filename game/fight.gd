extends RefCounted
## Fight and estate rules. UI and animation never decide rewards or purchases.

const TownGrid := preload("res://game/town_grid.gd")
const REST_DURATION := 60.0
const INJURY_DURATION := 180.0
const DEFEAT_LIMIT := 3
const BENCH_DECAY_INTERVAL := 60.0
const TRAINING_INTERVAL := 30.0
const TRAINING_XP := 5
const VICTORY_INCOME_CAP := 50
const BUILDING_COSTS := {
	"training": [250, 150000, 1000000], "infirmary": [450, 100000, 1800000],
	"hall": [200, 350, 900000], "tavern": [100, 300000, 7000000],
}
const FIGHTER_COSTS := [1500, 700000, 1200000]
const AUTO_FILL_COST := 6000
const RECRUIT_COSTS := [0, 0, 100, 150, 250, 400, 350000, 500000]
# Fixed recommendations, also used by the seeded economy check. No time gates.
const MILESTONES := [
	["recruit", 2], ["tavern", 1], ["hall", 1], ["recruit", 3], ["training", 1], ["recruit", 4],
	["hall", 2], ["recruit", 5], ["infirmary", 1], ["fighters", 1], ["seats", 1], ["auto", 1],
	["training", 2], ["infirmary", 2], ["fighters", 2], ["tavern", 2], ["seats", 2],
	["hall", 3], ["recruit", 6], ["recruit", 7], ["training", 3], ["fighters", 3],
	["infirmary", 3], ["tavern", 3],
]
const BASE_INCOME := 100
const COINS_PER_VICTORY := 5
const COINS_PER_LEVEL := 5
const ARENA_CAPACITIES := [100, 150, 200]
const ARENA_UPGRADE_COSTS := [5500, 600000]
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
const DASH_DISTANCE := 110.0
const DASH_DURATION := 0.22
const APPROACH_COOLDOWN := 4.5
const ESCAPE_COOLDOWN := 12.0
const APPROACH_RANGE := 200.0
const ESCAPE_RANGE := 100.0
const PUSHBACK_DISTANCE := 65.0
const PUSHBACK_DURATION := 0.22
const OVERTIME_AFTER := 60.0

# Short exchanges: dashes and skill pushback create breathing room between hits.
var heroes: Array[Dictionary] = [
	{"name": "Bram", "unit": "warrior", "red": false, "level": 1, "xp": 0, "health": 225, "attack": 17, "wins": 0,
		"ranged": false, "skill": {"name": "Heavy Strike", "kind": "strike", "power": 2.0, "description": "Deal 2x attack damage to the nearest enemy within 45 units."}},
	{"name": "Ivo", "unit": "lancer", "red": false, "level": 1, "xp": 0, "health": 198, "attack": 21, "wins": 0,
		"ranged": false, "skill": {"name": "Sweep", "kind": "sweep", "power": 1.0, "description": "Deal attack damage to every enemy within a 90-unit circle."}},
	{"name": "Nia", "unit": "archer", "red": false, "level": 1, "xp": 0, "health": 165, "attack": 18, "wins": 0,
		"ranged": true, "skill": {"name": "Snipe", "kind": "strike", "power": 2.5, "description": "Deal 2.5x attack damage to the nearest enemy within 160 units."}},
	{"name": "Tuck", "unit": "monk", "red": false, "level": 1, "xp": 0, "health": 210, "attack": 13, "wins": 0,
		"ranged": false, "skill": {"name": "Second Wind", "kind": "heal", "power": 0.2, "description": "Restore 20% of maximum HP to yourself."}},
	{"name": "Rook", "unit": "warrior", "red": true, "level": 1, "xp": 0, "health": 158, "attack": 12, "wins": 0,
		"ranged": false, "skill": {"name": "Drain", "kind": "drain", "power": 1.5, "description": "Deal 1.5x attack damage within 45 units. Heal by actual damage dealt."}},
]
var rest_remaining: Array[float] = []
var injury_remaining: Array[float] = []
var defeat_strain: Array[int] = []
var bench_elapsed: Array[float] = []
var injury_order: Array[int] = []
var next_injury_order := 1
var training_elapsed: Dictionary = {}
var restaurant_cooldown := 0.0
# Management changes are separate from the combat event stream.
var management_revision := 0
var grid := TownGrid.new()
var building_levels := {"training": 0, "infirmary": 0, "hall": 0, "tavern": 0}
var fighter_tier := 0
var auto_fill_owned := false
var auto_fill_enabled := false
var intro_seen := false
var tavern_payout := 0
var settled_tavern := 0
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
var dash_cooldowns: Dictionary = {}
var motions: Dictionary = {}
var pursuit_until: Dictionary = {}
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


func _init() -> void:
	for template in [[1, "Aldric"], [2, "Vera"], [3, "Oswin"]]:
		var hero: Dictionary = heroes[template[0]].duplicate(true)
		hero.name = template[1]
		hero.red = true
		heroes.append(hero)
	for id in range(heroes.size()):
		heroes[id].owned = id < 2
		heroes[id].stamina = 10
		rest_remaining.append(0.0)
		injury_remaining.append(0.0)
		defeat_strain.append(0)
		bench_elapsed.append(0.0)
		injury_order.append(0)


func max_stamina() -> int:
	return 10 + int(building_levels.training) * 5


func recovery_duration() -> float:
	return REST_DURATION


func roster_capacity() -> int:
	return [3, 5, 6, 8][building_levels.hall]


func owned_count() -> int:
	return heroes.filter(func(hero: Dictionary) -> bool: return hero.owned).size()


func fighter_capacity() -> int:
	return 2 + fighter_tier


func upgrade_level(id: String) -> int:
	match id:
		"seats": return arena_tier
		"fighters": return fighter_tier
		"auto": return int(auto_fill_owned)
	return int(building_levels.get(id, -1))


func upgrade_cost(id: String) -> int:
	var level := upgrade_level(id)
	var costs: Array = BUILDING_COSTS.get(id, [])
	match id:
		"seats": costs = ARENA_UPGRADE_COSTS
		"fighters": costs = FIGHTER_COSTS
		"auto": costs = [AUTO_FILL_COST]
	return costs[level] if level >= 0 and level < costs.size() else 0


func purchase_upgrade(id: String, cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var cost := upgrade_cost(id)
	if cost <= 0 or coins < cost:
		return false
	if building_levels.has(id) and building_levels[id] == 0 and not grid.can_place(id, cell):
		return false
	coins -= cost
	match id:
		"seats": arena_tier += 1
		"fighters": fighter_tier += 1
		"auto":
			auto_fill_owned = true
			auto_fill_enabled = true
		_:
			if building_levels[id] == 0:
				grid.buildings[id] = {"cell": cell, "size": TownGrid.BUILDINGS[id].size}
			building_levels[id] += 1
			if id == "training":
				for hero_id in range(heroes.size()):
					if rest_remaining[hero_id] <= 0.0:
						heroes[hero_id].stamina += 5
	management_revision += 1
	return true


func can_recruit(id: int) -> bool:
	return id >= 2 and id < heroes.size() and not heroes[id].owned and owned_count() < roster_capacity() and coins >= RECRUIT_COSTS[id]


func recruit(id: int) -> bool:
	if not can_recruit(id):
		return false
	coins -= RECRUIT_COSTS[id]
	heroes[id].owned = true
	heroes[id].stamina = max_stamina()
	management_revision += 1
	return true


func ready(id: int) -> bool:
	return availability(id).ready


func availability(id: int) -> Dictionary:
	var result := {"ready": false, "state": "unowned", "reason": "Not recruited", "seconds": 0.0}
	if id < 0 or id >= heroes.size() or not heroes[id].owned:
		return result
	if active and id in participants:
		result.merge({"state": "fighting", "reason": "In the current fight"}, true)
	elif injury_remaining[id] > 0.0:
		result.merge({"state": "injured", "reason": "Recovering from injury", "seconds": injury_remaining[id] / (hospital_rate() if id in hospital_patients() else 1.0)}, true)
	elif rest_remaining[id] > 0.0 or heroes[id].stamina <= 0:
		result.merge({"state": "resting", "reason": "Resting after exhaustion", "seconds": rest_remaining[id]}, true)
	elif training_elapsed.has(id):
		result.merge({"state": "training", "reason": "Training in the Gym", "seconds": TRAINING_INTERVAL - float(training_elapsed[id])}, true)
	else:
		result.merge({"ready": true, "state": "ready", "reason": "Ready"}, true)
	return result


func hospital_capacity() -> int:
	return int(building_levels.infirmary)


func hospital_rate() -> float:
	return 1.0 + float(building_levels.infirmary)


func _injury_queue() -> Array[int]:
	var queue: Array[int] = []
	for id in range(heroes.size()):
		if heroes[id].owned and injury_remaining[id] > 0.0:
			queue.append(id)
	queue.sort_custom(func(a: int, b: int) -> bool: return injury_order[a] < injury_order[b] if injury_order[a] != injury_order[b] else a < b)
	return queue


func hospital_patients() -> Array[int]:
	return _injury_queue().slice(0, hospital_capacity())


func hospital_waiting() -> Array[int]:
	return _injury_queue().slice(hospital_capacity())


func training_capacity() -> int:
	return int(building_levels.training)


func training_reason(id: int, booked: Array[int] = []) -> String:
	if id < 0 or id >= heroes.size() or not heroes[id].owned:
		return "Recruit this hero first"
	if training_elapsed.has(id):
		return "Already training"
	if training_capacity() == 0:
		return "Build a Gym first"
	if training_elapsed.size() >= training_capacity():
		return "All Gym slots are occupied"
	if heroes[id].level >= LEVEL_CAP:
		return "Already at maximum level"
	if not ready(id):
		return availability(id).reason
	if id in booked:
		return "Unbook this hero before training"
	var reserves := 0
	for other in range(heroes.size()):
		if other != id and heroes[other].owned and injury_remaining[other] <= 0.0 and not training_elapsed.has(other):
			reserves += 1
	if reserves < 2:
		return "Keep two healthy heroes outside the Gym"
	return ""


func training_assign(id: int, booked: Array[int] = []) -> bool:
	if not training_reason(id, booked).is_empty():
		return false
	training_elapsed[id] = 0.0
	management_revision += 1
	return true


func training_recall(id: int) -> bool:
	if not training_elapsed.has(id):
		return false
	training_elapsed.erase(id)
	management_revision += 1
	return true


func meal_cooldown_duration() -> float:
	return [30.0, 30.0, 20.0, 10.0][building_levels.tavern]


func meal_quote(id: int, kind: String) -> Dictionary:
	var quote := {"allowed": false, "reason": "", "cost": 20 if kind == "light" else 50, "restored": 0, "cooldown": restaurant_cooldown}
	if kind not in ["light", "feast"]:
		quote.reason = "Unknown meal"
	elif building_levels.tavern == 0:
		quote.reason = "Build a Restaurant first"
	elif id < 0 or id >= heroes.size() or not heroes[id].owned:
		quote.reason = "Recruit this hero first"
	elif active and id in participants:
		quote.reason = "Wait until this fight ends"
	elif injury_remaining[id] > 0.0:
		quote.reason = "Food cannot heal an injury"
	elif training_elapsed.has(id):
		quote.reason = "Recall this hero from the Gym first"
	elif heroes[id].stamina >= max_stamina():
		quote.reason = "Stamina is already full"
	else:
		quote.restored = mini(5 if kind == "light" else max_stamina(), max_stamina() - int(heroes[id].stamina))
		if restaurant_cooldown > 0.0:
			quote.reason = "Restaurant is preparing the next meal"
		elif coins < int(quote.cost):
			quote.reason = "Not enough gold"
		else:
			quote.allowed = true
	return quote


func feed(id: int, kind: String) -> bool:
	var quote := meal_quote(id, kind)
	if not quote.allowed:
		return false
	coins -= int(quote.cost)
	heroes[id].stamina += int(quote.restored)
	rest_remaining[id] = 0.0
	restaurant_cooldown = meal_cooldown_duration()
	management_revision += 1
	return true


func next_lineup(preferred: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for id in preferred:
		if ready(id) and id not in result and result.size() < fighter_capacity():
			result.append(id)
	if not auto_fill_owned or not auto_fill_enabled:
		return result
	for id in ready_lineup():
		if id not in result and result.size() < fighter_capacity():
			result.append(id)
	return result


func ready_lineup() -> Array[int]:
	var candidates: Array[int] = []
	for id in range(heroes.size()):
		if ready(id):
			candidates.append(id)
	candidates.sort_custom(func(a: int, b: int) -> bool: return heroes[a].stamina > heroes[b].stamina if heroes[a].stamina != heroes[b].stamina else a < b)
	return candidates.slice(0, fighter_capacity())


func upgrade_benefit(id: String) -> String:
	var level := upgrade_level(id)
	match id:
		"training": return "Stamina: %d → %d / training slots: %d → %d" % [max_stamina(), mini(25, max_stamina() + 5), level, mini(3, level + 1)] if level < 3 else "25 stamina / 3 training slots / 5 XP each 30s"
		"infirmary": return "Beds: %d → %d / injury recovery: x%d → x%d" % [level, mini(3, level + 1), level + 1, mini(4, level + 2)] if level < 3 else "3 beds / injury recovery x4"
		"hall": return "Roster space: %d → %d / recruits sold separately" % [roster_capacity(), [5, 6, 8, 8][level]] if level < 3 else "8 roster spaces / maximum"
		"tavern": return "Sales: +%d → +%d gold per fight / meals every %ds" % [arena_capacity() * [0, 1, 3, 6][level], arena_capacity() * [1, 3, 6, 6][level], [30, 20, 10, 10][level]] if level < 3 else "Sales: +%d gold per fight / meals every 10s" % (arena_capacity() * 6)
		"seats": return "Seats: %d → %d / more fight income and sales" % [arena_capacity(), mini(200, arena_capacity() + 50)]
		"fighters": return "Fighters: %d → %d / takes effect next fight" % [fighter_capacity(), mini(5, fighter_capacity() + 1)]
		"auto": return "Automatically replace tired bookings with ready recruits"
	return ""


func next_milestone() -> Dictionary:
	for step in MILESTONES:
		var id: String = step[0]
		var target: int = step[1]
		if id == "recruit":
			if not heroes[target].owned:
				if owned_count() >= roster_capacity():
					return {"id": "hall", "target": building_levels.hall + 1, "name": "Recruitment Hall / more roster space", "cost": upgrade_cost("hall")}
				return {"id": id, "target": target, "name": "Recruit " + heroes[target].name, "cost": RECRUIT_COSTS[target]}
		elif upgrade_level(id) < target:
			var title: String = {"seats": "Spectator seats", "fighters": "Fighter capacity", "auto": "Auto-fill"}.get(id, "")
			if title.is_empty():
				title = TownGrid.BUILDINGS[id].name
			return {"id": id, "target": target, "name": title + (" / level %d" % target if id != "auto" else ""), "cost": upgrade_cost(id)}
	return {}


func valid_lineup(lineup: Array[int]) -> bool:
	if lineup.size() < 2 or lineup.size() > fighter_capacity():
		return false
	var unique := {}
	for id in lineup:
		if id < 0 or id >= heroes.size() or unique.has(id):
			return false
		if not heroes[id].owned:
			return false
		unique[id] = true
	return true


func lineup_rest(lineup: Array[int]) -> float:
	var remaining := 0.0
	for id in lineup:
		if id >= 0 and id < rest_remaining.size():
			remaining = maxf(remaining, rest_remaining[id])
			remaining = maxf(remaining, injury_remaining[id] / (hospital_rate() if id in hospital_patients() else 1.0))
	return remaining


func income_for(lineup: Array[int]) -> int:
	return int(income_breakdown(lineup).get("guaranteed", 0))


func income_breakdown(lineup: Array[int]) -> Dictionary:
	if not valid_lineup(lineup):
		return {}
	var victories := 0
	var levels := 0
	for id in lineup:
		victories += mini(int(heroes[id].wins), VICTORY_INCOME_CAP)
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
	return purchase_upgrade("seats")


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
	if active or not valid_lineup(lineup) or lineup_rest(lineup) > 0.0:
		return false
	for id in lineup:
		if not ready(id):
			return false
	participants = lineup.duplicate()
	for id in participants:
		bench_elapsed[id] = 0.0
	for state in [health, mana, battle_stats, positions, velocities, targets, target_timers, cooldowns, pauses, dash_cooldowns, motions, pursuit_until]:
		state.clear()
	pending_casts.clear()
	action_order.clear()
	crowd_tips = 0
	excitement = 0.0
	elapsed = 0.0
	settled_income = 0
	settled_tavern = 0
	tavern_payout = arena_capacity() * [0, 1, 3, 6][building_levels.tavern]
	var remaining := participants.duplicate()
	while not remaining.is_empty():
		action_order.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	for slot in range(action_order.size()):
		var id := action_order[slot]
		# Freeze combat stats for this fight; XP is settled afterward.
		battle_stats[id] = stats_for(id)
		health[id] = battle_stats[id].health
		mana[id] = 0
		positions[id] = Vector2.from_angle(-PI / 2.0 + TAU * slot / participants.size()) * ARENA_RADIUS * 0.72
		velocities[id] = Vector2.ZERO
		targets[id] = -1
		target_timers[id] = 0.0
		cooldowns[id] = rng.randf_range(0.0, 0.3)
		pauses[id] = 0.0
		dash_cooldowns[id] = 0.5
	payout = income_for(participants)
	last_winner = -1
	active = true
	management_revision += 1
	return true


func survivors() -> Array[int]:
	var alive: Array[int] = []
	for id in participants:
		if health[id] > 0:
			alive.append(id)
	return alive


func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if delta <= 0.0 or not is_finite(delta):
		return events
	_advance_management(delta)
	if not active:
		return events
	var time_gain := minf(delta, maxf(0.0, EXCITEMENT_TIME_CAP - elapsed))
	elapsed += delta
	excitement = minf(EXCITEMENT_MAX, excitement + time_gain * EXCITEMENT_PER_SECOND)
	for id in survivors():
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
		pauses[id] = maxf(0.0, pauses[id] - delta)
		dash_cooldowns[id] = maxf(0.0, dash_cooldowns[id] - delta)
		target_timers[id] -= delta
		if target_timers[id] <= 0.0 or health.get(targets[id], 0) <= 0:
			_target_for(id)
			target_timers[id] = TARGET_INTERVAL
	_move(delta, events)
	for id in action_order:
		_queue_ready(id)
	_resolve_casts(events)
	for id in action_order:
		if not active:
			break
		if health[id] <= 0 or mana[id] == MANA_MAX or cooldowns[id] > 0.0 or _is_dashing(id):
			continue
		var target := _target_for(id)
		if not _in_range(id, target, attack_range(id)):
			continue
		cooldowns[id] = ATTACK_INTERVAL
		events.append(_act(id, false))
		# A hit's attacker and surviving defender cast before another normal hit.
		_resolve_casts(events)
	return events


func _advance_management(delta: float) -> void:
	if restaurant_cooldown > 0.0:
		restaurant_cooldown = maxf(0.0, restaurant_cooldown - delta)
		if restaurant_cooldown == 0.0:
			management_revision += 1
	for id in range(heroes.size()):
		if not heroes[id].owned or (active and id in participants):
			continue
		if rest_remaining[id] > 0.0:
			rest_remaining[id] = maxf(0.0, rest_remaining[id] - delta)
			if rest_remaining[id] == 0.0:
				heroes[id].stamina = max_stamina()
				management_revision += 1
		if injury_remaining[id] <= 0.0 and defeat_strain[id] > 0:
			bench_elapsed[id] += delta
			while bench_elapsed[id] >= BENCH_DECAY_INTERVAL and defeat_strain[id] > 0:
				bench_elapsed[id] -= BENCH_DECAY_INTERVAL
				defeat_strain[id] -= 1
				management_revision += 1
			if defeat_strain[id] == 0:
				bench_elapsed[id] = 0.0
		elif injury_remaining[id] > 0.0 or defeat_strain[id] == 0:
			bench_elapsed[id] = 0.0
	# Split large deltas at treatment completions, so a newly available bed
	# accelerates the next patient for the remainder of the same time step.
	var remaining_time := delta
	while remaining_time > 0.000001:
		var queue := _injury_queue()
		if queue.is_empty():
			break
		var patients := queue.slice(0, hospital_capacity())
		var step := remaining_time
		for id in queue:
			var rate := hospital_rate() if id in patients else 1.0
			step = minf(step, injury_remaining[id] / rate)
		for id in queue:
			var rate := hospital_rate() if id in patients else 1.0
			injury_remaining[id] = maxf(0.0, injury_remaining[id] - step * rate)
			if injury_remaining[id] < 0.000001:
				injury_remaining[id] = 0.0
				defeat_strain[id] = 0
				injury_order[id] = 0
				bench_elapsed[id] = 0.0
				management_revision += 1
		remaining_time = maxf(0.0, remaining_time - step)
	for key in training_elapsed.keys():
		var id := int(key)
		training_elapsed[id] = float(training_elapsed[id]) + delta
		while float(training_elapsed[id]) >= TRAINING_INTERVAL:
			training_elapsed[id] = float(training_elapsed[id]) - TRAINING_INTERVAL
			_award_xp(id, TRAINING_XP)
			management_revision += 1
			if heroes[id].level >= LEVEL_CAP:
				training_elapsed.erase(id)
				break


func _record_defeat(id: int) -> void:
	defeat_strain[id] = mini(DEFEAT_LIMIT, defeat_strain[id] + 1)
	bench_elapsed[id] = 0.0
	if defeat_strain[id] == DEFEAT_LIMIT:
		injury_remaining[id] = INJURY_DURATION
		injury_order[id] = next_injury_order
		next_injury_order += 1
	management_revision += 1


func attack_range(id: int) -> float:
	return RANGED_RANGE if heroes[id].ranged else MELEE_RANGE


func _move(delta: float, events: Array[Dictionary]) -> void:
	var before := positions.duplicate()
	var alive := survivors()
	for id in alive:
		var target: int = targets[id]
		if not motions.has(id) and pauses[id] <= 0.0 and target >= 0:
			_try_dash(id, before, events)
		if motions.has(id):
			var motion: Dictionary = motions[id]
			motion.elapsed = minf(motion.duration, motion.elapsed + delta)
			var progress: float = motion.elapsed / motion.duration
			if motion.kind == "pushback":
				progress = 1.0 - pow(1.0 - progress, 2)
			positions[id] = motion.origin.lerp(motion.destination, progress).limit_length(ARENA_RADIUS)
			if motion.elapsed >= motion.duration:
				motions.erase(id)
				target_timers[id] = 0.0
			continue
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
	# ponytail: pairwise separation suffices for five heroes; revisit for large crowds.
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


func _is_dashing(id: int) -> bool:
	return motions.has(id) and motions[id].kind != "pushback"


func _try_dash(id: int, before: Dictionary, events: Array[Dictionary]) -> void:
	if dash_cooldowns[id] > 0.0:
		return
	var target: int = targets[id]
	var offset: Vector2 = before[target] - before[id]
	var distance := offset.length()
	var destination: Vector2 = before[id]
	var kind := "approach"
	if heroes[id].ranged:
		# Escape only from a close opponent actively pursuing this hero.
		var threat := -1
		var nearest := ESCAPE_RANGE
		for opponent in survivors():
			var gap: float = before[id].distance_to(before[opponent])
			if opponent != id and targets[opponent] == id and gap <= nearest:
				threat = opponent
				nearest = gap
		if threat < 0:
			return
		var away: Vector2 = (before[id] - before[threat]).normalized()
		if away.is_zero_approx():
			away = Vector2.RIGHT
		var clearance := INF
		for opponent in survivors():
			if opponent != id:
				clearance = minf(clearance, before[id].distance_to(before[opponent]))
		var best := clearance + 10.0
		# Five candidate directions suffice in the obstacle-free circular arena.
		for angle in [0.0, PI / 3, -PI / 3, PI / 2, -PI / 2]:
			var candidate: Vector2 = (before[id] + away.rotated(angle) * DASH_DISTANCE).limit_length(ARENA_RADIUS)
			if candidate.distance_to(before[id]) < 40.0:
				continue
			var safety := INF
			for opponent in survivors():
				if opponent != id:
					safety = minf(safety, candidate.distance_to(before[opponent]))
			if safety > best:
				best = safety
				destination = candidate
		kind = "escape"
	elif distance > MELEE_RANGE + 25.0 and distance <= APPROACH_RANGE:
		destination = before[id] + offset.normalized() * minf(DASH_DISTANCE, distance - MELEE_RANGE + 4.0)
	if destination.is_equal_approx(before[id]):
		return
	destination = destination.limit_length(ARENA_RADIUS)
	motions[id] = {"kind": kind, "origin": before[id], "destination": destination, "elapsed": 0.0, "duration": DASH_DURATION}
	dash_cooldowns[id] = ESCAPE_COOLDOWN if heroes[id].ranged else APPROACH_COOLDOWN
	if not heroes[id].ranged:
		# Finish the chase instead of switching to another melee hero after an escape.
		pursuit_until[id] = elapsed + APPROACH_COOLDOWN
	var event := _action_event(id, "move")
	event.move_kind = kind
	event.destination = destination
	event.duration = DASH_DURATION
	events.append(event)


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
		if _is_dashing(id):
			pending_casts.append(id)
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


func _action_event(attacker: int, kind: String) -> Dictionary:
	return {"kind": kind, "attacker": attacker,
		"origin": positions[attacker], "radius": 0.0, "hits": [], "healing": 0, "tip": 0,
		"excitement_gain": 0.0, "time": elapsed, "winner": -1, "progression": [],
		"coins": coins, "crowd_tips": crowd_tips, "excitement": excitement}


func _act(attacker: int, casting: bool) -> Dictionary:
	var target := _target_for(attacker)
	var event := _action_event(attacker, "skill" if casting else "attack")
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
		# Resolve every hit first, then push survivors from the snapshotted impact.
		for hit in event.hits:
			if health[hit.target] > 0:
				var direction: Vector2 = (hit.position - event.origin).normalized()
				if direction.is_zero_approx():
					direction = Vector2.RIGHT
				hit.push_to = (hit.position + direction * PUSHBACK_DISTANCE).limit_length(ARENA_RADIUS)
				motions[hit.target] = {"kind": "pushback", "origin": hit.position, "destination": hit.push_to,
					"elapsed": 0.0, "duration": PUSHBACK_DURATION}
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
		motions.clear()
		pursuit_until.clear()
		last_winner = alive[0]
		settled_income = income_with_excitement(excitement)
		settled_tavern = tavern_payout
		coins += settled_income + settled_tavern
		heroes[last_winner].wins += 1
		completed += 1
		event.winner = last_winner
		for id in participants:
			heroes[id].stamina -= 1
			if heroes[id].stamina == 0:
				rest_remaining[id] = recovery_duration()
			if id != last_winner:
				_record_defeat(id)
			velocities[id] = Vector2.ZERO
			event.progression.append(_award_xp(id, XP_PER_FIGHT + (XP_WIN_BONUS if id == last_winner else 0)))
		management_revision += 1
	# Snapshots let the UI consume several same-frame actions in their reward order.
	event.coins = coins
	event.crowd_tips = crowd_tips
	event.excitement = excitement
	return event


func _target_for(attacker: int) -> int:
	var pursued: int = targets.get(attacker, -1)
	if pursuit_until.get(attacker, 0.0) > elapsed and health.get(pursued, 0) > 0:
		return pursued
	pursuit_until.erase(attacker)
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


func overtime_multiplier() -> float:
	# Mirror healers otherwise sustain forever. Ordinary short matches are unchanged.
	return 1.0 + maxf(0.0, elapsed - OVERTIME_AFTER) * 0.1


func _hit(target: int, amount: int) -> Dictionary:
	var damage := mini(int(health[target]), roundi(amount * overtime_multiplier()))
	health[target] -= damage
	if health[target] == 0:
		motions.erase(target)
		pursuit_until.erase(target)
	return {"target": target, "damage": damage, "position": positions[target]}


func _heal(id: int, amount: int) -> int:
	var restored := mini(int(battle_stats[id].health) - int(health[id]), amount)
	health[id] += restored
	return restored
