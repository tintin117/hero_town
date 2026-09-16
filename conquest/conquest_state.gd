extends RefCounted
## Independent prototype state. All durations are seconds; gold is the only resource.
const SAVE := "user://conquest_v1.json"
const DEFAULT_BALANCE = preload("res://conquest/default_balance.tres")
var balance: ConquestBalance
var lands: Array[ConquestLand]:
	get: return balance.lands
var s: Dictionary
var completed: Array[String] = []
func _init(tuning: ConquestBalance = DEFAULT_BALANCE) -> void:
	balance = tuning
	s = {"gold":balance.starting_gold,"owned":0,"plots":0,"academy":false,"development":0,"warriors":balance.starting_warriors,"initial_warriors":balance.starting_warriors,"mages":0,"healing":false,"spell":"fireball","projects":{},"recovery":0.0,"battle":{},"last":Time.get_unix_time_from_system(),"result":""}
func income() -> float:
	var amount := balance.base_income + balance.development_income * int(s.development)
	for i in mini(int(s.owned), lands.size()): amount += lands[i].income
	return amount
func project(key: String) -> Dictionary:
	match key:
		"warriors": return {"name":"Train two warriors","cost":balance.first_warrior_cost if int(s.warriors) == int(s.initial_warriors) else balance.warrior_cost,"duration":balance.first_warrior_seconds if int(s.warriors) == int(s.initial_warriors) else balance.warrior_seconds,"reward":"+2 permanent warriors","building":"barracks"}
		"mage": return {"name":"Train first mage","cost":balance.mage_cost,"duration":balance.mage_seconds,"reward":"+1 mage and Fireball","building":"academy"}
		"healing": return {"name":"Learn healing","cost":balance.healing_cost,"duration":balance.healing_seconds,"reward":"Unlock Healing; Fireball stays learned","building":"academy"}
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
	if s.academy or int(s.plots) < 1 or float(s.gold) < balance.academy_cost or not s.battle.is_empty(): return false
	s.gold -= balance.academy_cost
	s.plots -= 1
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
				"warriors": s.warriors += 2
				"mage": s.mages = 1
				"healing": s.healing = true
			completed.append(building)
			s.projects.erase(building)
func simulate(index: int) -> Dictionary:
	var land := lands[index]
	var hp := float(s.warriors) * balance.warrior_hp
	var maximum := hp
	var enemies: Array[float] = []
	for i in int(land.count): enemies.append(float(land.hp))
	var timeline: Array = []
	var dealt := 0.0
	var healed := 0.0
	for tick in 90:
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
		var damage := ceilf(hp / balance.warrior_hp) * balance.warrior_damage + int(s.mages) * balance.mage_damage
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
	if not won: feedback = "Frontline fell with %d enemies still standing. Add warriors for more frontline health%s." % [int(timeline.back().alive) if not timeline.is_empty() else land.count, " or equip learned Healing" if s.healing else "; the academy can teach Healing"]
	return {"won":won,"timeline":timeline,"feedback":feedback,"fire_damage":dealt,"healed":healed,"max_hp":maximum,"enemy_max":float(land.hp)*int(land.count),"index":index,"remaining":balance.presentation_seconds,"duration":balance.presentation_seconds,"warrior_hp":balance.warrior_hp,"land_name":land.name,"enemy_count":land.count}
func deploy() -> bool:
	if not s.battle.is_empty() or float(s.recovery) > 0 or int(s.owned) >= lands.size(): return false
	s.battle = simulate(int(s.owned))
	# Commit the reward together with the precomputed timeline, before showing combat.
	if s.battle.won:
		s.plots += lands[int(s.owned)].plots
		s.owned += 1
	return true
func finish_battle() -> void:
	if s.battle.is_empty(): return
	s.result = ("VICTORY  •  " if s.battle.won else "REGROUP  •  ") + str(s.battle.land_name) + "\n" + s.battle.feedback + "\nFireball damage: %d   •   Health restored: %d\nArmy and land preserved. Training resumes during recovery." % [s.battle.fire_damage,s.battle.healed]
	s.battle = {}
	s.recovery = balance.recovery_seconds
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
	if not data.has("initial_warriors"): s.initial_warriors = 3
	# Older saves predate authored tuning. Preserve their original battle pacing.
	if not s.battle.is_empty():
		var index := int(s.battle.index)
		if not s.battle.has("duration"): s.battle.duration = 14.0
		if not s.battle.has("warrior_hp"): s.battle.warrior_hp = 40.0
		# These are migration values from the original fixed three-land campaign.
		# Reading today's balance would change an already-simulated legacy battle.
		if not s.battle.has("land_name"): s.battle.land_name = ["Sunlit Meadow", "Amber Quarry", "River Watch"][index] if index >= 0 and index < 3 else "Expedition"
		if not s.battle.has("enemy_count"): s.battle.enemy_count = [2, 8, 4][index] if index >= 0 and index < 3 else 1
	# Closed time is not play time. Resume every timer from the saved remainder.
	s.last = Time.get_unix_time_from_system()
	completed.clear()
	var last_result := "\n".join(str(s.result).split("\n").slice(0,2))
	return "Welcome back • resumed where you left off.\n" + last_result
