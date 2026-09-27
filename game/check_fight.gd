extends SceneTree
## Run: godot --headless --path . --script res://game/check_fight.gd
## Omit --headless and append -- --capture to also save UI captures in .godot/.

const Rules := preload("res://game/fight.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_mana_and_targets()
	_check_skill_effects()
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
	var tips := _finish(fight)
	assert(fight.coins == 180 + tips and fight.income_for([0, 1, 2]) == 185)
	assert(fight.heroes[4].wins == 99)
	assert(fight.step().is_empty() and fight.coins == 180 + tips)
	assert(fight.start([0, 1, 2]))
	for id in fight.participants:
		assert(fight.health[id] == fight.heroes[id].health)
		assert(fight.mana[id] == 0)
	assert(fight.crowd_tips == 0 and fight.last_attacker.is_empty())
	assert(fight.pending_casts.is_empty() and fight.turn_order.is_empty())
	tips += _finish(fight)
	assert(fight.coins == 365 + tips and fight.completed == 2)
	# All ten possible trios, with twenty reproducible fights each.
	for a in range(3):
		for b in range(a + 1, 4):
			for c in range(b + 1, 5):
				var sample := Rules.new()
				var sample_tips := 0
				for seed_value in range(20):
					sample.rng.seed = seed_value
					assert(sample.start([a, b, c]))
					sample_tips += _finish(sample)
					assert(sample.income_for([a, b, c]) == 100 + 5 * (seed_value + 1))
				assert(sample.coins == 2950 + sample_tips)
	print("PASS: five skills, targeting, mana priority, cancelled casts, immediate tips, and 202 complete fights.")
	await _check_ui()
	quit()


func _finish(fight: RefCounted) -> int:
	var before := 0
	var tips := 0
	var coins_before: int = fight.coins
	for hero in fight.heroes:
		before += int(hero.wins)
	var steps := 0
	while fight.active and steps < 200:
		var action_coins: int = fight.coins
		var event: Dictionary = fight.step()
		tips += int(event.tip)
		assert(event.tip == (10 if event.kind == "skill" else 0))
		assert(fight.coins == action_coins + event.tip + (fight.payout if event.winner >= 0 else 0))
		for hit in event.hits:
			assert(event.attacker != hit.target and hit.damage > 0)
		for id in fight.participants:
			assert(fight.health[id] >= 0 and fight.health[id] <= fight.heroes[id].health)
			assert(fight.mana[id] >= 0 and fight.mana[id] <= Rules.MANA_MAX)
		steps += 1
	assert(not fight.active, "Fight did not terminate.")
	assert(fight.survivors().size() == 1)
	assert(fight.last_winner == fight.survivors()[0])
	var after := 0
	for hero in fight.heroes:
		after += int(hero.wins)
	assert(after == before + 1, "Exactly one career victory must be awarded.")
	assert(fight.coins == coins_before + fight.payout + tips)
	assert(fight.crowd_tips == tips and fight.pending_casts.is_empty())
	return tips


func _battle(lineup: Array[int] = [0, 1, 2]) -> RefCounted:
	var fight := Rules.new()
	fight.rng.seed = 7
	assert(fight.start(lineup))
	return fight


func _cast(fight: RefCounted, id: int) -> Dictionary:
	fight.mana[id] = Rules.MANA_MAX
	fight.pending_casts.assign([id])
	var event: Dictionary = fight.step()
	assert(event.kind == "skill" and event.attacker == id and event.tip == 10)
	assert(fight.mana[id] == 0)
	return event


func _check_mana_and_targets() -> void:
	var fight := _battle()
	fight.turn_order.assign([0, 1, 2])
	var hit: Dictionary = fight.step()
	assert(hit.attacker == 0 and hit.hits[0].target == 1)
	assert(fight.mana[0] == 25 and fight.mana[1] == 15 and fight.mana[2] == 0)
	assert(fight.last_attacker[1] == 0 and fight.pending_casts.is_empty())
	# Both fill on the same hit: attacker casts first, without using a normal turn.
	fight.turn_order.assign([0, 2, 1])
	fight.mana[0] = 90
	fight.mana[1] = 90
	fight.step()
	assert(fight.mana[0] == 100 and fight.mana[1] == 100)
	assert(fight.pending_casts == [0, 1] and fight.coins == 0)
	var first: Dictionary = fight.step()
	assert(first.kind == "skill" and first.attacker == 0 and fight.coins == 10)
	assert(fight.mana[0] == 0 and fight.mana[1] == 100)
	assert(fight.turn_order == [2, 1])
	var second: Dictionary = fight.step()
	assert(second.kind == "skill" and second.attacker == 1 and fight.coins == 20)
	assert(fight.mana[0] == 0 and fight.mana[1] == 0 and fight.mana[2] == 0)
	assert(fight.turn_order == [2, 1] and fight.pending_casts.is_empty())
	assert(fight.step().attacker == 2)
	# A ready defender killed by the first cast must never cast or receive a tip.
	fight = _battle()
	fight.health[1] = 20
	fight.mana[0] = 100
	fight.mana[1] = 100
	fight.pending_casts.assign([0, 1])
	fight.turn_order.assign([2, 0, 1])
	fight.step()
	assert(fight.health[1] == 0)
	var next: Dictionary = fight.step()
	assert(next.kind == "attack" and next.attacker == 2 and fight.coins == 10)
	# A final normal hit ends the fight instead of casting with the newly filled bar.
	fight = _battle()
	fight.health[1] = 1
	fight.health[2] = 0
	fight.mana[0] = 75
	fight.mana[1] = 95
	fight.turn_order.assign([0])
	var final_hit: Dictionary = fight.step()
	assert(final_hit.winner == 0 and fight.mana[0] == 100 and fight.mana[1] == 95)
	assert(fight.pending_casts.is_empty() and fight.crowd_tips == 0 and fight.coins == 100)
	# Preferences and seeded ties.
	fight = _battle()
	assert(fight._target_for(0) == 1 and fight._target_for(1) == 0)
	fight.health[0] = 50
	assert(fight._target_for(1) == 2 and fight._target_for(2) == 0)
	fight.heroes[2].attack = 21
	var ties := {}
	for seed_value in range(20):
		fight.rng.seed = seed_value
		var target: int = fight._target_for(0)
		assert(target in [1, 2])
		ties[target] = true
		fight.rng.seed = seed_value
		assert(fight._target_for(0) == target)
	assert(ties.size() == 2)
	fight = _battle([0, 3, 4])
	var revenge_choices := {}
	var random_choices := {}
	for seed_value in range(20):
		fight.rng.seed = seed_value
		revenge_choices[fight._target_for(4)] = true
		random_choices[fight._target_for(3)] = true
	assert(revenge_choices.has(0) and revenge_choices.has(3))
	assert(random_choices.has(0) and random_choices.has(4))
	fight.last_attacker[4] = 3
	assert(fight._target_for(4) == 3)
	fight.health[3] = 0
	assert(fight._target_for(4) == 0)


func _check_skill_effects() -> void:
	var fight := _battle()
	var event := _cast(fight, 0)
	assert(event.hits == [{"target": 1, "damage": 34}] and event.healing == 0)
	assert(fight.coins == 10 and fight.health[1] == 98 and fight.mana[1] == 0)
	fight = _battle()
	event = _cast(fight, 1)
	assert(event.hits.size() == 2 and fight.health[0] == 129 and fight.health[2] == 89)
	assert(fight.coins == 10 and fight.crowd_tips == 10)
	assert(fight.mana[0] == 0 and fight.mana[2] == 0)
	assert(fight.last_attacker[0] == 1 and fight.last_attacker[2] == 1)
	fight = _battle()
	fight.health[0] = 50
	fight.health[1] = 60
	event = _cast(fight, 2)
	assert(event.hits == [{"target": 0, "damage": 45}])
	fight.heroes[2].attack = 17
	fight.health[0] = 100
	event = _cast(fight, 2)
	assert(event.hits == [{"target": 1, "damage": 43}], "Retarget on cast; round half damage upward.")
	fight = _battle([0, 3, 4])
	fight.health[3] = 70
	event = _cast(fight, 3)
	assert(event.hits.is_empty() and event.healing == 42 and fight.health[3] == 112)
	fight.health[3] = 135
	assert(_cast(fight, 3).healing == 5 and fight.health[3] == 140)
	assert(_cast(fight, 3).healing == 0 and fight.coins == 30)
	fight = _battle([0, 3, 4])
	fight.health[4] = 40
	fight.health[0] = 7
	fight.last_attacker[4] = 0
	event = _cast(fight, 4)
	assert(event.hits == [{"target": 0, "damage": 7}] and event.healing == 7)
	assert(fight.health[4] == 47 and fight.health[0] == 0)
	fight.health[4] = 103
	event = _cast(fight, 4)
	assert(event.hits == [{"target": 3, "damage": 18}] and event.healing == 2)
	assert(fight.health[4] == 105 and fight.mana[3] == 0)
	# Sweep may finish both opponents: one tip, one victory, one guaranteed payout.
	fight = _battle()
	fight.health[0] = 21
	fight.health[2] = 21
	fight.mana[1] = 100
	fight.mana[2] = 100
	fight.pending_casts.assign([1, 2])
	event = fight.step()
	assert(event.winner == 1 and fight.survivors() == [1])
	assert(fight.coins == 110 and fight.crowd_tips == 10 and fight.heroes[1].wins == 1)
	assert(fight.pending_casts.is_empty())
	assert(fight.step().is_empty() and fight.coins == 110)


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
	# No frame wait: the bank and popup must change at the start of the cast.
	ui.fight.health[3] = 70
	ui.fight.mana[3] = 100
	ui.fight.pending_casts.assign([3])
	ui._tick()
	ui.get_node("%Tick").stop()
	assert(ui.fight.coins == 10 and ui.get_node("%Coins").text == "10 coins")
	assert(ui.get_node("%Tips").text == "CROWD TIPS  +10")
	assert(ui.fighters[3].mana.value == 0 and ui.fighters[3].bar.value == 112)
	assert(ui.fighters[3].body.has_node("SkillTip"))
	await _capture("skill-tip")
	ui.fight.mana[1] = 100
	ui.fight.pending_casts.assign([1])
	ui._tick()
	ui.get_node("%Tick").stop()
	assert(ui.fight.coins == 20 and ui.get_node("%Coins").text == "20 coins")
	assert(ui.fighters[1].body.has_node("SkillTip") and ui.fighters[3].body.has_node("SkillTip"))
	await _capture("overlapping-tips")
	while ui.fight.active:
		ui._tick()
		ui.get_node("%Tick").stop()
	assert(ui.fight.completed == 1 and ui.fight.coins == 100 + ui.fight.crowd_tips)
	assert(ui.get_node("%Tick").is_stopped())
	assert(not ui.get_node("%Start").disabled)
	assert(ui.get_node("%Income").text == "Guaranteed: 105 coins + skill tips")
	assert("Tips already paid" in ui.get_node("%Commentary").text)
	await create_timer(0.85).timeout
	for id in ui.fighters:
		if ui.fight.health[id] == 0:
			assert(ui.fighters[id].sprite.modulate == Color("515c68"))
	await _capture("winner")
	ui.get_node("%Start").pressed.emit()
	ui.get_node("%Tick").stop()
	assert(ui.get_node("%Tips").text == "CROWD TIPS  +0")
	for id in ui.selected:
		assert(ui.fighters[id].mana.value == 0)
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
	print("PASS: UI selection, cast-start money/popups, overlapping tips, mana reset, settlement, and stop/restart.")


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var path := "res://.godot/fight-%s.png" % label
	assert(root.get_texture().get_image().save_png(path) == OK)
