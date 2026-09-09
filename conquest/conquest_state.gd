extends RefCounted
## Campaign state and behavior. Authored Resources are read-only; live values live in s.
const SAVE := "user://conquest_v1.json"
signal gathering_changed
const DEFAULT_BALANCE = preload("res://conquest/data/default_balance.tres")
var balance: ConquestBalance
var spots: Dictionary = {}
var villagers: Dictionary = {}
var s: Dictionary
var completed: Array[String] = []
func _init(settings: ConquestBalance = DEFAULT_BALANCE) -> void:
	balance = settings
	s = {"gold":balance.starting_gold,"wood":balance.starting_wood,"food":balance.starting_food,"assignments":{},"gathering_progress":{},"gathering_initialized":false,"owned":0,"plots":0,"academy":false,"development":0,"warriors":balance.starting_warriors,"mages":0,"healing":false,"spell":"fireball","projects":{},"recovery":0.0,"battle":{},"last":Time.get_unix_time_from_system(),"result":""}
func income() -> float:
	var amount := balance.base_income + balance.development_income * int(s.development)
	for i in mini(int(s.owned), balance.encounters.size()): amount += balance.encounters[i].income
	return amount
func project(key: String) -> Dictionary:
	match key:
		"warriors": return {"name":"Train %d warriors" % balance.warrior_reward,"cost":balance.first_warrior_cost if int(s.warriors) == balance.starting_warriors else balance.warrior_cost,"duration":balance.first_warrior_duration if int(s.warriors) == balance.starting_warriors else balance.warrior_duration,"reward":"+%d permanent warriors" % balance.warrior_reward,"building":"barracks"}
		"mage": return {"name":"Train first mage","cost":balance.mage_cost,"duration":balance.mage_duration,"reward":"+1 mage and Fireball","building":"academy"}
		"healing": return {"name":"Learn healing","cost":balance.healing_cost,"duration":balance.healing_duration,"reward":"Unlock Healing; Fireball stays learned","building":"academy"}
	return {}
func start(key: String) -> bool:
	var p := project(key)
	if p.is_empty() or not s.battle.is_empty(): return false
	if s.projects.has(p.building) or float(s.gold) < p.cost: return false
	if p.building == "academy" and not s.academy: return false
	if key == "mage" and int(s.mages) > 0: return false
	if key == "healing" and (int(s.mages) == 0 or s.healing): return false
	s.gold -= p.cost
	s.projects[p.building] = {"key":key,"remaining":p.duration,"duration":p.duration,"cost":p.cost}
	return true
func build_academy() -> bool:
	if s.academy or int(s.plots) < balance.academy_plots or float(s.gold) < balance.academy_cost or not s.battle.is_empty(): return false
	s.gold -= balance.academy_cost
	s.plots -= balance.academy_plots
	s.academy = true
	return true
func develop() -> bool:
	if float(s.gold) < balance.development_cost or not s.battle.is_empty(): return false
	s.gold -= balance.development_cost
	s.development += 1
	return true
func equip(spell: String) -> bool:
	if not s.battle.is_empty() or int(s.mages) == 0: return false
	if spell != "fireball" and (spell != "healing" or not s.healing): return false
	s.spell = spell
	return true
func advance(now: float) -> void:
	var dt := maxf(0, now - float(s.last))
	s.last = maxf(now, float(s.last))
	s.gold += income() * dt / 60.0
	advance_gathering(dt)
	var working := dt
	if not s.battle.is_empty():
		var paused := minf(dt, float(s.battle.remaining))
		s.battle.remaining -= paused
		working -= paused
		if float(s.battle.remaining) <= 0: finish_battle()
	s.recovery = maxf(0, float(s.recovery) - working)
	for building in s.projects.keys():
		var p: Dictionary = s.projects[building]
		p.remaining -= working
		if float(p.remaining) <= 0:
			match p.key:
				"warriors": s.warriors += balance.warrior_reward
				"mage": s.mages = 1
				"healing": s.healing = true
			completed.append(building)
			s.projects.erase(building)
func simulate(index: int) -> Dictionary:
	var land: ConquestEncounter = balance.encounters[index]
	var hp := float(s.warriors) * balance.warrior_hp
	var maximum := hp
	var enemies: Array[float] = []
	for i in int(land.count): enemies.append(float(land.hp))
	var timeline: Array = []
	var dealt := 0.0
	var healed := 0.0
	for tick in balance.battle_ticks:
		var alive := 0
		for e in enemies:
			if e > 0: alive += 1
		if hp <= 0 or alive == 0: break
		var effect := ""
		var tick_healing := 0.0
		var enemy_hp_before := 0.0
		for enemy in enemies: enemy_hp_before += maxf(0, enemy)
		if int(s.mages) > 0 and tick % balance.spell_interval == 0:
			if s.spell == "fireball":
				effect = "fireball"
				for i in enemies.size():
					dealt += minf(maxf(enemies[i],0),balance.fireball_damage)
					enemies[i] -= balance.fireball_damage
			else:
				effect = "healing"
				var heal := minf(balance.healing_amount, maximum - hp)
				healed += heal
				tick_healing = heal
				hp += heal
		var damage := ceilf(hp / balance.warrior_hp) * balance.warrior_attack + int(s.mages) * balance.mage_attack
		for i in enemies.size():
			var hit := minf(maxf(enemies[i], 0), damage)
			enemies[i] -= hit
			damage -= hit
		alive = 0
		var enemy_hp := 0.0
		for e in enemies:
			if e > 0: alive += 1
			enemy_hp += maxf(0,e)
		var incoming := minf(hp, alive * float(land.attack))
		hp = maxf(0, hp - incoming)
		timeline.append({"hp":hp,"enemy_hp":enemy_hp,"alive":alive,"effect":effect,
			"enemy_damage":enemy_hp_before-enemy_hp,"ally_damage":incoming,"healing":tick_healing})
	var won := true
	for e in enemies:
		if e > 0: won = false
	var feedback := "Enemy formation defeated. Your entire army returns safely."
	if not won: feedback = "Frontline fell with %d enemies still standing. Add warriors for more frontline health%s." % [(timeline.back().alive if not timeline.is_empty() else land.count), " or equip learned Healing" if s.healing else "; the academy can teach Healing"]
	return {"won":won,"timeline":timeline,"feedback":feedback,"fire_damage":dealt,"healed":healed,"max_hp":maximum,"enemy_max":float(land.hp)*int(land.count),"enemy_count":land.count,"index":index,"remaining":balance.presentation_duration,"duration":balance.presentation_duration,"land_name":land.name}
func deploy() -> bool:
	if not s.battle.is_empty() or float(s.recovery) > 0 or int(s.owned) >= balance.encounters.size(): return false
	s.battle = simulate(int(s.owned))
	# Commit the reward together with the precomputed timeline, before showing combat.
	if s.battle.won:
		s.plots += balance.encounters[int(s.owned)].plots
		s.owned += 1
	return true
func finish_battle() -> void:
	if s.battle.is_empty(): return
	s.result = ("VICTORY  •  " if s.battle.won else "REGROUP  •  ") + str(s.battle.get("land_name", "Expedition")) + "\n" + s.battle.feedback + "\nFireball damage: %d   •   Health restored: %d\nArmy and land preserved. Training resumes during recovery." % [s.battle.fire_damage,s.battle.healed]
	s.battle = {}
	s.recovery = balance.recovery_duration
func save_game(path: String = SAVE) -> bool:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(s))
	f.flush()
	f.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
func load_game(path: String = SAVE) -> String:
	if not FileAccess.file_exists(path): return "Welcome, commander. %d warriors await your first expedition." % balance.starting_warriors
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("projects") or not data.has("last"): return "Save could not be read. A new expedition is ready."
	for key in s.keys():
		if data.has(key): s[key] = data[key]
	if not s.assignments is Dictionary: s.assignments = {}
	if not s.gathering_progress is Dictionary: s.gathering_progress = {}
	if not s.battle.is_empty():
		var index := int(s.battle.index)
		var land: ConquestEncounter = balance.encounters[index] if index >= 0 and index < balance.encounters.size() else null
		# The old save format always used a fourteen-second presentation.
		if not s.battle.has("duration"): s.battle.duration = 14.0
		if not s.battle.has("land_name"): s.battle.land_name = land.name if land != null else "Expedition"
		if not s.battle.has("enemy_count"): s.battle.enemy_count = land.count if land != null else int(s.battle.timeline[0].alive)
	# Closed time is not play time. Resume every timer from the saved remainder.
	s.last = Time.get_unix_time_from_system()
	completed.clear()
	var last_result := "\n".join(str(s.result).split("\n").slice(0,2))
	return "Welcome back • resumed where you left off.\n" + last_result

# The level supplies identities/settings, never positions or live Resource state.
func register_gathering(spot_definitions: Array, villager_definitions: Array) -> PackedStringArray:
	spots.clear()
	villagers.clear()
	var errors := PackedStringArray()
	var seen_spot_ids: Dictionary = {}
	for spot in spot_definitions:
		var id: String = spot.id
		if id.is_empty() or seen_spot_ids.has(id):
			errors.append("Resource spot ID is empty or duplicated: " + id)
			continue
		seen_spot_ids[id] = true
		if spot.settings == null or not spot.settings.is_valid() or spot.capacity < 1:
			errors.append("Invalid gathering settings/capacity: " + id)
			continue
		spots[id] = spot
	for villager in villager_definitions:
		var id: String = villager.id
		if id.is_empty() or villagers.has(id):
			errors.append("Villager ID is empty or duplicated: " + id)
			continue
		villagers[id] = villager
	var ids: Array = villagers.keys()
	ids.sort()
	var assignments: Dictionary = {}
	var progress: Dictionary = {}
	var occupancy: Dictionary = {}
	for id in ids:
		var target: String = s.assignments.get(id, "") if s.gathering_initialized else villagers[id].initial_spot
		if target.is_empty(): continue
		if not spots.has(target):
			errors.append("Missing resource spot for " + id + ": " + target)
			continue
		if occupancy.get(target, 0) >= spots[target].capacity: continue
		assignments[id] = target
		occupancy[target] = occupancy.get(target, 0) + 1
		var elapsed := float(s.gathering_progress.get(id, 0.0))
		progress[id] = clampf(elapsed, 0.0, spots[target].settings.cycle_seconds) if is_finite(elapsed) else 0.0
	s.assignments = assignments
	s.gathering_progress = progress
	s.gathering_initialized = true
	gathering_changed.emit()
	return errors

func assign_villager(id: String, target: String) -> bool:
	if not villagers.has(id) or (not target.is_empty() and not spots.has(target)): return false
	if s.assignments.get(id, "") == target: return true
	if not target.is_empty() and s.assignments.values().count(target) >= spots[target].capacity: return false
	# Settle elapsed work under the OLD assignment before transferring.
	advance(Time.get_unix_time_from_system())
	s.assignments.erase(id)
	s.gathering_progress.erase(id)
	if not target.is_empty():
		s.assignments[id] = target
		s.gathering_progress[id] = 0.0
	gathering_changed.emit()
	return true

func advance_gathering(delta: float) -> void:
	var paid := false
	for id in s.assignments:
		var target: String = s.assignments[id]
		if not villagers.has(id) or not spots.has(target): continue
		var settings: GatheringSettings = spots[target].settings
		var elapsed := float(s.gathering_progress.get(id, 0.0)) + delta
		var cycles := floori(elapsed / settings.cycle_seconds)
		s.gathering_progress[id] = fmod(elapsed, settings.cycle_seconds)
		if cycles > 0:
			s[settings.resource_type] += cycles * settings.yield_amount
			paid = true
	if paid: gathering_changed.emit()
