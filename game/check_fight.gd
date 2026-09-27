extends SceneTree
## Run: godot --headless --path . --script res://game/check_fight.gd
## Omit --headless and append -- --capture to also save UI captures in .godot/.

const Rules := preload("res://game/fight.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fight := Rules.new()
	assert(not fight.start([0, 1]))
	assert(not fight.start([0, 0, 1]))
	assert(not fight.start([-1, 1, 2]))
	assert(not fight.start([0, 1, 5]))
	assert(not fight.start([0, 1, 2, 3]))
	assert(fight.step().is_empty() and fight.coins == 0)
	fight.heroes[0].wins = 10
	fight.heroes[1].wins = 4
	fight.heroes[2].wins = 2
	fight.heroes[4].wins = 99
	assert(fight.income_for([0, 1, 2]) == 180)
	assert(fight.income_for([0, 1]) == 0)
	var lineup: Array[int] = [0, 1, 2]
	assert(fight.start(lineup))
	lineup[0] = 4
	assert(fight.participants == [0, 1, 2])
	assert(not fight.start([2, 3, 4]))
	_finish(fight)
	assert(fight.coins == 180 and fight.income_for([0, 1, 2]) == 185)
	assert(fight.heroes[4].wins == 99)
	assert(fight.step().is_empty() and fight.coins == 180)
	assert(fight.start([0, 1, 2]))
	for id in fight.participants:
		assert(fight.health[id] == fight.heroes[id].health)
	_finish(fight)
	assert(fight.coins == 365 and fight.completed == 2)
	# All ten possible trios, with twenty reproducible fights each.
	for a in range(3):
		for b in range(a + 1, 4):
			for c in range(b + 1, 5):
				var sample := Rules.new()
				for seed_value in range(20):
					sample.rng.seed = seed_value
					assert(sample.start([a, b, c]))
					_finish(sample)
					assert(sample.income_for([a, b, c]) == 100 + 5 * (seed_value + 1))
				assert(sample.coins == 2950)
	print("PASS: 202 fights; selection, single winner, rewards, repeat fights, and income formula.")
	await _check_ui()
	quit()


func _finish(fight: RefCounted) -> void:
	var before := 0
	for hero in fight.heroes:
		before += int(hero.wins)
	var steps := 0
	while fight.active and steps < 200:
		var event: Dictionary = fight.step()
		assert(event.attacker != event.target)
		assert(fight.health[event.target] >= 0)
		steps += 1
	assert(not fight.active, "Fight did not terminate.")
	assert(fight.survivors().size() == 1)
	assert(fight.last_winner == fight.survivors()[0])
	var after := 0
	for hero in fight.heroes:
		after += int(hero.wins)
	assert(after == before + 1, "Exactly one career victory must be awarded.")


func _check_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	assert(ui.cards.size() == 5 and ui.selected.size() == 3)
	assert(ui.cards[3].disabled)
	ui.cards[0].pressed.emit()
	assert(ui.selected.size() == 2 and ui.get_node("%Start").disabled)
	ui.cards[3].pressed.emit()
	assert(ui.selected == [1, 2, 3])
	assert(not ui.get_node("%Start").disabled)
	await _capture("booking")
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and ui.auto_fight)
	ui.get_node("%Tick").stop()
	ui._tick()
	ui.get_node("%Tick").stop()
	await create_timer(0.3).timeout
	await _capture("combat")
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and not ui.auto_fight)
	ui._select_hero(1)
	assert(ui.selected == [1, 2, 3], "An active fight's lineup must stay locked.")
	while ui.fight.active:
		ui._tick()
		ui.get_node("%Tick").stop()
	assert(ui.fight.completed == 1 and ui.fight.coins == 100)
	assert(ui.get_node("%Tick").is_stopped())
	assert(not ui.get_node("%Start").disabled)
	assert(ui.get_node("%Income").text == "Next fight: 105 coins")
	await create_timer(0.6).timeout
	await _capture("winner")
	ui.get_node("%Start").pressed.emit()
	ui.get_node("%Tick").stop()
	while ui.fight.active:
		ui._tick()
		ui.get_node("%Tick").stop()
	ui.get_node("%Start").pressed.emit()
	ui._tick()
	assert(not ui.fight.active and not ui.auto_fight, "Stopping between fights must cancel the restart.")
	ui.get_node("%Start").pressed.emit()
	ui.get_node("%Tick").stop()
	while ui.fight.active:
		ui._tick()
		ui.get_node("%Tick").stop()
	ui._tick()
	assert(ui.fight.active and ui.fight.completed == 3)
	ui.get_node("%Tick").stop()
	ui.queue_free()
	await process_frame
	print("PASS: UI selection, preview, start/stop, locked lineup, winner display, and automatic restart.")


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var path := "res://.godot/fight-%s.png" % label
	assert(root.get_texture().get_image().save_png(path) == OK)
