extends Node

var game_seconds := 0.0
var milestones: Dictionary = {}
var economy_milestones: Dictionary = {}
var policy: String = "balanced"

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--policy="): policy = arg.trim_prefix("--policy=")
	GameState.persistence_enabled = false
	GameState.place_building("barracks", Vector2i(4, 1))
	for round_index in 400:
		shop()
		var stage: int = mini(20, GameState.cleared_stage + 1) if GameState.advancing else GameState.farm_stage
		var sim := BattleSimulation.new()
		sim.setup(GameState.buildings, GameData.STAGES[stage])
		while sim.outcome == -1: sim.step()
		game_seconds += 25.0 + sim.elapsed
		var id: int = GameState.begin_battle()
		var result: Dictionary = GameState.settle_battle(id, stage, sim.outcome == 1, sim.elapsed)
		if result.first_clear:
			milestones[stage] = snappedf(game_seconds / 60, 0.1)
			print("BALANCE stage=%d minute=%.1f battle=%.1fs armies=%d gold=%d" % [stage, game_seconds / 60, sim.elapsed, GameState.buildings.size(), GameState.gold])
		if GameState.cleared_stage >= 20: break
		if round_index % 10 == 0: await get_tree().process_frame
	print("BALANCE COMPLETE ", JSON.stringify({"policy": policy, "minutes": game_seconds / 60, "cleared": GameState.cleared_stage, "milestones": milestones, "economy_minutes": economy_milestones, "buildings": GameState.buildings}))
	get_tree().quit(0 if GameState.cleared_stage == 20 else 1)

func shop() -> void:
	var changed := false
	# Buy one of each unlocked class, then repeat the four-army composition.
	var desired: String = TownRules.ARMY_TYPES[GameState.buildings.size() % 4]
	var data: BuildingData = GameData.BUILDINGS[desired]
	if GameState.buildings.size() < TownRules.capacity(GameState.cleared_stage) and GameState.cleared_stage >= data.unlock_stage:
		if GameState.gold >= data.build_cost:
			var index: int = GameState.buildings.size()
			var positions := [Vector2i(4, 1), Vector2i(2, 0), Vector2i(1, 2), Vector2i(5, 0), Vector2i(5, 2), Vector2i(2, 2), Vector2i(1, 0), Vector2i(4, 0)]
			changed = GameState.place_building(desired, positions[index]).ok
			if changed and GameState.buildings.size() == 2:
				economy_milestones["second_army"] = game_seconds / 60.0
		else:
			return # Save for a newly available class rather than spending every coin.
	# Purchase the cheapest available improvement, with promotions favored.
	for attempt in 40:
		var candidate := {}
		var best_score := INF
		for record in GameState.buildings:
			for node: ResearchNodeData in GameData.research_for(GameData.BUILDINGS[record.type]):
				if not GameState.research_error(record.id, node.id).is_empty(): continue
				var score := float(node.cost)
				if node.branch == "rarity": score *= 0.45
				if node.branch == "crew": score *= 0.7
				if score < best_score:
					best_score = score
					candidate = {"army": record.id, "node": node.id}
		if candidate.is_empty(): break
		if GameState.purchase_research(candidate.army, candidate.node).ok:
			changed = true
			if not economy_milestones.has("first_research"):
				economy_milestones["first_research"] = game_seconds / 60.0
	if changed: GameState.set_advancing(true)
