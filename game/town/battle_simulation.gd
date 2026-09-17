class_name BattleSimulation
extends RefCounted

## One combat model for the visible game and headless balance/regression tests.
## Rendering consumes events; it never decides damage, rewards, or victory.
const STEP := 0.05
var units: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var events: Array[Dictionary] = []
var reports: Dictionary = {}
var elapsed: float = 0.0
var limit: float = 60.0
var outcome: int = -1 # -1 ongoing, 0 defeat (including mutual defeat), 1 victory
var _next_id: int = 0
var continuous := false
var bounds := Rect2(-570, -80, 1130, 170)
var enemy_cap := TownRules.MAX_ENEMIES
var _unit_by_id: Dictionary = {}

static func army_units(records: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		var data: BuildingData = GameData.BUILDINGS[record.type]
		var hero: HeroData = GameData.hero_for(record.type, TownRules.rarity(record))
		var stats := TownRules.stats(hero, record)
		var home := TownRules.cell_position(Vector2i(record.cell[0], record.cell[1]))
		for member in TownRules.crew(record, data):
			var pos := home + Vector2(26 + (member / 3) * 22, (member % 3 - 1) * 16)
			result.append({"army": record.id, "type": record.type, "member": member,
				"class": int(data.hero_class), "visual": data.visual_unit, "rarity": TownRules.rarity(record),
				"position": pos, "home": pos, "hp": stats.hp, "max_hp": stats.hp,
				"damage": stats.damage, "interval": stats.interval, "specialty": stats.specialty,
				"guard_strength": stats.guard_strength, "specialization": record.get("specialization", "balanced"),
				"range": [52.0, 78.0, 245.0, 225.0][int(data.hero_class)],
				"ability": hero.ability, "side": 0})
	return result

func setup(records: Array, stage: StageData) -> void:
	continuous = false
	bounds = Rect2(-570, -80, 1130, 170)
	enemy_cap = TownRules.MAX_ENEMIES
	_unit_by_id.clear()
	units.clear()
	projectiles.clear()
	warnings.clear()
	events.clear()
	reports.clear()
	elapsed = 0
	outcome = -1
	_next_id = 0
	limit = stage.time_limit
	for unit in army_units(records):
		_append_unit(unit)
		reports[unit.army] = {"damage": 0.0, "healing": 0.0, "casualties": 0}
	for index in stage.enemies.size():
		spawn_enemy(stage.enemies[index], Vector2(360 + (index / 5) * 44, (index % 5 - 2) * 34))

func _append_unit(unit: Dictionary) -> void:
	unit.id = _next_id
	_next_id += 1
	unit.cooldown = 0.25 + (unit.id % 4) * 0.08
	unit.ability_timer = 4.0 + (unit.id % 4) * 0.2
	unit.guard_time = 0.0
	unit.guard = 0.0
	unit.target = -1
	unit.think = 0.0
	unit.moving = false
	unit.action_until = 0.0
	unit.action_name = "attack"
	unit.skill_count = 0
	unit.facing_right = unit.side == 0
	units.append(unit)
	_unit_by_id[unit.id] = unit
	events.append({"kind": "spawn", "unit": unit.id})

func spawn_enemy(data: Dictionary, pos: Vector2) -> bool:
	if alive_count(1) >= enemy_cap: return false
	var visual: String = data.get("unit", "warrior")
	_append_unit({"army": "", "class": -1, "visual": visual, "rarity": 0,
		"position": pos, "home": pos, "hp": float(data.hp), "max_hp": float(data.hp),
		"damage": float(data.damage), "interval": float(data.get("interval", 1.8)), "specialty": 1.0,
		"range": 240.0 if visual == "archer" else 65.0, "ability": data.get("ability", ""),
		"boss": data.get("boss", ""), "side": 1})
	return true

func alive_count(side: int) -> int:
	var count := 0
	for unit in units:
		if unit.side == side and unit.hp > 0 and not unit.get("objective", false): count += 1
	return count

func find_unit(id: int) -> Dictionary:
	return _unit_by_id.get(id, {})

func start_frontier(hp: float, cap: int) -> void:
	continuous = true
	bounds = Rect2(-570, -30, 1130, 58)
	enemy_cap = cap
	outcome = -1
	projectiles.clear()
	warnings.clear()
	events.clear()
	units = units.filter(func(u: Dictionary): return u.side == 0 and u.hp > 0)
	_unit_by_id.clear()
	for unit in units:
		unit.position = unit.home
		unit.target = -1
		_unit_by_id[unit.id] = unit
	_append_unit({"army": "", "class": -1, "visual": "tower", "rarity": 0,
		"position": Vector2(520, 0), "home": Vector2(520, 0), "hp": hp, "max_hp": hp,
		"damage": 0.0, "interval": 1.0, "range": 0.0, "specialty": 1.0,
		"ability": "", "side": 1, "objective": true})

func tower() -> Dictionary:
	for unit in units:
		if unit.get("objective", false): return unit
	return {}

func spawn_hero(data: Dictionary) -> void:
	_append_unit(data)

func living_class(id: String) -> int:
	var count := 0
	for unit in units:
		if unit.side == 0 and unit.hp > 0 and unit.army == id: count += 1
	return count

func restore_frontier(data: Dictionary) -> void:
	continuous = true
	elapsed = data.elapsed
	_next_id = int(data.next_id)
	units.assign(data.units)
	projectiles.assign(data.projectiles)
	warnings.assign(data.warnings)
	events.clear()
	_unit_by_id.clear()
	for unit in units:
		for key in ["id", "side", "class", "rarity", "target", "skill_count"]: unit[key] = int(unit[key])
		_unit_by_id[unit.id] = unit
	for shot in projectiles:
		for key in ["source", "target", "side"]: shot[key] = int(shot[key])
		shot.source_data.side = int(shot.source_data.side)

func frontier_snapshot() -> Dictionary:
	return {"elapsed": elapsed, "next_id": _next_id, "units": units.duplicate(true),
		"projectiles": projectiles.duplicate(true), "warnings": warnings.duplicate(true)}

func step(delta: float = STEP) -> void:
	events.clear()
	if outcome != -1: return
	elapsed += delta
	# Resolve projectiles/warnings first, allowing a mutual defeat to be observed.
	_update_projectiles(delta)
	_update_warnings(delta)
	for unit in units:
		unit.moving = false
		if unit.hp <= 0: continue
		if unit.get("objective", false): continue
		if continuous and unit.side == 1 and unit.position.x <= bounds.position.x + 12:
			unit.hp = 0
			events.append({"kind": "death", "unit": unit.id, "position": unit.position})
			continue
		unit.guard_time = maxf(0.0, unit.guard_time - delta)
		unit.cooldown -= delta
		unit.ability_timer -= delta
		unit.think -= delta
		if unit.side == 0 and unit.class == 3 and unit.cooldown <= 0:
			var patient := injured_ally(unit)
			if not patient.is_empty():
				heal(patient, unit.damage * 3.0 * unit.specialty, unit)
				unit.cooldown = unit.interval
				unit.action_until = elapsed + 0.4
				unit.action_name = "attack"
				continue
		var target := find_unit(int(unit.target))
		if unit.think <= 0 or target.is_empty() or target.hp <= 0:
			target = nearest_opponent(unit)
			unit.target = target.get("id", -1)
			unit.think = 0.25
		if target.is_empty():
			if continuous and unit.side == 1: _move(unit, {"position": Vector2(bounds.position.x, unit.position.y)}, delta)
			continue
		if absf(target.position.x - unit.position.x) > 1.0:
			unit.facing_right = target.position.x > unit.position.x
		var distance: float = unit.position.distance_to(target.position)
		if unit.ability_timer <= 0 and distance < 300.0:
			_use_specialty(unit, target)
			unit.ability_timer = 7.0 if unit.side == 0 else 8.0
		if distance > unit.range:
			_move(unit, target, delta)
		elif unit.cooldown <= 0:
			unit.cooldown = unit.interval
			unit.action_until = elapsed + 0.35
			unit.action_name = "attack"
			if unit.range > 150:
				shoot(unit, target, unit.damage)
			else:
				damage(target, unit.damage, unit)
	if continuous:
		# Continuous sessions cannot retain a growing list of corpses like short rounds.
		for index in range(units.size() - 1, -1, -1):
			var unit := units[index]
			if unit.hp <= 0 and not unit.get("objective", false):
				_unit_by_id.erase(int(unit.id))
				units.remove_at(index)
	elif alive_count(0) == 0:
		outcome = 0
	elif alive_count(1) == 0:
		outcome = 1
	elif elapsed >= limit:
		outcome = 0

func nearest_opponent(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score := INF
	for candidate in units:
		if candidate.side == unit.side or candidate.hp <= 0: continue
		var distance: float = unit.position.distance_squared_to(candidate.position)
		if distance < score:
			score = distance
			best = candidate
	return best

func injured_ally(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var ratio := 1.0
	for candidate in units:
		if candidate.side != unit.side or candidate.hp <= 0: continue
		if unit.position.distance_to(candidate.position) > 280.0: continue
		var current: float = candidate.hp / candidate.max_hp
		if current < ratio - 0.01:
			ratio = current
			best = candidate
	return best

func _move(unit: Dictionary, target: Dictionary, delta: float) -> void:
	var seek: Vector2 = (target.position - unit.position).normalized()
	var separation := Vector2.ZERO
	for ally in units:
		if ally.id == unit.id or ally.side != unit.side or ally.hp <= 0: continue
		var offset: Vector2 = unit.position - ally.position
		var dist := offset.length()
		if dist > 0.01 and dist < 22:
			separation += offset / dist * (1.0 - dist / 22.0)
	var speed := 62.0 if unit.side == 1 else 82.0
	unit.position += (seek + separation * 0.7).normalized() * speed * delta
	unit.position = unit.position.clamp(bounds.position, bounds.end)
	unit.moving = true

func damage(target: Dictionary, amount: float, source: Dictionary) -> float:
	if source.is_empty() or target.is_empty() or target.hp <= 0 or target.side == source.side: return 0.0
	var reduction: float = target.guard if target.guard_time > 0 else 0.0
	var applied := minf(target.hp, maxf(0, amount * (1.0 - reduction)))
	target.hp -= applied
	if source.side == 0 and reports.has(source.army): reports[source.army].damage += applied
	events.append({"kind": "hit", "unit": target.id, "amount": applied, "position": target.position, "side": target.side})
	if target.hp <= 0:
		if target.side == 0 and reports.has(target.army): reports[target.army].casualties += 1
		events.append({"kind": "death", "unit": target.id, "position": target.position})
	return applied

func heal(target: Dictionary, amount: float, source: Dictionary) -> float:
	if target.is_empty() or target.hp <= 0 or target.side != source.side: return 0.0
	var applied := minf(target.max_hp - target.hp, maxf(0, amount))
	target.hp += applied
	if source.side == 0 and reports.has(source.army): reports[source.army].healing += applied
	events.append({"kind": "heal", "unit": target.id, "amount": applied, "position": target.position})
	return applied

func shoot(source: Dictionary, target: Dictionary, amount: float) -> void:
	projectiles.append({"source": source.id, "target": target.id, "position": source.position,
		"damage": amount, "life": 2.5, "side": source.side,
		"source_data": {"side": source.side, "army": source.army}})

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot := projectiles[index]
		shot.life -= delta
		var target := find_unit(int(shot.target))
		if target.is_empty() or target.hp <= 0 or shot.life <= 0:
			projectiles.remove_at(index)
			continue
		var offset: Vector2 = target.position - shot.position
		if offset.length() <= 420.0 * delta:
			damage(target, shot.damage, shot.get("source_data", find_unit(int(shot.source))))
			projectiles.remove_at(index)
		else:
			shot.position += offset.normalized() * 420.0 * delta

func _use_specialty(unit: Dictionary, target: Dictionary) -> void:
	var ability: String = unit.ability
	unit.skill_count += 1
	if unit.side == 0:
		unit.action_name = "guard" if ability == "guard" else "attack"
		match ability:
			"guard":
				for ally in units:
					if ally.side == 0 and ally.hp > 0 and unit.position.distance_to(ally.position) <= 150:
						var previous: float = ally.guard if ally.guard_time > 0 else 0.0
						ally.guard = maxf(previous, minf(0.65, float(unit.get("guard_strength", 0.25)) * unit.specialty))
						ally.guard_time = 3.0
				events.append({"kind": "guard", "position": unit.position})
			"volley":
				var targets := _opponents_in_range(unit, 310)
				for index in mini(3, targets.size()): shoot(unit, targets[index], unit.damage * unit.specialty)
			"pierce":
				var end: Vector2 = unit.position + (target.position - unit.position).normalized() * 170.0
				_line_damage(unit, unit.position, end, unit.damage * 1.5 * unit.specialty, 36.0)
				events.append({"kind": "pierce", "position": unit.position, "end": end})
		unit.action_until = elapsed + 0.4
	elif not ability.is_empty():
		if ability == "warlord":
			ability = "summon" if unit.skill_count % 2 == 0 else "cleave"
		var end: Vector2 = target.position
		warnings.append({"source": unit.id, "kind": ability, "start": unit.position,
			"position": end, "remaining": 1.1, "radius": 95.0})
		events.append({"kind": "warning", "position": end, "ability": ability})

func _opponents_in_range(unit: Dictionary, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for other in units:
		if other.side != unit.side and other.hp > 0 and unit.position.distance_to(other.position) <= radius:
			result.append(other)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
	return result

func _line_damage(source: Dictionary, start: Vector2, end: Vector2, amount: float, width: float) -> void:
	for target in units:
		if target.side == source.side or target.hp <= 0: continue
		var closest := Geometry2D.get_closest_point_to_segment(target.position, start, end)
		if closest.distance_to(target.position) <= width: damage(target, amount, source)

func _update_warnings(delta: float) -> void:
	for index in range(warnings.size() - 1, -1, -1):
		var warning := warnings[index]
		warning.remaining -= delta
		var source := find_unit(int(warning.source))
		if source.is_empty() or source.hp <= 0:
			warnings.remove_at(index)
			continue
		if warning.remaining > 0: continue
		warnings.remove_at(index)
		var multiplier := 1.5 if not source.get("boss", "").is_empty() else 0.9
		match warning.kind:
			"cleave":
				for target in units:
					if target.side != source.side and target.hp > 0 and target.position.distance_to(warning.position) <= warning.radius:
						damage(target, source.damage * multiplier, source)
			"volley":
				var targets := _opponents_in_range(source, 1200)
				targets.sort_custom(func(a: Dictionary, b: Dictionary): return a.position.x < b.position.x)
				for i in mini(3, targets.size()): shoot(source, targets[i], source.damage * multiplier)
			"charge":
				_line_damage(source, warning.start, warning.position, source.damage * multiplier, 40)
				source.position = warning.position
			"summon":
				for i in 3:
					spawn_enemy({"unit": "warrior", "hp": source.max_hp * 0.035, "damage": source.damage * 0.32}, Vector2(470, -40 + i * 40))
		source.action_until = elapsed + 0.45
		events.append({"kind": "blast", "position": warning.position})
