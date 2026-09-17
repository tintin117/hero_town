extends Node

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _ready() -> void:
	call_deferred("run_checks")

func quit(code: int) -> void:
	get_tree().quit(code)

func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i], b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.000000001
	return a == b

func run_checks() -> void:
	if not OS.get_cmdline_user_args().has("--test"): quit(1); return
	var game := FarmFightState.new()
	check(game.idle_farmers() == 4 and game.s.research.warrior.unlocked, "opening workers and Warrior")
	check(not game.s.research.monk.unlocked and game.s.towers.size() == 1 and game.s.towers.has("warrior"), "starter barracks; other branches need construction")
	check(game.simulation.living_class("warrior") == 1 and game.simulation.alive_count(1) == 1, "opening skirmish starts immediately")
	check(not game.assign_farmer(1, "gold", 1) and not game.assign_farmer(0, "meat", 1), "only owned valid spots")
	for i in 2: check(game.assign_farmer(0, "gold", 1), "assign gold")
	for i in 2: check(game.assign_farmer(0, "wood", 1), "assign wood")
	check(not game.assign_farmer(0, "wood", 1), "no duplicate workers")
	var gold: float = game.s.gold
	var wood: float = game.s.wood
	game.advance(0.5)
	check(is_equal_approx(game.s.gold - gold, 0.3) and is_equal_approx(game.s.wood - wood, 0.3), "fractional simultaneous income")
	game.s.gold = 100000.0
	game.s.wood = 100000.0
	check(game.purchase("efficiency") and is_equal_approx(game.rates.gold, 0.75), "global farmer upgrades")
	check(game.hire_farmer() and game.idle_farmers() == 1, "hire shared worker")
	check(game.assign_farmer(0, "gold", -1) and game.idle_farmers() == 2, "unassign returns worker")
	for id in FarmFightState.CLASSES:
		if id != "warrior":
			check(not game.build_tower(id), "locked class cannot build")
			check(game.purchase("unlock", id), "unlock " + id)
		if id != "warrior": check(game.build_tower(id), "construct " + id)
		check(not game.build_tower(id), "one tower " + id)
		check(game.buy_reinforcement(id), "reinforcement " + id)
		var paid_gold: float = game.s.gold
		check(not game.buy_reinforcement(id) and game.s.gold == paid_gold, "rapid recruit clicks cannot spend or spawn " + id)
		var hero: Dictionary = game.simulation.units.back()
		hero.hp *= 0.5
		var old_hp: float = hero.max_hp
		check(game.purchase("upgrade", id, "health"), "health upgrade " + id)
		check(hero.max_hp > old_hp and is_equal_approx(hero.hp / hero.max_hp, 0.5), "health fraction preserved " + id)
		var old_power: float = hero.damage
		check(game.purchase("upgrade", id, "power") and hero.damage > old_power, "live power upgrade")
		var old_timer: float = game.s.towers[id].remaining
		check(game.purchase("upgrade", id, "spawn") and game.s.towers[id].remaining < old_timer, "spawn progress preserved")
	while game.simulation.living_class("warrior") < game.balance.hero_cap: game.spawn_hero("warrior")
	gold = game.s.gold
	check(not game.buy_reinforcement("warrior") and game.s.gold == gold, "full army cannot spend on reinforcement")
	game.s.towers.warrior.remaining = 0
	game.advance(0.05)
	check(game.s.towers.warrior.remaining == 0, "full tower retains ready spawn")
	for unit in game.simulation.units:
		if unit.side == 0 and unit.army == "warrior": unit.hp = 0; break
	game.advance(0.1)
	check(game.simulation.living_class("warrior") == game.balance.hero_cap, "ready tower replaces casualty once")
	game.s.gold = 0
	game.s.wood = 0
	var before := game.snapshot()
	check(not game.purchase("efficiency") and game.snapshot() == before, "failed purchase is atomic")
	check(not game.purchase("upgrade", "warrior", "unknown"), "invalid upgrade rejected")
	var survivor := game.simulation.units.filter(func(u): return u.side == 0)[0] as Dictionary
	var survivor_hp: float = survivor.hp
	var old_rates := game.rates.duplicate()
	var timer: float = game.s.towers.monk.remaining
	game.simulation.tower().hp = 0
	var events := game.advance(0.05)
	check(game.s.owned == 1 and events.any(func(e): return e.kind == "conquered"), "capture exactly once")
	check(game.simulation.alive_count(1) == 0 and survivor.hp == survivor_hp, "capture removes foes, preserves survivors")
	check(is_equal_approx(game.s.towers.monk.remaining, timer - 0.05), "tower timer survives relocation")
	check(game.rates == old_rates and game.spot_rate(1) > game.spot_rate(0), "old farms continue, new spots richer")
	game.advance(0.1)
	check(game.s.owned == 1, "no duplicate conquest")
	check(game.assign_farmer(1, "wood", 1), "new spot unlocked")
	game.spawn_wave()
	game.advance(15.0)
	var firing_archer: Dictionary = game.simulation.units.filter(func(unit): return unit.side == 0 and unit.army == "archer")[0]
	game.simulation.shoot(firing_archer, game.simulation.tower(), firing_archer.damage)
	check(not game.simulation.projectiles.is_empty(), "save fixture includes an in-flight projectile")
	DirAccess.make_dir_recursive_absolute("res://.godot/test_outputs")
	var path := "res://.godot/test_outputs/farm-fight-check.json"
	check(game.save_game(path), "save active combat")
	var loaded := FarmFightState.new()
	check(loaded.load_game(path).contains("resumed"), "load without offline progress")
	check(equivalent(loaded.snapshot(), game.snapshot()), "active-combat roundtrip to JSON precision")
	game.advance(1.0)
	loaded.advance(1.0)
	check(equivalent(loaded.snapshot(), game.snapshot()), "resumed simulation equivalent")
	check(game.save_game(path), "second checkpoint creates backup")
	var preserved := FileAccess.get_file_as_string(path + ".bak")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("{broken save")
	damaged.close()
	var recovery := FarmFightState.new()
	check(recovery.load_game(path).begins_with("Recovered"), "corrupt primary recovers valid backup")
	check(recovery.save_game(path) and FileAccess.get_file_as_string(path + ".bak") == preserved, "recovery preserves good backup")
	check(not game.save_game("res://.godot/missing-save-directory/save.json"), "unwritable save reports failure")
	var corrupt_path := "res://.godot/test_outputs/farm-fight-corrupt.json"
	damaged = FileAccess.open(corrupt_path, FileAccess.WRITE)
	damaged.store_string("invalid")
	damaged.close()
	var corrupt := FarmFightState.new()
	corrupt.load_game(corrupt_path)
	check(corrupt.load_failed and not corrupt.save_game(corrupt_path) and FileAccess.get_file_as_string(corrupt_path) == "invalid", "unrecoverable save never overwritten")
	DirAccess.remove_absolute(corrupt_path)
	var broken := game.snapshot()
	broken.campaign.assignments["0:gold"] = 999
	check(not game.valid_save(broken), "invalid assignments rejected")
	check(not game.valid_save({}), "invalid save rejected")
	var legacy := game.snapshot()
	for id in legacy.campaign.towers: legacy.campaign.towers[id].erase("recruit_remaining")
	check(game.valid_save(legacy), "earlier campaign saves accept a missing reinforcement timer")
	var invalid_timer := game.snapshot()
	invalid_timer.campaign.towers.warrior.recruit_remaining = "broken"
	check(not game.valid_save(invalid_timer), "invalid reinforcement timer rejected")
	var empty := FarmFightState.new()
	for unit in empty.simulation.units:
		if not unit.get("objective", false): unit.hp = 0
	empty.simulation.spawn_enemy({"hp": 10.0, "damage": 5.0}, Vector2(-568, 0))
	empty.advance(0.1)
	check(empty.simulation.alive_count(1) == 0 and empty.s.owned == 0, "safe rear defense")
	empty.build_tower("warrior")
	empty.advance(empty.spawn_seconds("warrior") + 0.1)
	check(empty.simulation.living_class("warrior") > 0, "empty army recovers automatically")
	for i in 100: empty.spawn_wave()
	check(empty.simulation.alive_count(1) <= empty.balance.enemy_cap, "bounded enemy waves")
	# An arrow keeps attribution after its source is removed.
	var shooter := empty.simulation.units.filter(func(u): return u.side == 0)[0] as Dictionary
	var target := empty.simulation.units.filter(func(u): return u.side == 1 and not u.get("objective", false))[0] as Dictionary
	shooter.position = target.position
	empty.simulation.shoot(shooter, target, 3.0)
	shooter.hp = 0
	empty.advance(0.1)
	check(empty.simulation.find_unit(int(shooter.id)).is_empty(), "dead units removed with stable IDs")
	check(empty.simulation.units.size() <= empty.balance.enemy_cap + 2, "simulation storage bounded")
	var roles := FarmFightState.new()
	roles.simulation.units = roles.simulation.units.filter(func(u): return u.get("objective", false))
	roles.simulation.start_frontier(roles.balance.tower_health, roles.balance.enemy_cap)
	for id in FarmFightState.CLASSES: roles.spawn_hero(id)
	var warrior: Dictionary = roles.simulation.units[1]
	var monk: Dictionary = roles.simulation.units[2]
	var archer: Dictionary = roles.simulation.units[3]
	var lancer: Dictionary = roles.simulation.units[4]
	for unit in [warrior, monk, archer, lancer]: unit.position = Vector2.ZERO
	warrior.hp *= 0.5
	monk.cooldown = 0
	var wounded_hp: float = warrior.hp
	roles.advance(0.05)
	check(warrior.hp > wounded_hp, "Monk heals a real injured ally")
	roles.simulation._use_specialty(warrior, roles.simulation.tower())
	check(warrior.guard > 0 and monk.guard > 0, "Warrior protects nearby allies")
	roles.simulation.spawn_enemy({"hp": 100.0, "damage": 1.0}, Vector2(60, 0))
	roles.simulation.spawn_enemy({"hp": 100.0, "damage": 1.0}, Vector2(100, 0))
	var enemy: Dictionary = roles.simulation.units.back()
	roles.simulation._use_specialty(lancer, enemy)
	check(enemy.hp < 100 and roles.simulation.units[-2].hp < 100, "Lancer pierces multiple targets")
	roles.simulation._use_specialty(archer, enemy)
	check(roles.simulation.projectiles.size() >= 2, "Archer volleys ranged projectiles")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("FARM FIGHT CHECKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
