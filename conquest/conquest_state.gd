extends RefCounted
## Independent prototype state. All durations are seconds; gold is the only resource.
const SAVE := "user://conquest_v1.json"
const RECOVERY := 120.0
const PRESENTATION := 14.0
const LANDS := [
	{"name":"Sunlit Meadow", "income":5, "plots":1, "count":2, "hp":22.0, "attack":3.0, "hint":"A small scouting party guards fertile land."},
	{"name":"Amber Quarry", "income":5, "plots":1, "count":8, "hp":24.0, "attack":2.4, "hint":"Eight clustered raiders. Fireball strikes the entire group."},
	{"name":"River Watch", "income":10, "plots":2, "count":4, "hp":130.0, "attack":9.0, "hint":"Four armored guards. A deeper frontline and healing can outlast them."}
]
var s: Dictionary
var completed: Array[String] = []
func _init() -> void:
	s = {"gold":200.0,"owned":0,"plots":0,"academy":false,"development":0,"warriors":3,"mages":0,"healing":false,"spell":"fireball","projects":{},"recovery":0.0,"battle":{},"last":Time.get_unix_time_from_system(),"result":""}
func income() -> float:
	var amount := 10.0 + 5.0 * int(s.development)
	for i in int(s.owned): amount += LANDS[i].income
	return amount
func project(key: String) -> Dictionary:
	match key:
		"warriors": return {"name":"Train two warriors","cost":20 if int(s.warriors) == 3 else 40,"duration":30.0 if int(s.warriors) == 3 else 180.0,"reward":"+2 permanent warriors","building":"barracks"}
		"mage": return {"name":"Train first mage","cost":30,"duration":60.0,"reward":"+1 mage and Fireball","building":"academy"}
		"healing": return {"name":"Learn healing","cost":60,"duration":300.0,"reward":"Unlock Healing; Fireball stays learned","building":"academy"}
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
	if s.academy or int(s.plots) < 1 or float(s.gold) < 60 or not s.battle.is_empty(): return false
	s.gold -= 60
	s.plots -= 1
	s.academy = true
	return true
func develop() -> bool:
	if float(s.gold) < 60 or not s.battle.is_empty(): return false
	s.gold -= 60
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
	var land: Dictionary = LANDS[index]
	var hp := float(s.warriors) * 40.0
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
		if int(s.mages) > 0 and tick % 3 == 0:
			if s.spell == "fireball":
				effect = "fireball"
				for i in enemies.size():
					dealt += minf(maxf(enemies[i],0),12.0)
					enemies[i] -= 12.0
			else:
				effect = "healing"
				var heal := minf(40.0, maximum - hp)
				healed += heal
				hp += heal
		var damage := ceilf(hp / 40.0) * 4.0 + int(s.mages) * 4.0
		for i in enemies.size():
			var hit := minf(maxf(enemies[i], 0), damage)
			enemies[i] -= hit
			damage -= hit
		alive = 0
		var enemy_hp := 0.0
		for e in enemies:
			if e > 0: alive += 1
			enemy_hp += maxf(0,e)
		hp = maxf(0, hp - alive * float(land.attack))
		timeline.append({"hp":hp,"enemy_hp":enemy_hp,"alive":alive,"effect":effect})
	var won := true
	for e in enemies:
		if e > 0: won = false
	var feedback := "Enemy formation defeated. Your entire army returns safely."
	if not won: feedback = "Frontline fell with %d enemies still standing. Add warriors for more frontline health%s." % [timeline.back().alive, " or equip learned Healing" if s.healing else "; the academy can teach Healing"]
	return {"won":won,"timeline":timeline,"feedback":feedback,"fire_damage":dealt,"healed":healed,"max_hp":maximum,"enemy_max":float(land.hp)*int(land.count),"index":index,"remaining":PRESENTATION}
func deploy() -> bool:
	if not s.battle.is_empty() or float(s.recovery) > 0 or int(s.owned) >= LANDS.size(): return false
	s.battle = simulate(int(s.owned))
	# Commit the reward together with the precomputed timeline, before showing combat.
	if s.battle.won:
		s.plots += LANDS[int(s.owned)].plots
		s.owned += 1
	return true
func finish_battle() -> void:
	if s.battle.is_empty(): return
	s.result = ("VICTORY  •  " if s.battle.won else "REGROUP  •  ") + LANDS[int(s.battle.index)].name + "\n" + s.battle.feedback + "\nFireball damage: %d   •   Health restored: %d\nArmy and land preserved. Training resumes during recovery." % [s.battle.fire_damage,s.battle.healed]
	s.battle = {}
	s.recovery = RECOVERY
func save_game(path: String = SAVE) -> bool:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(s))
	f.flush()
	f.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
func load_game(path: String = SAVE) -> String:
	if not FileAccess.file_exists(path): return "Welcome, commander. Three warriors await your first expedition."
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("projects") or not data.has("last"): return "Save could not be read. A new expedition is ready."
	for key in s.keys():
		if data.has(key): s[key] = data[key]
	var gold := float(s.gold)
	var troops := int(s.warriors) + int(s.mages)
	var had_healing: bool = s.healing
	advance(Time.get_unix_time_from_system())
	# Keep gains and the last outcome/feedback within the footer; detailed battle
	# statistics remain in the saved result and the immediate postbattle screen.
	var last_result := "\n".join(str(s.result).split("\n").slice(0,2))
	return "While you were away: +%d gold, +%d troops%s.\n%s" % [int(float(s.gold)-gold), int(s.warriors)+int(s.mages)-troops, ", Healing learned" if s.healing and not had_healing else "",last_result]
