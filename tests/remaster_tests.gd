extends Node

var failures: int = 0
var checks: int = 0
var initial: Dictionary

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("TEST: " + message)

func reset_state() -> void:
	GameState.deserialize(initial)
	GameState.persistence_enabled = false

func _ready() -> void:
	if not GameState.is_test_session():
		push_error("Tests require -- --test to protect the player save.")
		get_tree().quit(1)
		return
	initial = GameState.serialize(1000.0)
	await get_tree().process_frame
	_run()
	print("REMASTER TESTS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _run() -> void:
	check(GameData.STAGES.size() == 20, "20 authored stages")
	for type: String in TownRules.ARMY_TYPES:
		for rarity in 5:
			check(GameData.hero_for(type, rarity) != null, "All four classes have all five rarities")
	var placed: Dictionary = GameState.place_building("barracks", Vector2i(4, 1))
	check(placed.ok, "First barracks can be placed")
	check(GameState.gold == 50, "Placement charged once")
	check(not GameState.place_building("barracks", Vector2i(4, 1)).ok, "Occupied tile rejected")
	var record: Dictionary = GameState.get_building(placed.id)
	check(TownRules.crew(record, GameData.BUILDINGS.barracks) == 3, "Warrior initial crew is three")
	check(GameState.purchase_research(placed.id, "damage_1").ok, "First research affordable")
	check(not GameState.purchase_research(placed.id, "damage_1").ok, "Duplicate purchase rejected")
	check(not GameState.purchase_research(placed.id, "rarity_1").ok, "Rarity gate enforced")
	GameState.set_reorganizing(true)
	check(GameState.refund_research(placed.id).gold == 50, "Exact research refund")
	check(GameState.refund_research(placed.id).gold == 0, "Refund cannot be duplicated")
	var sim := BattleSimulation.new()
	sim.setup(GameState.buildings, GameData.STAGES[1])
	while sim.outcome == -1: sim.step()
	check(sim.outcome == 1, "Starter army wins stage one")
	print("Starter battle: %.2fs" % sim.elapsed)
	var round_id: int = GameState.begin_battle()
	check(GameState.settle_battle(round_id, 1, true, sim.elapsed).ok, "Victory settled")
	var balance: int = GameState.gold
	check(not GameState.settle_battle(round_id, 1, true, sim.elapsed).ok, "Victory cannot pay twice")
	check(GameState.gold == balance, "Duplicate settlement changes no gold")
	check(GameState.offline_reward(1000, 1100).gold == 0, "Clock rollback earns zero")
	check(GameState.offline_reward(100000, 1000).seconds == 28800, "Offline cap is eight hours")
	check(GameState.valid_save(GameState.serialize(1000)), "Generated save validates")
	_transactions()
	_combat()
	_save_and_offline()
	_progression()
	_director_controls()

func _transactions() -> void:
	reset_state()
	GameState.cleared_stage = 20
	GameState.gold = 100000
	var expected := [3, 2, 1, 2]
	for index in 4:
		var type: String = TownRules.ARMY_TYPES[index]
		var placed: Dictionary = GameState.place_building(type, Vector2i(index + 1, 0))
		check(placed.ok, "Each army type can be constructed")
		var record := GameState.get_building(placed.id)
		check(TownRules.crew(record, GameData.BUILDINGS[type]) == expected[index], "Authored initial crew")
		check(not GameState.purchase_research(placed.id, "health_2").ok, "Training prerequisite enforced")
		for rarity in range(1, 5):
			check(GameState.purchase_research(placed.id, "rarity_%d" % rarity).ok, "Sequential promotion succeeds")
		check(TownRules.crew(record, GameData.BUILDINGS[type]) == expected[index], "Promotion preserves crew")
		for rank in range(1, 7 - expected[index]):
			check(GameState.purchase_research(placed.id, "crew_%d" % rank).ok, "Crew node adds a soldier")
		check(TownRules.crew(record, GameData.BUILDINGS[type]) == 6, "Crew cap is six")
		check(not GameState.purchase_research(placed.id, "crew_6").ok, "Invalid extra crew rejected")
		var hero: HeroData = GameData.hero_for(type, 4)
		var old_interval: float = TownRules.stats(hero, record).interval
		GameState.purchase_research(placed.id, "haste_1")
		var new_interval: float = TownRules.stats(hero, record).interval
		check(new_interval < old_interval and is_equal_approx(new_interval, old_interval / 1.15), "Haste reduces actual interval")
		check(TownRules.stats(hero, record) == TownRules.stats(hero, record), "Stat derivation never stacks twice")
	for index in 4: check(GameState.place_building("barracks", Vector2i(index + 1, 2)).ok, "Expanded slots available")
	check(not GameState.place_building("barracks", Vector2i(7, 1)).ok, "Eight-army cap enforced")
	check(GameState.get_building("army_005").research.is_empty(), "Duplicate class has independent research")
	GameState.phase = "BATTLE"
	check(not GameState.refund_research("army_001").ok, "Refund locked in battle")
	GameState.phase = "PREPARE"
	GameState.set_reorganizing(true)
	GameState.refund_research("army_001")
	check(GameState.samples.is_empty(), "Refund invalidates measured earnings")
	check(not GameState.get_building("army_002").research.is_empty(), "Refund preserves other armies")
	reset_state()
	check(not GameState.place_building("mage_tower", Vector2i(1, 1)).ok, "Army stage unlock enforced")
	check(not GameState.place_building("barracks", Vector2i(0, 1)).ok, "Town Hall tile reserved")
	check(not GameState.place_building("barracks", Vector2i(8, 1)).ok, "Battlefield placement rejected")

func _combat() -> void:
	reset_state()
	GameState.cleared_stage = 20
	GameState.gold = 100000
	for index in 4: GameState.place_building(TownRules.ARMY_TYPES[index], Vector2i(2, index % 3) if index < 3 else Vector2i(3, 1))
	var sim := BattleSimulation.new()
	sim.setup(GameState.buildings, GameData.STAGES[5])
	var warrior: Dictionary = sim.units[0]
	var enemy: Dictionary = sim.units.back()
	var cleric: Dictionary = {}
	var ranger: Dictionary = {}
	var lancer: Dictionary = {}
	for unit in sim.units:
		if unit.class == 3: cleric = unit
		if unit.class == 2: ranger = unit
		if unit.class == 1: lancer = unit
	warrior.hp -= 20
	check(sim.heal(warrior, 100, cleric) == 20, "Healing clamps at max HP")
	check(sim.heal(enemy, 100, cleric) == 0, "Healing rejects enemies")
	check(sim.damage(warrior, 10, ranger) == 0, "Friendly fire rejected")
	warrior.guard = 0.25
	warrior.guard_time = 3
	check(sim.damage(warrior, 20, enemy) == 15, "Guard reduces incoming damage")
	warrior.hp = 0
	check(sim.heal(warrior, 100, cleric) == 0, "Healing does not revive casualties")
	warrior.hp = warrior.max_hp
	warrior.guard_time = 0
	cleric.position = warrior.position
	warrior.hp -= 30
	check(sim.injured_ally(cleric).id == warrior.id, "Cleric finds injured ally")
	ranger.position = enemy.position - Vector2(100, 0)
	sim._use_specialty(ranger, enemy)
	check(sim.projectiles.size() == mini(3, sim.alive_count(1)), "Ranger volley fires at distinct enemies in range")
	sim.projectiles.clear()
	var enemy_hp: float = enemy.hp
	ranger.position = enemy.position - Vector2(100, 0)
	sim.shoot(ranger, enemy, 10)
	check(enemy.hp == enemy_hp, "Projectile damage waits for travel")
	sim._update_projectiles(0.5)
	check(enemy.hp < enemy_hp, "Projectile hits enemy after travel")
	check(sim.reports[ranger.army].damage > 0, "Damage attributed to army")
	warrior.guard = 0.6
	warrior.guard_time = 3.0
	sim._use_specialty(warrior, enemy)
	check(warrior.guard == 0.6, "Overlapping guards retain the strongest protection")
	check(warrior.action_name == "guard", "Guard uses the shield animation")
	lancer.position = enemy.position - Vector2(70, 0)
	enemy_hp = enemy.hp
	sim._use_specialty(lancer, enemy)
	check(enemy.hp < enemy_hp, "Lancer pierces nearby target")
	for i in 30: sim.spawn_enemy({"unit": "warrior", "hp": 10, "damage": 1}, Vector2.ZERO)
	check(sim.alive_count(1) == 20, "Enemy and reinforcement cap is twenty")
	check(not sim.spawn_enemy({"unit": "warrior", "hp": 10, "damage": 1}, Vector2.ZERO), "Reinforcement rejected at cap")
	for number in [5, 10, 15, 20]:
		sim.setup(GameState.buildings, GameData.STAGES[number])
		var boss: Dictionary = {}
		for unit in sim.units:
			if not unit.get("boss", "").is_empty(): boss = unit
		sim._use_specialty(boss, sim.units[0])
		check(sim.warnings.size() == 1, "Boss ability telegraphed before activation")
		check(sim.warnings[0].remaining >= 1, "Telegraph gives one second warning")
		sim._update_warnings(1.2)
		check(sim.warnings.is_empty(), "Boss telegraph resolves")
		if number == 20:
			var before: int = sim.alive_count(1)
			sim._use_specialty(boss, sim.units[0])
			sim._update_warnings(1.2)
			check(sim.alive_count(1) == before + 3, "Warlord alternates attacks with reinforcements")
	sim.setup(GameState.buildings, GameData.STAGES[1])
	for unit in sim.units: unit.hp = 0
	sim.step()
	check(sim.outcome == 0, "Mutual defeat has an explicit loss outcome")
	sim.setup(GameState.buildings, GameData.STAGES[1])
	sim.limit = 0.05
	sim.step()
	check(sim.outcome == 0, "Battle timeout resolves defeat")

func _save_and_offline() -> void:
	reset_state()
	GameState.place_building("barracks", Vector2i(4, 1))
	GameState.cleared_stage = 1
	GameState.samples.assign([{"gold": 100, "seconds": 50.0}])
	check(is_equal_approx(GameState.offline_rate(), 1.0), "Offline rate is half the measured gold rate")
	check(GameState.offline_reward(10000, 1000).gold == 9000, "Offline amount uses elapsed time")
	check(GameState.offline_reward(100000, 1000).gold == 28800, "Offline amount caps at eight hours")
	GameState.update_setting("landscape", 2)
	var saved := GameState.serialize(1000)
	var legacy := saved.duplicate(true)
	legacy.settings.erase("landscape")
	check(GameState.valid_save(legacy), "Existing saves without a landscape remain valid")
	GameState.deserialize(legacy)
	check(GameState.settings.landscape == 0, "Existing saves default to waterside without resetting progression")
	GameState.deserialize(saved)
	var invalid := saved.duplicate(true)
	invalid.settings.volume = {}
	check(not GameState.valid_save(invalid), "Invalid settings rejected without conversion errors")
	invalid = saved.duplicate(true)
	invalid.buildings[0].cell = [999, 0]
	check(not GameState.valid_save(invalid), "Out-of-bounds save rejected")
	invalid = saved.duplicate(true)
	invalid.buildings.append(invalid.buildings[0].duplicate(true))
	check(not GameState.valid_save(invalid), "Duplicate building IDs rejected")
	invalid = saved.duplicate(true)
	invalid.version = 999
	check(not GameState.valid_save(invalid), "Unsupported save version rejected")
	DirAccess.make_dir_recursive_absolute("res://.godot/remaster_tests")
	GameState.save_path = "res://.godot/remaster_tests/save_%d.json" % Time.get_ticks_msec()
	GameState.persistence_enabled = true
	check(GameState.save_game(1000), "Save writes successfully")
	GameState.gold = 999
	check(GameState.load_game(1100), "Save reload succeeds")
	check(GameState.settings.landscape == 2, "Landscape choice survives the real save and reload path")
	check(GameState.gold == 150, "Offline gold added to saved balance")
	check(GameState.load_game(1100) and GameState.gold == 150, "Repeated load cannot duplicate offline credit")
	GameState.gold = 175
	check(GameState.save_game(1100), "Replacement save succeeds")
	var corrupt := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	corrupt.store_string("not JSON")
	corrupt.close()
	check(GameState.load_game(1100) and GameState.gold == 150, "Corrupt primary recovers backup")
	check(GameState.active_round_id == 0 and GameState.phase == "PREPARE", "Reload returns to preparation")
	check(GameState.load_game(1050) and GameState.gold == 150 and GameState.last_seen == 1100, "Clock rollback preserves timestamp without gold")
	GameState.persistence_enabled = false

func _progression() -> void:
	reset_state()
	GameState.cleared_stage = 10
	GameState.farm_stage = 9
	GameState.set_advancing(false)
	GameState.select_farm(3)
	var id: int = GameState.begin_battle()
	GameState.settle_battle(id, 3, true, 20)
	check(GameState.farm_stage == 3, "Selected farm stage persists after victory")
	id = GameState.begin_battle()
	GameState.settle_battle(id, 3, false, 60)
	check(GameState.farm_stage == 2, "Farming defeat steps down")
	GameState.set_advancing(true)
	id = GameState.begin_battle()
	GameState.settle_battle(id, 11, false, 60)
	check(not GameState.advancing and GameState.farm_stage == 9, "Progression defeat selects cleared ordinary stage")
	GameState.cleared_stage = 19
	GameState.set_advancing(true)
	id = GameState.begin_battle()
	GameState.settle_battle(id, 20, true, 50)
	check(GameState.cleared_stage == 20 and not GameState.advancing and GameState.farm_stage == 19, "Demo completion continues farming")
	check(TownRules.capacity(0) == 3 and TownRules.capacity(5) == 4 and TownRules.capacity(10) == 6 and TownRules.capacity(15) == 8, "Boss capacity milestones")

func _director_controls() -> void:
	reset_state()
	GameState.cleared_stage = 4
	GameState.gold = 10000
	var placed: Dictionary = GameState.place_building("barracks", Vector2i(4, 1))
	var director := BattleDirector.new()
	add_child(director)
	director.set_physics_process(false)
	GameState.set_advancing(false)
	director.start_now()
	GameState.purchase_research(placed.id, "damage_1")
	GameState.select_farm(2)
	director.simulation.outcome = 0
	director._finish()
	director.advance(5.1)
	check(not GameState.advancing and director.stage_number == 1, "Latest Farm choice cancels queued upgrade retry and permits fallback")
	director.start_now()
	GameState.purchase_research(placed.id, "health_1")
	director.simulation.outcome = 0
	director._finish()
	director.advance(5.1)
	check(GameState.advancing and director.stage_number == 5, "Battle-time improvement retries progression at next preparation")
	director.start_now()
	GameState.set_advancing(false)
	GameState.set_advancing(true)
	director.simulation.outcome = 0
	director._finish()
	director.advance(5.1)
	check(GameState.advancing and director.stage_number == 5, "Latest Challenge choice survives the current battle's defeat")
	director.free()
