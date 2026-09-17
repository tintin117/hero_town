class_name FarmFightState
extends RefCounted

const SAVE := "user://farm_fight_v1.json"
const DEFAULT_BALANCE = preload("res://data/companion/farm_fight_balance.tres")
const CLASSES := ["warrior", "monk", "archer", "lancer"]
const UPGRADES := ["power", "health", "spawn"]
var balance: FarmFightBalance
var simulation := BattleSimulation.new()
var s: Dictionary
var accumulator := 0.0
var rates := {"gold": 0.0, "wood": 0.0}
var spawn_positions: Dictionary = {}
var save_error := ""
var load_failed := false

func _init(tuning: FarmFightBalance = DEFAULT_BALANCE) -> void:
	balance = tuning
	s = {"version": 1, "gold": balance.starting_gold, "wood": balance.starting_wood,
		"farmers": balance.starting_farmers, "hired": 0, "efficiency": 0, "owned": 0,
		"assignments": {}, "research": {}, "towers": {}, "wave_remaining": balance.wave_seconds, "wave": 0}
	for id in CLASSES:
		s.research[id] = {"unlocked": id == "warrior", "power": 0, "health": 0, "spawn": 0}
	simulation.start_frontier(balance.tower_health, balance.enemy_cap)
	if balance.starting_tower: s.towers.warrior = {"remaining": spawn_seconds("warrior"), "recruit_remaining": 0.0}
	for i in mini(balance.starting_warriors, balance.hero_cap):
		spawn_hero("warrior")
		simulation.units.back().position = Vector2(-30 - i * 22, 0)
	# The first skirmish is already underway when the player arrives.
	spawn_wave()
	for unit in simulation.units:
		if unit.side == 1 and not unit.get("objective", false): unit.position = Vector2(45, 0)

func spot_id(land: int, resource: String) -> String:
	return "%d:%s" % [land, resource]

func assigned(land: int, resource: String) -> int:
	return int(s.assignments.get(spot_id(land, resource), 0))

func idle_farmers() -> int:
	var count := int(s.farmers)
	for value in s.assignments.values(): count -= int(value)
	return count

func spot_rate(land: int) -> float:
	return balance.production_per_second * (1.0 + land * balance.land_yield_growth) * (1.0 + int(s.efficiency) * balance.efficiency_per_rank)

func refresh_rates() -> void:
	rates = {"gold": 0.0, "wood": 0.0}
	for key: String in s.assignments:
		rates[key.get_slice(":", 1)] += int(s.assignments[key]) * spot_rate(int(key.get_slice(":", 0)))

func assign_farmer(land: int, resource: String, change: int) -> bool:
	if land < 0 or land > int(s.owned) or resource not in ["gold", "wood"] or change not in [-1, 1]: return false
	var count := assigned(land, resource)
	if change > 0 and (idle_farmers() <= 0 or count >= balance.spot_capacity): return false
	if count + change < 0: return false
	var key := spot_id(land, resource)
	s.assignments[key] = count + change
	if s.assignments[key] == 0: s.assignments.erase(key)
	refresh_rates()
	return true

func quote(action: String, id := "", node := "") -> Dictionary:
	match action:
		"farmer": return {"gold": balance.cost(balance.farmer_gold, int(s.hired)), "wood": 0.0}
		"efficiency": return {"gold": balance.cost(balance.efficiency_gold, int(s.efficiency)), "wood": balance.cost(balance.efficiency_wood, int(s.efficiency))}
	var hero := balance.hero(id)
	if hero == null: return {}
	match action:
		"unlock": return {"gold": hero.unlock_gold, "wood": 0.0}
		"build": return {"gold": hero.tower_gold, "wood": hero.tower_wood}
		"recruit": return {"gold": hero.recruit_gold, "wood": 0.0}
		"upgrade":
			if node not in UPGRADES: return {}
			return {"gold": balance.cost(hero.get(node + "_gold"), int(s.research[id][node])),
				"wood": balance.cost(hero.spawn_wood, int(s.research[id][node])) if node == "spawn" else 0.0}
	return {}

func action_error(action: String, id := "", node := "") -> String:
	var price := quote(action, id, node)
	if price.is_empty(): return "Unknown purchase"
	if action not in ["farmer", "efficiency"]:
		var research: Dictionary = s.research[id]
		if action == "unlock" and research.unlocked: return "Already unlocked"
		if action != "unlock" and not research.unlocked: return "Unlock this class in Research first"
		if action == "build" and s.towers.has(id): return "Tower already built"
		if action == "recruit":
			if not s.towers.has(id): return "Build this tower first"
			if simulation.living_class(id) >= balance.hero_cap: return "Hero capacity reached"
			if s.towers[id].get("recruit_remaining", 0.0) > 0: return "Reinforcement ready in %.0fs" % ceil(s.towers[id].recruit_remaining)
		if action == "upgrade" and node == "spawn" and spawn_seconds(id) <= balance.minimum_spawn_seconds: return "Maximum spawn speed reached"
	if s.gold < price.gold or s.wood < price.wood: return "Not enough gold or wood"
	return ""

func purchase(action: String, id := "", node := "") -> bool:
	if not action_error(action, id, node).is_empty(): return false
	var price := quote(action, id, node)
	s.gold -= price.gold
	s.wood -= price.wood
	match action:
		"farmer": s.farmers += 1; s.hired += 1
		"efficiency": s.efficiency += 1; refresh_rates()
		"unlock": s.research[id].unlocked = true
		"build": s.towers[id] = {"remaining": spawn_seconds(id), "recruit_remaining": 0.0}
		"recruit":
			spawn_hero(id)
			s.towers[id].recruit_remaining = balance.recruit_seconds
		"upgrade":
			var old_interval := spawn_seconds(id)
			s.research[id][node] += 1
			if node == "spawn" and s.towers.has(id):
				s.towers[id].remaining *= spawn_seconds(id) / old_interval
			var stats := hero_stats(id)
			for unit in simulation.units:
				if unit.side != 0 or unit.army != id: continue
				unit.hp = unit.hp / unit.max_hp * stats.hp
				unit.max_hp = stats.hp
				unit.damage = stats.damage
	return true

func hire_farmer() -> bool: return purchase("farmer")
func build_tower(id: String) -> bool: return purchase("build", id)
func buy_reinforcement(id: String) -> bool: return purchase("recruit", id)

func spawn_seconds(id: String) -> float:
	return maxf(balance.minimum_spawn_seconds, balance.hero(id).spawn_seconds / (1.0 + int(s.research[id].spawn) * balance.spawn_per_rank))

func hero_stats(id: String) -> Dictionary:
	var hero := balance.hero(id)
	return {"hp": hero.health * (1.0 + int(s.research[id].health) * balance.stat_per_rank),
		"damage": hero.power * (1.0 + int(s.research[id].power) * balance.stat_per_rank)}

func spawn_hero(id: String) -> void:
	var hero := balance.hero(id)
	var stats := hero_stats(id)
	var slot: int = CLASSES.find(id)
	var pos: Vector2 = spawn_positions.get(id, Vector2(-510 + slot * 90, 18 + (slot % 2) * 10))
	simulation.spawn_hero({"army": id, "type": id, "class": hero.combat_class, "visual": id,
		"rarity": 0, "position": pos, "home": pos, "hp": stats.hp, "max_hp": stats.hp,
		"damage": stats.damage, "interval": hero.attack_seconds, "specialty": 1.0,
		"guard_strength": 0.25, "range": hero.attack_range, "ability": hero.ability, "side": 0})

func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not is_finite(delta) or delta <= 0: return events
	accumulator += delta
	while accumulator + 0.0000001 >= BattleSimulation.STEP:
		accumulator = maxf(0, accumulator - BattleSimulation.STEP)
		events.append_array(_step())
	return events

func _step() -> Array[Dictionary]:
	var dt := BattleSimulation.STEP
	s.gold += rates.gold * dt
	s.wood += rates.wood * dt
	simulation.events.clear()
	for id: String in s.towers:
		s.towers[id].recruit_remaining = maxf(0, float(s.towers[id].get("recruit_remaining", 0.0)) - dt)
		s.towers[id].remaining = maxf(0, float(s.towers[id].remaining) - dt)
		if s.towers[id].remaining <= 0 and simulation.living_class(id) < balance.hero_cap:
			spawn_hero(id)
			s.towers[id].remaining = spawn_seconds(id)
	s.wave_remaining -= dt
	if s.wave_remaining <= 0:
		spawn_wave()
		s.wave_remaining += balance.wave_seconds
	var events: Array[Dictionary] = simulation.events.duplicate()
	simulation.step(dt)
	events.append_array(simulation.events)
	if simulation.tower().hp <= 0:
		s.owned += 1
		s.wave = 0
		s.wave_remaining = balance.wave_seconds
		simulation.start_frontier(balance.tower_health * balance.strength(int(s.owned) + 1), balance.enemy_cap)
		events.append({"kind": "conquered", "land": int(s.owned)})
	return events

func spawn_wave() -> void:
	var land := int(s.owned) + 1
	var strength := balance.strength(land)
	var pattern := balance.wave_patterns[(land - 1) % balance.wave_patterns.size()]
	for i in balance.wave_size:
		var visual: String = pattern[(int(s.wave) * balance.wave_size + i) % pattern.size()]
		simulation.spawn_enemy({"unit": visual, "hp": balance.enemy_health * strength,
			"damage": balance.enemy_power * strength, "interval": balance.enemy_attack_seconds}, Vector2(450 + (i / 5) * 12, (i % 5 - (balance.wave_size - 1) / 2.0) * 14))
	s.wave += 1

static func encode(value: Variant) -> Variant:
	if value is Vector2: return {"v2": [value.x, value.y]}
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = encode(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(encode(item))
		return result
	return value

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if _vector(value): return Vector2(value.v2[0], value.v2[1])
		var result := {}
		for key in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(decode(item))
		return result
	return value

func snapshot() -> Dictionary:
	return encode({"campaign": s, "combat": simulation.frontier_snapshot(), "accumulator": accumulator})

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or not data.get("campaign") is Dictionary or not data.get("combat") is Dictionary: return false
	var state: Dictionary = data.campaign
	for key in ["gold", "wood", "farmers", "hired", "efficiency", "owned", "wave_remaining", "wave"]:
		if not _number(state.get(key)) or state[key] < 0: return false
	if state.get("version") != 1 or state.farmers < 1 or state.hired > state.farmers: return false
	for key in ["farmers", "hired", "efficiency", "owned", "wave"]:
		if state[key] != int(state[key]): return false
	for key in ["assignments", "research", "towers"]:
		if not state.get(key) is Dictionary: return false
	var used := 0
	for key: String in state.assignments:
		var parts := key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or int(parts[0]) < 0 or int(parts[0]) > state.owned or parts[1] not in ["gold", "wood"]: return false
		var count: Variant = state.assignments[key]
		if not _number(count) or count < 0 or count > balance.spot_capacity or count != int(count): return false
		used += int(count)
	if used > state.farmers: return false
	for id in CLASSES:
		var research: Variant = state.research.get(id)
		if not research is Dictionary or not research.get("unlocked") is bool: return false
		for node in UPGRADES:
			if not _number(research.get(node)) or research[node] < 0 or research[node] != int(research[node]): return false
			if not research.unlocked and research[node] > 0: return false
	if not state.research.warrior.unlocked or state.research.size() != CLASSES.size(): return false
	for id in state.towers:
		if id not in CLASSES or not state.research[id].unlocked: return false
		if not state.towers[id] is Dictionary or not _number(state.towers[id].get("remaining")) or state.towers[id].remaining < 0: return false
		if not _number(state.towers[id].get("recruit_remaining", 0.0)) or state.towers[id].get("recruit_remaining", 0.0) < 0: return false
	if not _number(data.get("accumulator")) or data.accumulator < 0 or data.accumulator >= BattleSimulation.STEP: return false
	var combat: Dictionary = data.combat
	if not _number(combat.get("elapsed")) or not _number(combat.get("next_id")): return false
	if combat.elapsed < 0 or combat.next_id < 1 or combat.next_id != int(combat.next_id): return false
	for key in ["units", "projectiles", "warnings"]:
		if not combat.get(key) is Array: return false
	if combat.units.size() > balance.hero_cap * 4 + balance.enemy_cap + 1: return false
	var ids := {}
	var objectives := 0
	var counts := {"warrior": 0, "monk": 0, "archer": 0, "lancer": 0, "enemy": 0}
	for unit in combat.units:
		if not unit is Dictionary: return false
		for key in ["id", "side", "class", "rarity", "hp", "max_hp", "damage", "interval", "range", "specialty", "cooldown", "ability_timer", "guard_time", "guard", "target", "think", "action_until", "skill_count"]:
			if not _number(unit.get(key)): return false
		for key in ["army", "visual", "ability", "action_name"]:
			if not unit.get(key) is String: return false
		for key in ["moving", "facing_right"]:
			if not unit.get(key) is bool: return false
		if not _vector(unit.get("position")) or not _vector(unit.get("home")): return false
		if int(unit.side) not in [0, 1] or unit.side != int(unit.side) or unit.max_hp <= 0 or unit.hp < 0 or unit.hp > unit.max_hp or unit.interval <= 0: return false
		if unit.rarity != 0 or unit.class != int(unit.class) or int(unit.class) not in [-1, 0, 1, 2, 3]: return false
		if unit.id != int(unit.id) or unit.id < 0 or unit.id >= combat.next_id or ids.has(int(unit.id)): return false
		ids[int(unit.id)] = true
		if unit.side == 0 and unit.army not in CLASSES: return false
		if not unit.get("objective", false) is bool: return false
		if unit.get("objective", false):
			if unit.side != 1 or unit.visual != "tower": return false
			objectives += 1
		else:
			if unit.visual not in CLASSES: return false
			if unit.hp > 0: counts[unit.army if unit.side == 0 else "enemy"] += 1
	if objectives != 1: return false
	for id in CLASSES:
		if counts[id] > balance.hero_cap: return false
	if counts.enemy > balance.enemy_cap: return false
	for shot in combat.projectiles:
		if not shot is Dictionary or not _vector(shot.get("position")): return false
		for key in ["source", "target", "damage", "life", "side"]:
			if not _number(shot.get(key)): return false
		if not shot.get("source_data") is Dictionary or not _number(shot.source_data.get("side")) or int(shot.source_data.side) not in [0, 1] or not shot.source_data.get("army") is String: return false
	# Frontier enemies do not currently create delayed warning attacks.
	return combat.warnings.is_empty()

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	return value is Dictionary and value.size() == 1 and value.get("v2") is Array and value.v2.size() == 2 and _number(value.v2[0]) and _number(value.v2[1])

func load_game(path := SAVE) -> String:
	load_failed = false
	if not FileAccess.file_exists(path): return "Your Warrior is holding the line. Assign farmers to begin."
	var data: Variant = read_json(path)
	var recovered := false
	if not valid_save(data):
		data = read_json(path + ".bak")
		recovered = true
	if not valid_save(data):
		load_failed = true
		return "Save could not be read. Original files preserved; use New Game to restart."
	data = decode(data)
	s = data.campaign
	for id in s.towers:
		s.towers[id].recruit_remaining = float(s.towers[id].get("recruit_remaining", 0.0))
	for key in ["version", "farmers", "hired", "efficiency", "owned", "wave"]: s[key] = int(s[key])
	for key in s.assignments: s.assignments[key] = int(s.assignments[key])
	for id in CLASSES:
		for node in UPGRADES: s.research[id][node] = int(s.research[id][node])
	accumulator = data.accumulator
	simulation.restore_frontier(data.combat)
	simulation.enemy_cap = balance.enemy_cap
	refresh_rates()
	return "Recovered backup. Progress resumed." if recovered else "Welcome back. Progress resumed where you left off."

func save_game(path := SAVE) -> bool:
	if load_failed: return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: save_error = "Could not write save"; return false
	file.store_string(JSON.stringify(snapshot(), "", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: save_error = "Could not finish save"; return false
	if FileAccess.file_exists(path) and valid_save(read_json(path)):
		if DirAccess.copy_absolute(path, path + ".bak") != OK: save_error = "Could not back up save"; return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: save_error = "Could not replace save"; return false
	save_error = ""
	return true

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
