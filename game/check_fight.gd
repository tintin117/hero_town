extends SceneTree
## godot --headless --path . --script res://game/check_fight.gd
## Omit --headless and append -- --capture for screenshots in .godot/.

const Rules := preload("res://game/fight.gd")
const DT := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_movement()
	_check_mana()
	_check_skills()
	_check_reproducibility()
	var fight := Rules.new()
	for invalid in [[0, 1], [0, 0, 1], [-1, 1, 2], [0, 1, 5], [0, 1, 2, 3]]:
		var ids: Array[int] = []
		ids.assign(invalid)
		assert(not fight.start(ids))
	assert(fight.advance(DT).is_empty() and fight.coins == 0)
	fight.heroes[0].wins = 10
	fight.heroes[1].wins = 4
	fight.heroes[2].wins = 2
	fight.heroes[4].wins = 99
	assert(fight.income_for([0, 1, 2]) == 180 and fight.income_for([0, 1]) == 0)
	var lineup: Array[int] = [0, 1, 2]
	assert(fight.start(lineup))
	lineup[0] = 4
	assert(fight.participants == [0, 1, 2] and not fight.start([2, 3, 4]))
	_finish(fight)
	var bank := fight.coins
	assert(fight.heroes[4].wins == 99 and fight.income_for([0, 1, 2]) == 185)
	assert(fight.advance(DT).is_empty() and fight.coins == bank)
	assert(fight.start([0, 1, 2]))
	assert(fight.crowd_tips == 0 and fight.pending_casts.is_empty())
	for id in fight.participants:
		assert(fight.health[id] == fight.heroes[id].health and fight.mana[id] == 0)
		assert(fight.velocities[id] == Vector2.ZERO and fight.pauses[id] == 0.0)
		assert(fight.targets[id] == -1 and fight.cooldowns[id] <= 0.3)
	_finish(fight)
	var longest := 0.0
	for a in range(3):
		for b in range(a + 1, 4):
			for c in range(b + 1, 5):
				var sample := Rules.new()
				for seed_value in range(20):
					sample.rng.seed = seed_value
					assert(sample.start([a, b, c]))
					longest = maxf(longest, _finish(sample))
					assert(sample.income_for([a, b, c]) == 100 + 5 * (seed_value + 1))
	print("PASS: movement, ranges, targeting, skills, mana, and 202 fights. Longest: %.2fs." % longest)
	await _check_ui()
	quit()


func _finish(fight: RefCounted) -> float:
	var bank: int = fight.coins
	var wins := 0
	for hero in fight.heroes:
		wins += int(hero.wins)
	var tips := 0
	var ticks := 0
	while fight.active and ticks < 7200:
		var previous_bank: int = fight.coins
		for event in fight.advance(DT):
			assert(event.tip == (10 if event.kind == "skill" else 0))
			tips += int(event.tip)
			assert(event.coins == previous_bank + event.tip + (fight.payout if event.winner >= 0 else 0))
			previous_bank = event.coins
			for hit in event.hits:
				assert(hit.target != event.attacker and hit.damage > 0)
				var radius: float = event.radius if event.radius > 0.0 else fight.attack_range(event.attacker)
				assert(event.origin.distance_to(hit.position) <= radius + 0.001)
		for id in fight.participants:
			assert(fight.positions[id].length() <= Rules.ARENA_RADIUS + 0.001)
			assert(fight.health[id] >= 0 and fight.health[id] <= fight.heroes[id].health)
			assert(fight.mana[id] >= 0 and fight.mana[id] <= 100)
		ticks += 1
	assert(not fight.active, "Fight failed to terminate within 120 seconds: %s" % [fight.participants])
	assert(fight.survivors().size() == 1 and fight.last_winner == fight.survivors()[0])
	var after := 0
	for hero in fight.heroes:
		after += int(hero.wins)
	assert(after == wins + 1 and fight.coins == bank + fight.payout + tips)
	assert(fight.crowd_tips == tips and fight.pending_casts.is_empty())
	return ticks * DT


func _battle(lineup: Array[int] = [0, 1, 2]) -> RefCounted:
	var fight := Rules.new()
	fight.rng.seed = 7
	assert(fight.start(lineup))
	fight.action_order.assign(lineup)
	for id in lineup:
		fight.cooldowns[id] = 1000.0
		fight.pauses[id] = 1000.0
	fight.positions[lineup[0]] = Vector2.ZERO
	fight.positions[lineup[1]] = Vector2(40, 0)
	fight.positions[lineup[2]] = Vector2(0, 180)
	return fight


func _cast(fight: RefCounted, id: int) -> Dictionary:
	fight.mana[id] = 100
	fight.pending_casts.assign([id])
	var events: Array[Dictionary] = fight.advance(DT)
	assert(events.size() == 1)
	var event := events[0]
	assert(event.kind == "skill" and event.attacker == id and event.tip == 10)
	assert(fight.mana[id] == 0)
	return event


func _check_movement() -> void:
	var fight := _battle()
	assert(fight._target_for(0) == 1)
	fight.positions[1] = Vector2(80, 0)
	fight.positions[2] = Vector2(-80, 0)
	assert(fight._target_for(0) == 1, "Equal distances retain the current target.")
	var ties := {}
	for seed_value in range(20):
		fight.targets[0] = -1
		fight.rng.seed = seed_value
		var target: int = fight._target_for(0)
		ties[target] = true
		fight.targets[0] = -1
		fight.rng.seed = seed_value
		assert(fight._target_for(0) == target)
	assert(ties.size() == 2)
	fight.targets[0] = 1
	fight.target_timers[0] = 1.0
	fight.health[1] = 0
	fight.advance(DT)
	assert(fight.targets[0] == 2, "A dead target is replaced immediately.")
	fight = _battle()
	fight.positions[1] = Vector2(200, 0)
	fight.health[2] = 0
	fight.pauses[0] = 0.0
	fight.advance(DT)
	assert(fight.positions[0].is_equal_approx(Vector2(Rules.MELEE_SPEED * DT, 0)))
	assert(fight.velocities[0].x > 0.0 and fight.health[1] == 132)
	fight = _battle()
	fight.advance(DT)
	fight.positions[1] = Vector2(240, 0)
	fight.positions[2] = Vector2(80, 0)
	for i in range(16):
		fight.advance(DT)
	assert(fight.targets[0] == 2, "Reconsider targets every 0.25 seconds.")
	# Nia approaches, holds, retreats, then fights at the boundary.
	fight = _battle([0, 2, 3])
	fight.health[3] = 0
	fight.pauses[2] = 0.0
	fight.positions[2] = Vector2(200, 0)
	fight.advance(DT)
	assert(is_equal_approx(fight.positions[2].x, 200.0 - Rules.RANGED_SPEED * DT))
	fight.positions[2] = Vector2(130, 0)
	fight.advance(DT)
	assert(fight.positions[2] == Vector2(130, 0))
	fight.positions[2] = Vector2(90, 0)
	fight.advance(DT)
	assert(fight.positions[2].x > 90.0)
	fight.positions[0] = Vector2(220, 0)
	fight.positions[2] = Vector2(260, 0)
	fight.cooldowns[2] = 0.0
	assert(fight.advance(DT)[0].attacker == 2)
	assert(fight.positions[2] == Vector2(260, 0))
	# Separate exact overlaps gently.
	fight = _battle()
	fight.health[2] = 0
	fight.positions[1] = Vector2.ZERO
	fight.advance(DT)
	assert(fight.positions[0].distance_to(fight.positions[1]) > 0.0)
	assert(fight.positions[0].length() <= 30.0 * DT)
	for i in range(60):
		fight.advance(DT)
	assert(is_equal_approx(fight.positions[0].distance_to(fight.positions[1]), Rules.BODY_RADIUS * 2.0))


func _check_mana() -> void:
	var fight := _battle()
	fight.cooldowns[0] = 0.0
	var events: Array[Dictionary] = fight.advance(DT)
	assert(events.size() == 1 and events[0].attacker == 0)
	assert(fight.mana[0] == 25 and fight.mana[1] == 15 and fight.mana[2] == 0)
	assert(fight.advance(DT).is_empty(), "Respect independent attack cooldowns.")
	fight.cooldowns[0] = 0.0
	fight.mana[0] = 90
	fight.mana[1] = 90
	events = fight.advance(DT)
	assert(events.size() == 3)
	assert(events[0].kind == "attack" and events[1].attacker == 0 and events[2].attacker == 1)
	assert(events[1].kind == "skill" and events[2].kind == "skill")
	assert(fight.coins == 20 and fight.mana[0] == 0 and fight.mana[1] == 0 and fight.mana[2] == 0)
	assert(fight.cooldowns[0] == Rules.ATTACK_INTERVAL and fight.cooldowns[1] > 900)
	# An attacker's cast kills the ready defender: no defender tip.
	fight = _battle()
	fight.cooldowns[0] = 0.0
	fight.health[1] = 35
	fight.mana[0] = 75
	fight.mana[1] = 85
	events = fight.advance(DT)
	assert(events.size() == 2 and fight.health[1] == 0 and fight.coins == 10)
	assert(fight.pending_casts.is_empty())
	# A final normal kill cancels newly ready skills.
	fight = _battle()
	fight.health[1] = 1
	fight.health[2] = 0
	fight.mana[0] = 75
	fight.mana[1] = 95
	fight.cooldowns[0] = 0.0
	events = fight.advance(DT)
	assert(events.size() == 1 and events[0].winner == 0)
	assert(fight.mana[0] == 100 and fight.mana[1] == 95 and fight.coins == 100)
	assert(fight.crowd_tips == 0 and fight.pending_casts.is_empty())
	# Waiting for range cannot pay a tip or block another hero.
	fight = _battle()
	fight.positions[0] = Vector2(-200, 0)
	fight.positions[1] = Vector2.ZERO
	fight.positions[2] = Vector2(40, 0)
	fight.mana[0] = 100
	fight.cooldowns[0] = 0.0
	fight.cooldowns[1] = 0.0
	events = fight.advance(DT)
	assert(events.size() == 1 and events[0].attacker == 1 and fight.coins == 0)
	assert(fight.pending_casts == [0] and fight.mana[0] == 100)
	fight.positions[0] = Vector2(-45, 0)
	events = fight.advance(DT)
	assert(events[0].kind == "skill" and events[0].attacker == 0)
	assert(events[1].kind == "attack" and events[1].attacker == 0, "A cast does not consume a ready attack.")
	fight = _battle()
	fight.positions[1] = Vector2(45.1, 0)
	fight.cooldowns[0] = 0.0
	assert(fight.advance(DT).is_empty())
	fight.positions[1] = Vector2(45, 0)
	assert(fight.advance(DT).size() == 1)
	# Both ready heroes can attack in one physics tick; no global turn delay.
	fight = _battle()
	fight.cooldowns[0] = 0.0
	fight.cooldowns[1] = 0.0
	events = fight.advance(DT)
	assert(events.size() == 2 and events[0].attacker == 0 and events[1].attacker == 1)
	assert(fight.cooldowns[0] == Rules.ATTACK_INTERVAL and fight.cooldowns[1] == Rules.ATTACK_INTERVAL)


func _check_skills() -> void:
	var fight := _battle()
	var event := _cast(fight, 0)
	assert(event.hits[0].damage == 34 and event.hits[0].target == 1)
	assert(fight.coins == 10 and fight.mana[1] == 0)
	for distance in [89.0, 90.0, 90.1]:
		fight = _battle()
		fight.positions[1] = Vector2.ZERO
		fight.positions[0] = Vector2(-40, 0)
		fight.positions[2] = Vector2(0, distance)
		event = _cast(fight, 1)
		assert(event.hits.size() == (2 if distance <= 90.0 else 1))
		assert(event.radius == 90.0 and fight.health[0] == 129)
		assert(fight.health[2] == (89 if distance <= 90.0 else 110))
		assert(fight.coins == 10 and fight.mana[0] == 0 and fight.mana[2] == 0)
	fight = _battle()
	fight.positions[2] = Vector2(0, 100)
	fight.targets[2] = 1
	event = _cast(fight, 2)
	assert(event.hits[0].target == 0 and event.hits[0].damage == 45)
	fight.heroes[2].attack = 17
	assert(_cast(fight, 2).hits[0].damage == 43)
	fight = _battle()
	fight.positions[2] = Vector2(-160.1, 0)
	fight.mana[2] = 100
	assert(fight.advance(DT).is_empty() and fight.coins == 0)
	fight.positions[2] = Vector2(-160, 0)
	assert(fight.advance(DT)[0].tip == 10)
	fight = _battle([0, 3, 4])
	fight.health[3] = 70
	event = _cast(fight, 3)
	assert(event.hits.is_empty() and event.healing == 42 and fight.health[3] == 112)
	fight.health[3] = 135
	assert(_cast(fight, 3).healing == 5)
	assert(_cast(fight, 3).healing == 0 and fight.coins == 30)
	fight = _battle([0, 3, 4])
	fight.positions[4] = Vector2(-40, 0)
	fight.health[4] = 40
	fight.health[0] = 7
	event = _cast(fight, 4)
	assert(event.hits[0].damage == 7 and event.healing == 7 and fight.health[4] == 47)
	fight.positions[3] = Vector2.ZERO
	fight.health[4] = 103
	event = _cast(fight, 4)
	assert(event.hits[0].damage == 18 and event.healing == 2 and fight.health[4] == 105)
	fight = _battle()
	fight.positions[2] = Vector2(80, 0)
	fight.health[0] = 21
	fight.health[2] = 21
	fight.mana[1] = 100
	fight.mana[2] = 100
	fight.pending_casts.assign([1, 2])
	event = fight.advance(DT)[0]
	assert(event.winner == 1 and fight.survivors() == [1])
	assert(fight.coins == 110 and fight.crowd_tips == 10 and fight.heroes[1].wins == 1)
	assert(fight.pending_casts.is_empty() and fight.advance(DT).is_empty())
	var origin: Vector2 = event.origin
	fight.positions[1] += Vector2(10, 10)
	assert(event.origin == origin, "Effects retain their impact positions.")


func _check_reproducibility() -> void:
	var first := Rules.new()
	var second := Rules.new()
	first.rng.seed = 123
	second.rng.seed = 123
	assert(first.start([0, 2, 4]) and second.start([0, 2, 4]))
	for i in range(7200):
		assert(first.advance(DT) == second.advance(DT))
		assert(first.positions == second.positions)
		if not first.active:
			break
	assert(not first.active and first.coins == second.coins)


func _check_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(ui.cards.size() == 5 and ui.selected.size() == 3 and ui.cards[3].disabled)
	ui.cards[0].pressed.emit()
	assert(ui.selected.size() == 2 and ui.get_node("%Start").disabled)
	ui.cards[3].pressed.emit()
	assert(ui.selected == [1, 2, 3])
	await _capture("booking")
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and ui.auto_fight and ui.get_node("%Tick").is_stopped())
	var start: Vector2 = ui.fighters[1].body.position
	for i in range(60):
		ui._physics_process(DT)
	assert(ui.fighters[1].body.position != start)
	assert(ui.fighters[1].sprite.animation == "run")
	await _capture("combat")
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and not ui.auto_fight)
	ui._select_hero(1)
	assert(ui.selected == [1, 2, 3])
	for id in ui.selected:
		ui.fight.cooldowns[id] = 1000.0
		ui.fight.pauses[id] = 1000.0
	ui.fight.positions[1] = Vector2.ZERO
	ui.fight.positions[2] = Vector2(70, -30)
	ui.fight.positions[3] = Vector2(-60, 30)
	ui.fight.health[3] = 70
	ui.fight.mana[3] = 100
	ui._physics_process(DT)
	# No frame or animation wait: payment and feedback happen on this call.
	assert(ui.fight.coins == 10 and ui.get_node("%Coins").text == "10 coins")
	assert(ui.get_node("%Tips").text == "CROWD TIPS  +10")
	assert(ui.fighters[3].mana.value == 0 and ui.fighters[3].bar.value == 112)
	assert(ui.get_node("%Stage").has_node("SkillTip"))
	await _capture("skill-tip")
	ui.fight.mana[1] = 100
	ui._physics_process(DT)
	assert(ui.fight.coins == 20 and ui.get_node("%Coins").text == "20 coins")
	assert(ui.effects[-1].event.radius == 90.0)
	var popups := 0
	for node in ui.get_node("%Stage").get_children():
		if node.has_meta("skill_tip"):
			popups += 1
	assert(popups == 2)
	assert(ui.fighters[2].body.z_index < ui.fighters[1].body.z_index)
	assert(ui.fighters[1].body.z_index < ui.fighters[3].body.z_index)
	await _capture("overlapping-tips")
	for id in ui.selected:
		ui.fight.cooldowns[id] = 0.0
		ui.fight.pauses[id] = 0.0
	_finish_ui(ui)
	assert(ui.fight.completed == 1 and ui.fight.coins == 100 + ui.fight.crowd_tips)
	assert(ui.get_node("%Tick").is_stopped() and not ui.get_node("%Start").disabled)
	assert(ui.get_node("%Income").text == "Guaranteed: 105 coins + skill tips")
	assert("Tips already paid" in ui.get_node("%Commentary").text)
	await create_timer(0.85).timeout
	for id in ui.fighters:
		if ui.fight.health[id] == 0:
			assert(ui.fighters[id].sprite.modulate == Color("515c68"))
	await _capture("winner")
	ui.get_node("%Start").pressed.emit()
	assert(ui.effects.is_empty() and ui.get_node("%Tips").text == "CROWD TIPS  +0")
	for id in ui.selected:
		assert(ui.fighters[id].mana.value == 0)
	_finish_ui(ui)
	assert(not ui.get_node("%Tick").is_stopped())
	ui.get_node("%Start").pressed.emit()
	ui._intermission_finished()
	assert(not ui.fight.active and not ui.auto_fight and ui.get_node("%Tick").is_stopped())
	ui.get_node("%Start").pressed.emit()
	_finish_ui(ui)
	ui._intermission_finished()
	assert(ui.fight.active and ui.fight.completed == 3)
	ui.queue_free()
	await process_frame
	print("PASS: UI movement/depth, immediate money/popups, Sweep, resets, settlement, and stop/rebook/repeat.")


func _finish_ui(ui: Control) -> void:
	for i in range(7200):
		if not ui.fight.active:
			break
		ui._physics_process(DT)
	assert(not ui.fight.active)


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/fight-%s.png" % label) == OK)
