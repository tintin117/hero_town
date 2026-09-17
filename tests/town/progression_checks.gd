extends Node

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PROTOTYPE: " + message)

func _ready() -> void:
	if not GameState.is_test_session() or GameState.persistence_enabled:
		get_tree().quit(1)
		return
	GameState.place_building("barracks", Vector2i(4,1))
	var id: String = GameState.buildings[0].id
	var director := BattleDirector.new()
	add_child(director)
	director.set_physics_process(false)
	director.advance(0.01)
	check(director.phase == "BATTLE", "Army starts without a preparation wait")
	var original_damage: float = director.simulation.units[0].damage
	GameState.set_specialization(id,"vanguard")
	GameState.purchase_research(id,"damage_1")
	check(director.simulation.units[0].damage == original_damage, "Research and specialization preserve active snapshot")
	GameState.set_reorganizing(true)
	director.simulation.elapsed = 10.0
	director.simulation.outcome = 1
	director._finish()
	var reward_gold := GameState.gold
	director._finish()
	check(GameState.gold == reward_gold, "Nonblocking reward settles exactly once")
	check(is_equal_approx(GameState.samples[0].seconds,10.8), "Offline sample uses battle plus actual short transition")
	check(is_equal_approx(GameState.offline_rate(),0.5 * GameData.STAGES[1].gold / 10.8), "Offline multiplier follows faster online cadence")
	director.advance(0.79)
	check(director.phase == "RESULTS", "Short visual transition remains")
	director.advance(0.02)
	check(director.phase == "PREPARE", "No five-second results lock")
	director.advance(100)
	check(director.phase == "PREPARE", "Arrange deliberately holds between battles")
	check(GameState.refund_research(id).get("gold",0) == 50, "Arrange permits exact refund")
	check(GameState.samples.is_empty(), "Refund clears income measurement")
	check(GameState.move_building(id,Vector2i(2,2)).ok, "Reorganization moves freely")
	GameState.set_reorganizing(false)
	director.advance(0.01)
	check(director.phase == "BATTLE", "Resume starts immediately")
	check(is_equal_approx(director.simulation.units[0].damage,original_damage * 1.3), "Vanguard has real damage effect")
	check(director.simulation.units[0].home == TownRules.cell_position(Vector2i(2,2)) + Vector2(26,-16), "Next snapshot uses moved deployment")
	check(not GameState.refund_research(id).ok, "Refund cannot change an active round")
	var spent := GameState.gold
	GameState.set_specialization(id,"bulwark")
	check(GameState.gold == spent, "Specialization is free and reversible")
	var bulwark := BattleSimulation.new()
	bulwark.setup(GameState.buildings,GameData.STAGES[1])
	check(is_equal_approx(bulwark.units[0].max_hp,195.0), "Bulwark gains thirty percent HP")
	bulwark._use_specialty(bulwark.units[0],bulwark.units.back())
	check(is_equal_approx(bulwark.units[0].guard,0.4), "Bulwark grants forty percent nearby guard")
	GameState.set_specialization(id,"vanguard")
	var vanguard := BattleSimulation.new()
	vanguard.setup(GameState.buildings,GameData.STAGES[1])
	vanguard._use_specialty(vanguard.units[0],vanguard.units.back())
	check(is_equal_approx(vanguard.units[0].guard,0.15), "Vanguard trades away some protection")
	check(not GameState.set_specialization(id,"captain").ok, "Unsupported specialization rejected")
	director.free()
	GameState.pin_upgrade(id,"damage_1")
	GameState.gold = 1000
	GameState.set_specialization(id,"bulwark")
	var old_path := GameState.save_path
	DirAccess.make_dir_recursive_absolute("res://.godot/prototype_tests")
	GameState.save_path = "res://.godot/prototype_tests/save_%d.json" % Time.get_ticks_msec()
	GameState.persistence_enabled = true
	check(GameState.save_game(1000), "Prototype state saves to isolated file")
	check(GameState.load_game(1000), "Prototype state reloads")
	check(GameState.get_building(id).specialization == "bulwark" and GameState.pinned_goal.node == "damage_1", "Specialization and pinned goal survive real persistence")
	GameState.persistence_enabled = false
	GameState.save_path = old_path
	var legacy := GameState.serialize(1000)
	legacy.buildings[0].erase("specialization")
	legacy.erase("pinned_goal")
	check(GameState.valid_save(legacy), "Old building records remain valid")
	GameState.deserialize(legacy)
	check(GameState.get_building(id).get("specialization","balanced") == "balanced", "Old army defaults to balanced")
	GameState.pin_upgrade(id,"damage_1")
	GameState.purchase_research(id,"damage_1")
	check(GameState.pinned_goal.is_empty(), "Completing a pinned upgrade releases objective")
	GameState.cleared_stage = 4
	var round_id := GameState.begin_battle()
	GameState.settle_battle(round_id,5,true,30)
	check(TownRules.capacity(GameState.cleared_stage) == 4, "First boss opens useful fourth army plot")
	check(GameState.objective_text().contains("Commons"), "Town development reward becomes persistent objective")
	check(GameState.offline_reward(100000,1000).seconds == 28800, "Eight-hour offline cap preserved")
	print("PROTOTYPE TESTS: %d checks, %d failures" % [checks,failures])
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if failures else 0)
