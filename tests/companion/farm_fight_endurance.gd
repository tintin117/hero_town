extends Node

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"): get_tree().quit(1); return
	call_deferred("run_check")

func run_check() -> void:
	var game := FarmFightState.new()
	var duration := 1800
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="): duration = int(arg.trim_prefix("--duration="))
	# A developed campaign stresses all four classes, repeated transitions and projectiles.
	game.s.gold = 100000000.0
	game.s.wood = 100000000.0
	for id in FarmFightState.CLASSES:
		if id != "warrior": game.purchase("unlock", id)
		game.build_tower(id)
		for rank in 12:
			game.purchase("upgrade", id, "power")
			game.purchase("upgrade", id, "health")
			game.purchase("upgrade", id, "spawn")
	for resource in ["gold", "wood"]:
		for i in 2: game.assign_farmer(0, resource, 1)
	var max_units := 0
	var max_shots := 0
	var captures := 0
	var failed := false
	var start := Time.get_ticks_msec()
	for second in duration:
		for event in game.advance(1.0):
			if event.kind == "conquered": captures += 1
		max_units = maxi(max_units, game.simulation.units.size())
		max_shots = maxi(max_shots, game.simulation.projectiles.size())
		if game.simulation.units.size() > 89 or game.simulation.alive_count(1) > 40: failed = true
		for id in FarmFightState.CLASSES:
			if game.simulation.living_class(id) > 12: failed = true
		if second % 300 == 0:
			print("ENDURANCE ", second, " / ", duration, "s; lands=", game.s.owned, "; units=", game.simulation.units.size(), "; shots=", game.simulation.projectiles.size())
			if not game.valid_save(game.snapshot()): failed = true
			await get_tree().process_frame
	if captures != game.s.owned or (duration >= 1800 and captures < 3) or max_shots > 256: failed = true
	print("FARM FIGHT ENDURANCE: %s; %ds simulated, %d conquests, max units %d, max projectiles %d, %.2fs wall time" % ["FAILED" if failed else "PASSED", duration, captures, max_units, max_shots, (Time.get_ticks_msec() - start) / 1000.0])
	get_tree().quit(1 if failed else 0)
