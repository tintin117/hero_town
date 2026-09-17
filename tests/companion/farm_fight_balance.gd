extends Node

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"): get_tree().quit(1); return
	var idle := FarmFightState.new()
	var max_enemies := 0
	var empty_seconds := 0
	for second in 180:
		idle.advance(1.0)
		max_enemies = maxi(max_enemies, idle.simulation.alive_count(1))
		if idle.simulation.alive_count(0) == 0: empty_seconds += 1
	print("UNATTENDED OPENING: tower=", idle.simulation.tower().hp, " max enemies=", max_enemies, " empty seconds=", empty_seconds)
	var opening_ok: bool = idle.s.owned == 0 and idle.simulation.tower().hp >= idle.balance.tower_health * 0.9 and max_enemies <= 6 and empty_seconds <= 45
	var spam := FarmFightState.new()
	spam.s.gold = 100000.0
	var paid := 0
	for second in 60:
		for click in 20:
			if spam.buy_reinforcement("warrior"): paid += 1
		spam.advance(1.0)
	print("RECRUITMENT: ", paid, " paid heroes from 1,200 clicks in 60s")
	var recruitment_ok := paid == 3
	var game := FarmFightState.new()
	for resource in ["gold", "wood"]:
		for i in 2: game.assign_farmer(0, resource, 1)
	var purchases := [["upgrade", "warrior", "power"], ["farmer", "", ""], ["upgrade", "warrior", "health"],
		["upgrade", "warrior", "power"], ["upgrade", "warrior", "spawn"], ["upgrade", "warrior", "health"]]
	var purchase_index := 0
	var first_conquest := -1
	for second in 600:
		if purchase_index < purchases.size():
			var entry: Array = purchases[purchase_index]
			if game.purchase(entry[0], entry[1], entry[2]):
				purchase_index += 1
				if entry[0] == "farmer": game.assign_farmer(0, "gold", 1)
		game.advance(1.0)
		if second % 60 == 0: print("OPENING ", second, "s heroes=", game.simulation.alive_count(0), " enemies=", game.simulation.alive_count(1), " tower=", game.simulation.tower().hp, " purchases=", purchase_index)
		if game.s.owned > 0: first_conquest = second + 1; break
	print("FIRST CONQUEST: ", first_conquest, " seconds")
	var passed := opening_ok and recruitment_ok and first_conquest >= 180 and first_conquest <= 360
	print("FARM FIGHT BALANCE: ", "PASSED" if passed else "FAILED")
	get_tree().quit(0 if passed else 1)
