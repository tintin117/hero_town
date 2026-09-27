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
	_check_progression()
	_check_arena_income()
	_check_excitement()
	_check_recovery()
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
	fight.advance(Rules.REST_DURATION)
	assert(fight.start([0, 1, 2]))
	assert(fight.crowd_tips == 0 and fight.pending_casts.is_empty())
	for id in fight.participants:
		assert(fight.health[id] == fight.stats_for(id).health and fight.mana[id] == 0)
		assert(fight.velocities[id] == Vector2.ZERO and fight.pauses[id] == 0.0)
		assert(fight.targets[id] == -1 and fight.cooldowns[id] <= 0.3)
	_finish(fight)
	var longest := 0.0
	var tiers := [0, 0, 0]
	for a in range(3):
		for b in range(a + 1, 4):
			for c in range(b + 1, 5):
				var sample := Rules.new()
				for seed_value in range(20):
					sample.rng.seed = seed_value
					sample.advance(Rules.REST_DURATION)
					assert(sample.start([a, b, c]))
					longest = maxf(longest, _finish(sample))
					tiers[Rules.excitement_tier(sample.excitement)] += 1
					var level_bonus := 0
					for id in [a, b, c]:
						level_bonus += 5 * (int(sample.heroes[id].level) - 1)
					assert(sample.income_for([a, b, c]) == 100 + level_bonus + 5 * (seed_value + 1))
				# Mixed-level bookings and the cap must also terminate and settle correctly.
				for levels in [[1, 5, 10], [10, 10, 10]]:
					var leveled := Rules.new()
					leveled.rng.seed = 12
					for index in range(3):
						leveled.heroes[[a, b, c][index]].level = levels[index]
					assert(leveled.start([a, b, c]))
					longest = maxf(longest, _finish(leveled))
	print("PASS: excitement, arena/level income, flat tips, XP, movement, mana, and 222 seeded/regression fights. Longest: %.2fs. Normal/Excited/Wild: %s" % [longest, tiers])
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 420)
	await _check_ui()
	await _check_arena_ui()
	await _check_excitement_ui()
	await _check_combat_feedback()
	await _check_promenade_ui()
	await _check_recovery_ui()
	await _check_town_grid()
	quit()


func _finish(fight: RefCounted) -> float:
	var bank: int = fight.coins
	var wins := 0
	for hero in fight.heroes:
		wins += int(hero.wins)
	var tips := 0
	var xp_before := []
	for hero in fight.heroes:
		xp_before.append(_total_xp(hero))
	var ticks := 0
	while fight.active and ticks < 7200:
		var previous_bank: int = fight.coins
		for event in fight.advance(DT):
			assert(event.tip == (10 if event.kind == "skill" else 0))
			assert(event.time == fight.elapsed)
			tips += int(event.tip)
			assert(event.coins == previous_bank + event.tip + (fight.settled_income if event.winner >= 0 else 0))
			previous_bank = event.coins
			for hit in event.hits:
				assert(hit.target != event.attacker and hit.damage > 0)
				var radius: float = event.radius if event.radius > 0.0 else fight.attack_range(event.attacker)
				assert(event.origin.distance_to(hit.position) <= radius + 0.001)
		for id in fight.participants:
			assert(fight.positions[id].length() <= Rules.ARENA_RADIUS + 0.001)
			assert(fight.health[id] >= 0 and fight.health[id] <= fight.battle_stats[id].health)
			assert(fight.mana[id] >= 0 and fight.mana[id] <= 100)
		ticks += 1
	assert(not fight.active, "Fight failed to terminate within 120 seconds: %s" % [fight.participants])
	assert(fight.survivors().size() == 1 and fight.last_winner == fight.survivors()[0])
	var after := 0
	for hero in fight.heroes:
		after += int(hero.wins)
	assert(after == wins + 1 and fight.coins == bank + fight.settled_income + tips)
	var expected_excitement := minf(100.0, minf(fight.elapsed, 20.0) + tips * 0.8)
	assert(is_equal_approx(fight.excitement, expected_excitement))
	var multiplier := 2.5 if expected_excitement >= 60.0 else (1.25 if expected_excitement >= 25.0 else 1.0)
	assert(fight.settled_income == roundi(fight.payout * multiplier))
	assert(fight.crowd_tips == tips and fight.pending_casts.is_empty())
	for id in range(fight.heroes.size()):
		var gained := (20 if id == fight.last_winner else 10) if id in fight.participants else 0
		assert(_total_xp(fight.heroes[id]) == mini(990, xp_before[id] + gained))
	return ticks * DT


func _total_xp(hero: Dictionary) -> int:
	var total: int = hero.xp
	for level in range(1, hero.level):
		total += 30 + 20 * (level - 1)
	return total


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
	fight.battle_stats[2].attack = 17
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


func _check_progression() -> void:
	var fight := Rules.new()
	assert(fight.xp_needed(0) == 30 and fight.income_for([0, 1, 2]) == 100)
	fight._award_xp(0, 29)
	assert(fight.heroes[0].level == 1 and fight.heroes[0].xp == 29)
	fight._award_xp(0, 1)
	assert(fight.heroes[0].level == 2 and fight.heroes[0].xp == 0 and fight.xp_needed(0) == 50)
	assert(fight.stats_for(0) == {"health": 158, "attack": 18} and fight.income_for([0, 1, 2]) == 105)
	# Carry overflow across multiple thresholds and derive stats from the original base.
	fight._award_xp(0, 130)
	assert(fight.heroes[0].level == 4 and fight.heroes[0].xp == 10 and fight.xp_needed(0) == 90)
	assert(fight.stats_for(0) == {"health": 173, "attack": 20} and fight.income_for([0, 1, 2]) == 115)
	fight._award_xp(0, 10000)
	assert(fight.heroes[0].level == 10 and fight.heroes[0].xp == 0 and fight.xp_needed(0) == 0)
	assert(fight.stats_for(0) == {"health": 218, "attack": 25} and fight.income_for([0, 1, 2]) == 145)
	assert(fight.heroes[0].health == 150 and fight.heroes[0].attack == 17)
	assert(fight._award_xp(0, 20).xp == 0 and fight.heroes[0].xp == 0)
	# Level-ups affect the next guarantee; the current fight keeps its quoted payout.
	fight = _battle()
	for id in fight.participants:
		fight.heroes[id].xp = 20
	fight.positions[2] = Vector2(80, 0)
	fight.health[0] = 21
	fight.health[2] = 21
	var event := _cast(fight, 1)
	assert(event.winner == 1 and event.tip == 10 and fight.coins == 110)
	assert(event.progression.size() == 3)
	assert(fight.heroes[1].level == 2 and fight.heroes[1].xp == 10)
	assert(fight.heroes[0].level == 2 and fight.heroes[0].xp == 0)
	assert(fight.heroes[2].level == 2 and fight.heroes[2].xp == 0)
	assert(fight.heroes[3].level == 1 and fight.heroes[3].xp == 0)
	assert(fight.battle_stats[1] == {"health": 132, "attack": 21})
	var records: Array = fight.heroes.duplicate(true)
	assert(fight.advance(DT).is_empty() and fight.heroes == records and fight.coins == 110)
	fight.advance(Rules.REST_DURATION)
	assert(fight.start([0, 1, 2]))
	assert(fight.battle_stats[1] == {"health": 139, "attack": 22})
	assert(fight.health[1] == 139 and fight.heroes[1].xp == 10 and fight.payout == 120)
	# Scaled attacks, healing caps, and cast payments still share the same rules.
	fight = Rules.new()
	fight.heroes[0].level = 10
	fight.heroes[3].level = 10
	fight.heroes[4].level = 10
	assert(fight.start([0, 3, 4]))
	for id in fight.participants:
		fight.cooldowns[id] = 1000.0
		fight.pauses[id] = 1000.0
	fight.positions[0] = Vector2.ZERO
	fight.positions[3] = Vector2(40, 0)
	fight.positions[4] = Vector2(-40, 0)
	fight.targets[0] = 3
	event = _cast(fight, 0)
	assert(event.hits[0].damage == 50 and event.tip == 10 and fight.coins == 10)
	fight.health[3] = 100
	assert(_cast(fight, 3).healing == 61 and fight.health[3] == 161)
	fight.health[3] = 200
	assert(_cast(fight, 3).healing == 3 and fight.health[3] == 203)
	fight.health[0] = 7
	fight.health[4] = 100
	event = _cast(fight, 4)
	assert(event.hits[0].damage == 7 and event.healing == 7 and fight.health[4] == 107)
	assert(fight.coins == 40)


func _check_arena_income() -> void:
	var fight := Rules.new()
	fight.heroes[0].level = 5
	fight.heroes[1].level = 6
	fight.heroes[2].level = 10
	fight.heroes[4].level = 10
	fight.heroes[4].wins = 100
	assert(fight.income_breakdown([0, 1, 2]) == {"base": 100, "levels": 90, "victories": 0, "multiplier": 1.0, "guaranteed": 190})
	assert(fight.income_for([0, 0, 1]) == 0 and fight.income_breakdown([0, 1]).is_empty())
	fight.coins = 499
	assert(not fight.upgrade_arena() and fight.coins == 499 and fight.arena_capacity() == 100)
	fight.coins = 500
	assert(fight.upgrade_arena() and fight.coins == 0 and fight.arena_capacity() == 150)
	assert(fight.income_for([0, 1, 2]) == 285 and fight.arena_upgrade_cost() == 1000)
	fight.heroes[0].wins = 1
	assert(fight.income_for([0, 1, 2]) == 293, "Round the final capacity-scaled payout once, including half coins.")
	fight.coins = 999
	assert(not fight.upgrade_arena() and fight.coins == 999 and fight.arena_capacity() == 150)
	fight.coins = 1000
	assert(fight.upgrade_arena() and fight.coins == 0 and fight.arena_capacity() == 200)
	assert(fight.income_for([0, 1, 2]) == 390)
	fight.heroes[0].wins = 0
	assert(fight.income_for([0, 1, 2]) == 380)
	fight.coins = 10000
	assert(fight.arena_upgrade_cost() == 0 and not fight.upgrade_arena() and fight.coins == 10000)
	# Expansion during combat preserves the paid quote, geometry, and fighter stats.
	fight = _battle()
	var positions: Dictionary = fight.positions.duplicate()
	var stats: Dictionary = fight.battle_stats.duplicate(true)
	fight.coins = 500
	assert(fight.upgrade_arena())
	assert(fight.payout == 100 and fight.positions == positions and fight.battle_stats == stats)
	for id in fight.participants:
		fight.cooldowns[id] = 0.0
		fight.pauses[id] = 0.0
	_finish(fight)
	assert(fight.coins == fight.settled_income + fight.crowd_tips and fight.payout == 100)
	fight.advance(Rules.REST_DURATION)
	assert(fight.start([0, 1, 2]) and fight.arena_capacity() == 150 and fight.payout == 158)


func _check_excitement() -> void:
	var fight := _battle()
	assert(fight.excitement == 0.0 and fight.elapsed == 0.0 and fight.settled_income == 0)
	for delta in [0.0, -1.0, INF, NAN]:
		assert(fight.advance(delta).is_empty() and fight.excitement == 0.0 and fight.elapsed == 0.0)
	for delta in [0.25, 0.75, 18.5, 0.5, 20.0]:
		assert(fight.advance(delta).is_empty())
		assert(is_equal_approx(fight.excitement, minf(fight.elapsed, 20.0)))
	assert(fight.excitement == 20.0 and fight.coins == 0)
	for entry in [[0.0, 100], [24.999, 100], [25.0, 125], [59.999, 125], [60.0, 250], [100.0, 250]]:
		assert(fight.income_with_excitement(entry[0]) == entry[1])
	fight.payout = 285
	assert(fight.income_with_excitement(60.0) == 713, "Round the boosted payout, including half coins.")
	# A waiting skill contributes only elapsed time; normal hits add no excitement.
	fight = _battle()
	fight.positions[0] = Vector2(-200, 0)
	fight.mana[0] = 100
	assert(fight.advance(DT).is_empty() and is_equal_approx(fight.excitement, DT))
	fight.positions[0] = Vector2.ZERO
	var event: Dictionary = fight.advance(DT)[0]
	assert(event.excitement_gain == 8.0 and is_equal_approx(event.excitement, 8.0 + 2.0 * DT))
	fight.cooldowns[0] = 0.0
	event = fight.advance(DT)[0]
	assert(event.excitement_gain == 0.0 and is_equal_approx(event.excitement, 8.0 + 3.0 * DT))
	# Same-frame casts retain ordered score snapshots, one increment each.
	fight = _battle()
	fight.mana[0] = 100
	fight.mana[1] = 100
	var events: Array[Dictionary] = fight.advance(DT)
	assert(events.size() == 2 and is_equal_approx(events[0].excitement, 8.0 + DT))
	assert(is_equal_approx(events[1].excitement, 16.0 + DT) and fight.coins == 20)
	# Full-health healing counts, the bar caps at 100, and tips remain flat.
	fight = _battle([0, 3, 4])
	for i in range(13):
		event = _cast(fight, 3)
		assert(event.healing == 0 and event.tip == 10)
	assert(fight.excitement == 100.0 and event.excitement_gain < 8.0 and fight.coins == 130)
	assert(_cast(fight, 3).excitement_gain == 0.0 and fight.coins == 140)
	# A final Sweep crosses a tier before settlement, pays once, and cancels a ready victim.
	for score in [17.0, 52.0]:
		fight = _battle()
		fight.excitement = score
		fight.elapsed = 20.0
		fight.positions[2] = Vector2(80, 0)
		fight.health[0] = 21
		fight.health[2] = 21
		fight.mana[1] = 100
		fight.mana[2] = 100
		fight.pending_casts.assign([1, 2])
		events = fight.advance(DT)
		var expected := 125 if score == 17.0 else 250
		assert(events.size() == 1 and events[0].winner == 1 and events[0].excitement_gain == 8.0)
		assert(fight.excitement == score + 8.0 and fight.settled_income == expected)
		assert(fight.coins == expected + 10 and fight.crowd_tips == 10 and fight.pending_casts.is_empty())
		var elapsed: float = fight.elapsed
		assert(fight.advance(30.0).is_empty() and fight.excitement == score + 8.0 and fight.elapsed == elapsed)
		assert(fight.coins == expected + 10 and fight.heroes[1].wins == 1)
		var lineup: Array[int] = [0, 1, 2]
		assert(fight.start(lineup) and fight.excitement == 0.0 and fight.elapsed == 0.0)
		assert(fight.settled_income == 0 and fight.crowd_tips == 0 and fight.coins == expected + 10)
	# A normal final hit cannot cash in a newly ready skill or its excitement.
	fight = _battle()
	fight.excitement = 17.0
	fight.elapsed = 20.0
	fight.health[1] = 1
	fight.health[2] = 0
	fight.mana[0] = 75
	fight.cooldowns[0] = 0.0
	assert(fight.advance(DT).size() == 1 and fight.excitement == 17.0 and fight.coins == 100)
	print("PASS: excitement timing, thresholds, capped gains, ordered casts, final-cast bonus, cancellation, and one-time settlement.")


func _check_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(ui.cards.size() == 5 and ui.selected.size() == 3 and ui.cards[3].disabled)
	ui.get_node("%HeroesButton").pressed.emit()
	ui.cards[0].pressed.emit()
	assert(ui.selected.size() == 2 and ui.get_node("%Start").disabled)
	ui.cards[3].pressed.emit()
	assert(ui.selected == [1, 2, 3])
	assert(ui.card_details[1].level.text == "LV 1  /  0/30 XP")
	assert(ui.card_details[1].skill.text == "Sweep / 10 coins")
	# A near-level-up booking exercises the locked payout and next fight's level bonus.
	for id in ui.selected:
		ui.fight.heroes[id].xp = 20
	ui._refresh()
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
	assert(ui.get_node("%Tips").text == "10 tips paid")
	assert(ui.fighters[3].mana.value == 0 and ui.fighters[3].bar.value == 112)
	assert(ui.feedback.toast.text == "Crowd tips +10")
	await _capture("skill-tip")
	ui.fight.mana[1] = 100
	ui._physics_process(DT)
	assert(ui.fight.coins == 20 and ui.get_node("%Coins").text == "20 coins")
	assert(ui.feedback.effects[-1].event.radius == 90.0)
	var popups := 0
	for node in ui.feedback.world.get_children():
		if node.get_meta("feedback_kind", "") == "skill_name":
			popups += 1
	assert(popups == 2)
	assert(ui.fighters[2].body.z_index < ui.fighters[1].body.z_index)
	assert(ui.fighters[1].body.z_index < ui.fighters[3].body.z_index)
	await _capture("overlapping-tips")
	for id in ui.selected:
		ui.fight.cooldowns[id] = 0.0
		ui.fight.pauses[id] = 0.0
	_finish_ui(ui)
	assert(ui.fight.completed == 1 and ui.fight.coins == ui.fight.settled_income + ui.fight.crowd_tips)
	assert(ui.get_node("%Tick").is_stopped() and not ui.get_node("%Start").disabled)
	assert(ui.get_node("%Income").text == "120 coins")
	assert("+15 hero levels" in ui.get_node("%Formula").text)
	assert("Tips already paid" in ui.get_node("%Commentary").tooltip_text)
	assert("Level up:" in ui.get_node("%Status").text and "XP" in ui.get_node("%Hint").text)
	for id in ui.selected:
		assert(ui.fight.heroes[id].level == 2)
		assert("LV 2" in ui.card_details[id].level.text and "10 coins" in ui.card_details[id].skill.text)
		assert(ui.card_details[id].xp.value == ui.fight.heroes[id].xp)
		assert(ui.fighters[id].bar.max_value == ui.fight.battle_stats[id].health)
	await create_timer(0.85).timeout
	for id in ui.fighters:
		if ui.fight.health[id] == 0:
			assert(ui.fighters[id].sprite.modulate == Color("515c68"))
	await _capture("winner")
	ui.get_node("%Start").pressed.emit()
	assert(not ui.fight.active and ui.auto_fight)
	ui._physics_process(Rules.REST_DURATION)
	assert(ui.feedback.effects.is_empty() and ui.get_node("%Tips").text == "0 tips paid")
	for id in ui.selected:
		assert(ui.fighters[id].mana.value == 0)
		assert(ui.fighters[id].bar.max_value == ui.fight.stats_for(id).health)
	var bank: int = ui.fight.coins
	for id in ui.selected:
		ui.fight.cooldowns[id] = 1000.0
	ui.fight.mana[3] = 100
	ui._physics_process(DT)
	assert(ui.fight.coins == bank + 10 and ui.get_node("%Coins").text == "%d coins" % (bank + 10))
	assert(ui.get_node("%Tips").text == "10 tips paid")
	assert(ui.feedback.toast.text == "Crowd tips +10")
	await _capture("level-tip")
	for id in ui.selected:
		ui.fight.cooldowns[id] = 0.0
	_finish_ui(ui)
	assert(not ui.get_node("%Tick").is_stopped())
	ui.get_node("%Start").pressed.emit()
	ui._intermission_finished()
	assert(not ui.fight.active and not ui.auto_fight and ui.get_node("%Tick").is_stopped())
	ui.get_node("%Start").pressed.emit()
	ui._physics_process(Rules.REST_DURATION)
	_finish_ui(ui)
	ui._intermission_finished()
	ui._physics_process(Rules.REST_DURATION)
	assert(ui.fight.active and ui.fight.completed == 3)
	ui.fight.heroes[4].level = 10
	ui._refresh()
	assert(ui.card_details[4].level.text == "LV 10  /  MAX" and ui.card_details[4].xp.value == 1)
	assert("10 coins" in ui.card_details[4].skill.text)
	ui.queue_free()
	await process_frame
	print("PASS: UI XP/levels, flat cast tips, movement, resets, settlement, and stop/rebook/repeat.")


func _check_arena_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	ui.fight.heroes[0].level = 5
	ui.fight.heroes[1].level = 6
	ui.fight.heroes[2].level = 10
	ui._show_fighters(ui.selected)
	ui._refresh()
	assert(ui.get_node("%Capacity").text == "100 seats" and ui.get_node("%Expand").disabled)
	assert(ui.get_node("%Income").text == "190 coins" and "+90 hero levels" in ui.get_node("%Formula").text)
	ui.get_node("%ArenaButton").pressed.emit()
	await _capture("arena-booking")
	ui.fight.coins = 500
	ui._refresh()
	assert(not ui.get_node("%Expand").disabled)
	ui.get_node("%Expand").pressed.emit()
	assert(ui.fight.coins == 0 and ui.get_node("%Coins").text == "0 coins")
	assert(ui.get_node("%Income").text == "285 coins" and ui.get_node("%Capacity").text == "150 seats")
	assert(ui.get_node("%Expand").disabled and "1000 coins" in ui.get_node("%Expand").text)
	await _capture("arena-upgrade")
	ui.get_node("%Start").pressed.emit()
	ui.get_node("%Start").pressed.emit()
	ui.fight.coins = 1000
	ui._refresh()
	ui.get_node("%Expand").pressed.emit()
	assert(ui.fight.payout == 285 and ui.get_node("%Income").text == "380 coins")
	assert("285 base" in ui.get_node("%Status").text)
	assert(ui.get_node("%Expand").disabled and ui.get_node("%Expand").text == "Fully expanded")
	assert(ui.get_node("%Capacity").text == "200 seats" and ui.fight.coins == 0)
	ui._expand_arena()
	assert(ui.fight.coins == 0 and ui.fight.arena_capacity() == 200)
	await _capture("arena-expanded")
	_finish_ui(ui)
	assert(ui.fight.coins == ui.fight.settled_income + ui.fight.crowd_tips and ui.get_node("%Income").text == "390 coins")
	# Buying an upgrade becomes possible immediately when a tip crosses its price.
	ui.fight.arena_tier = 0
	ui.fight.coins = 490
	ui.get_node("%Start").pressed.emit()
	ui._physics_process(Rules.REST_DURATION)
	for id in ui.selected:
		ui.fight.cooldowns[id] = 1000.0
		ui.fight.pauses[id] = 1000.0
	ui.fight.positions[0] = Vector2.ZERO
	ui.fight.positions[1] = Vector2(40, 0)
	ui.fight.positions[2] = Vector2(200, 0)
	ui.fight.mana[0] = 100
	assert(ui.get_node("%Expand").disabled)
	ui._physics_process(DT)
	assert(ui.fight.coins == 500 and not ui.get_node("%Expand").disabled)
	ui.queue_free()
	await process_frame
	print("PASS: arena income breakdown, purchasing, max capacity, quote snapshots, and instant affordability.")


func _check_excitement_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(ui.get_node("%Excitement").value == 0 and "NORMAL" in ui.get_node("%ExcitementLabel").text)
	assert(ui.get_node("%Multiplier").text == "x1.00")
	ui.get_node("%Start").pressed.emit()
	for id in ui.selected:
		ui.fight.cooldowns[id] = 1000.0
		ui.fight.pauses[id] = 1000.0
	ui.fight.excitement = 24.5
	ui.fight.elapsed = 19.5
	ui._physics_process(0.5)
	assert(ui.get_node("%Excitement").value == 25.0 and ui.displayed_tier == 1)
	assert("EXCITED" in ui.get_node("%ExcitementLabel").text and ui.get_node("%Multiplier").text == "x1.25")
	assert(ui.get_node("%FightIncome").text == "125 at finish" and ui.fight.coins == 0)
	await _capture("excitement-excited")
	ui.fight.positions[0] = Vector2(-40, 0)
	ui.fight.positions[1] = Vector2.ZERO
	ui.fight.positions[2] = Vector2(80, 0)
	ui.fight.excitement = 52.0
	ui.fight.mana[1] = 100
	ui._physics_process(DT)
	assert(ui.get_node("%Excitement").value == 60.0 and ui.displayed_tier == 2)
	assert("WILD" in ui.get_node("%ExcitementLabel").text and ui.get_node("%Multiplier").text == "x2.50")
	assert(ui.get_node("%FightIncome").text == "250 at finish")
	assert(ui.get_node("%Coins").text == "10 coins" and "+8 excitement" in ui.get_node("%Commentary").text)
	assert(ui.feedback.toast.text == "Crowd tips +10")
	await _capture("excitement-wild")
	ui.fight.health[0] = 21
	ui.fight.health[2] = 21
	ui.fight.mana[1] = 100
	ui._physics_process(DT)
	assert(ui.fight.coins == 270 and ui.get_node("%Coins").text == "270 coins")
	assert("100 base x2.50 = 250" in ui.get_node("%Commentary").tooltip_text)
	assert("20 tips paid = 270 earned" in ui.get_node("%Commentary").text)
	assert(ui.get_node("%FightIncome").text == "250 paid / last fight")
	await _capture("excitement-result")
	ui.get_node("%Tick").stop()
	ui._intermission_finished()
	ui._physics_process(Rules.REST_DURATION)
	assert(ui.fight.active and ui.get_node("%Excitement").value == 0 and ui.displayed_tier == 0)
	assert(ui.get_node("%ExcitementMeter").modulate == Color.WHITE)
	assert(ui.get_node("%FightIncome").text == "105 at finish")
	assert(not ui.feedback.toast.visible and ui.feedback.world.get_child_count() == 0)
	ui.queue_free()
	await process_frame
	print("PASS: excitement bar, time/cast tier feedback, projected income, result breakdown, and repeat reset.")


func _check_combat_feedback() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	# Actual events from all five skills produce one damage label per victim.
	for actor in range(5):
		var lineup: Array[int] = []
		lineup.assign([0, 1, 2] if actor < 3 else [0, 3, 4])
		ui.fight = _battle(lineup)
		ui.selected.assign(ui.fight.participants)
		for index in range(3):
			ui.fight.positions[ui.selected[index]] = Vector2(index * 35, 0)
		ui.fight.health[actor] -= 40
		ui._show_fighters(ui.selected)
		var event := _cast(ui.fight, actor)
		var rng_before: int = ui.fight.rng.state
		ui._present_action(event)
		assert(ui.fight.rng.state == rng_before, "Cosmetic effects must not consume combat RNG.")
		var labels: Array = _feedback_labels(ui, "damage")
		assert(labels.size() == event.hits.size())
		for index in range(labels.size()):
			assert(labels[index].text == str(event.hits[index].damage))
			assert(labels[index].global_position.y >= ui.get_node("%Bank").get_global_rect().end.y)
		var heals: Array = _feedback_labels(ui, "healing")
		assert(heals.size() == (1 if event.healing > 0 else 0))
		if not heals.is_empty():
			assert(heals[0].text == "+%d" % event.healing)
		assert(_feedback_labels(ui, "skill_name").size() == 1)
		assert(ui.feedback.toast.text == "Crowd tips +10")
		assert(ui.feedback.world.get_parent() == ui.get_node("%Stage"))
		assert(ui.feedback.hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		await _capture("feedback-skill-%d" % actor)
	# Normal damage, overkill, two victims, and winning animation follow-through.
	ui.fight = _battle()
	ui.selected.assign([0, 1, 2])
	ui._show_fighters(ui.selected)
	ui.fight.health[1] = 1
	ui.fight.health[2] = 0
	ui.fight.cooldowns[0] = 0
	ui._physics_process(DT)
	var labels: Array = _feedback_labels(ui, "damage")
	assert(labels.size() == 1 and labels[0].text == "1")
	assert(ui.fighters[0].sprite.animation == "attack" and ui.fighters[0].sprite.is_playing())
	ui._sync_fighters()
	assert(ui.fighters[0].sprite.animation == "attack")
	await create_timer(1.25).timeout
	assert(ui.fighters[0].sprite.animation == "idle")
	assert(ui.feedback.world.get_child_count() == 0, "Transient effect nodes must free themselves.")
	# Presentation aggregation never modifies the bank or consumes model RNG.
	ui.fight = _battle([0, 3, 4])
	ui.selected.assign([0, 3, 4])
	ui._show_fighters(ui.selected)
	var event := _cast(ui.fight, 3)
	var bank: int = ui.fight.coins
	event.time = 0.0
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 0)
	ui.feedback.clock += 0.25
	event.time = 2.0
	ui.feedback.present(event)
	assert(ui.feedback.toast.text == "Crowd tips +20")
	assert(ui.feedback.pending_celebration == 1 and ui.feedback.burst_until == 6.0)
	ui.feedback.tier_crossed(1)
	ui.feedback.flush_celebration()
	assert(ui.feedback.fireworks.size() == 1 and ui.feedback.fireworks[0].strength == 2)
	ui.feedback.clock += 0.251
	event.time = 3.0
	ui.feedback.present(event)
	assert(ui.feedback.toast.text == "Crowd tips +10" and ui.feedback.pending_celebration == 0)
	event.time = 5.9
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 0)
	event.time = 6.0
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 1)
	ui.feedback.flush_celebration()
	ui.feedback.reset()
	event.excitement_gain = 0.0
	ui.feedback.present(event)
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 0 and ui.feedback.gains.is_empty())
	event.excitement_gain = 7.9
	ui.feedback.present(event)
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 0, "Use actual gains, not the number of casts.")
	assert(ui.fight.coins == bank)
	ui.feedback.reset()
	event.time = 0.0
	event.excitement_gain = 8.0
	ui.feedback.present(event)
	event.time = 2.001
	ui.feedback.present(event)
	assert(ui.feedback.pending_celebration == 0, "Gains older than two seconds cannot trigger a burst.")
	ui.feedback.reset()
	assert(ui.feedback.world.get_child_count() == 0 and ui.feedback.hud.get_child_count() == 1)
	assert(ui.feedback.fireworks.is_empty() and ui.feedback.gains.is_empty() and not ui.feedback.toast.visible)
	ui.queue_free()
	await process_frame
	var opening := Rules.new()
	var distribution := [0, 0, 0]
	for seed_value in range(20):
		opening.advance(8.0)
		opening.rng.seed = seed_value
		assert(opening.start([0, 1, 2]))
		_finish(opening)
		distribution[Rules.excitement_tier(opening.excitement)] += 1
	print("PASS: damage/healing on all five skills, winner follow-through, fixed tips, aggregation, rapid celebrations, and effect cleanup. Opening twenty default fights Normal/Excited/Wild: %s" % [distribution])


func _feedback_labels(ui: Control, kind: String) -> Array:
	return ui.feedback.world.get_children().filter(func(node: Node): return node.get_meta("feedback_kind", "") == kind)


func _check_promenade_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(not ui.get_node("%HeroesDrawer").visible and not ui.get_node("%ArenaDrawer").visible)
	assert(not ui.get_node("%Dismiss").visible)
	await _capture("promenade")
	ui.get_node("%HeroesButton").pressed.emit()
	assert(ui.get_node("%HeroesDrawer").visible and ui.get_node("%Dismiss").visible)
	await process_frame
	await process_frame
	assert(ui.get_node("%Scroll").get_global_rect().encloses(ui.cards[4].get_global_rect()), "All five heroes fit without scrolling at default size.")
	assert(ui.get_viewport().gui_get_focus_owner() == ui.get_node("%CloseHeroes"))
	ui.cards[0].pressed.emit()
	assert(ui.selected.size() == 2 and ui.get_node("%Start").disabled)
	assert(ui.get_node("%FightIncome").text == "Book three heroes")
	ui.cards[4].pressed.emit()
	assert(ui.selected == [1, 2, 4] and not ui.get_node("%Start").disabled)
	assert(ui.get_node("%HeroesButton").text == "Heroes  3/3")
	await _capture("promenade-heroes")
	ui.get_node("%ArenaButton").pressed.emit()
	assert(not ui.get_node("%HeroesDrawer").visible and ui.get_node("%ArenaDrawer").visible)
	ui.fight.coins = 1500
	ui._refresh_money()
	ui.get_node("%Expand").pressed.emit()
	ui.get_node("%Expand").pressed.emit()
	assert(ui.fight.arena_capacity() == 200 and ui.fight.coins == 0)
	await _capture("promenade-arena")
	ui.get_node("%Dismiss").pressed.emit()
	assert(not ui.get_node("%ArenaDrawer").visible and not ui.get_node("%Dismiss").visible)
	assert(ui.get_viewport().gui_get_focus_owner() == ui.get_node("%ArenaButton"))
	ui.get_node("%HeroesButton").pressed.emit()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui._unhandled_key_input(escape)
	assert(not ui.get_node("%HeroesDrawer").visible)
	ui.get_node("%Start").pressed.emit()
	ui.get_node("%HeroesButton").pressed.emit()
	assert(ui.get_node("%HeroesDrawer").visible and ui.cards[1].disabled)
	var start: Vector2 = ui.fight.positions[1]
	ui._physics_process(1.0 / 60.0)
	assert(ui.fight.positions[1] != start, "Inspecting a panel must not pause idle combat.")
	ui.get_node("%CloseHeroes").pressed.emit()
	assert(not ui.get_node("%Dismiss").visible)
	ui.fight.excitement = 80.0
	ui._refresh_excitement(80.0)
	assert(ui.cheer == 1.0 and ui.get_node("%Multiplier").text == "x2.50")
	ui._process(1.0)
	assert(ui.cheer < 1.0)
	# Fit the HUD and both popovers at minimum size and on a larger window.
	for viewport_size in [Vector2i(960, 420), Vector2i(1600, 560)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		for name in ["Bank", "ExcitementMeter", "Earnings", "Footer", "Start", "HeroesDrawer", "ArenaDrawer"]:
			var rect: Rect2 = ui.get_node("%" + name).get_global_rect()
			assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rect), "UI spills outside window: " + name)
		assert(ui.get_node("%Bank").get_global_rect().end.x < ui.get_node("%ExcitementMeter").get_global_rect().position.x)
		assert(ui.get_node("%ExcitementMeter").get_global_rect().end.x < ui.get_node("%Earnings").get_global_rect().position.x)
		ui.get_node("%ArenaButton").pressed.emit()
		await _capture("promenade-%d" % viewport_size.x)
		ui._close_drawers()
	root.size = Vector2i(1280, 420)
	ui.queue_free()
	await process_frame
	print("PASS: promenade panels, keyboard/outside close, selection, upgrades, live combat, crowd feedback, and 960/1600px layouts.")


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


func _check_recovery() -> void:
	var fight := Rules.new()
	fight = _battle()
	fight.positions[2] = Vector2(80, 0)
	fight.health[0] = 21
	fight.health[2] = 21
	_cast(fight, 1)
	assert(fight.rest_remaining == [8.0, 8.0, 8.0, 0.0, 0.0])
	assert(fight.valid_lineup([0, 3, 4]) and not fight.start([0, 3, 4]))
	assert(fight.lineup_rest([0, 3, 4]) == 8.0 and fight.lineup_rest([3, 4]) == 0.0)
	var bank: int = fight.coins
	var records: Array = fight.heroes.duplicate(true)
	var elapsed: float = fight.elapsed
	var score: float = fight.excitement
	for invalid in [0.0, -1.0, INF, NAN]:
		assert(fight.advance(invalid).is_empty() and fight.lineup_rest([0, 1, 2]) == 8.0)
	assert(fight.advance(7.5).is_empty() and fight.lineup_rest([0, 1, 2]) == 0.5)
	assert(not fight.start([0, 1, 2]))
	assert(fight.advance(0.5).is_empty() and fight.lineup_rest([0, 1, 2]) == 0.0)
	assert(fight.coins == bank and fight.heroes == records and fight.elapsed == elapsed and fight.excitement == score)
	fight.rest_remaining[4] = 4.0
	assert(fight.start([0, 1, 2]) and fight.rest_remaining[4] == 4.0)
	for id in fight.participants:
		assert(fight.health[id] == fight.stats_for(id).health and fight.mana[id] == 0)
	fight.advance(0.5)
	assert(fight.rest_remaining[4] == 3.5)
	print("PASS: individual recovery, invalid deltas, start guards, expiry, inactive rewards, and bench recovery during combat.")


func _check_recovery_ui() -> void:
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	ui.get_node("%Start").pressed.emit()
	_finish_ui(ui)
	assert(ui.fight.lineup_rest(ui.selected) == 8.0 and not ui.get_node("%Tick").is_stopped())
	assert("Resting" in ui.card_details[0].rest.text and "Ready" in ui.card_details[3].rest.text)
	ui.get_node("%HeroesButton").pressed.emit()
	ui._physics_process(3.0)
	ui._intermission_finished()
	assert(not ui.fight.active and ui.fight.lineup_rest(ui.selected) == 5.0)
	ui.get_node("%Start").pressed.emit()
	assert(not ui.auto_fight and ui.get_node("%Tick").is_stopped())
	ui._physics_process(2.0)
	assert(ui.fight.lineup_rest(ui.selected) == 3.0)
	ui.get_node("%Start").pressed.emit()
	assert(ui.auto_fight and not ui.fight.active and "3s" in ui.get_node("%Start").text)
	ui._physics_process(2.5)
	assert(not ui.fight.active)
	ui._physics_process(0.5)
	assert(ui.fight.active and ui.selected == [0, 1, 2])
	# Even an artificially longer intermission must finish before starting.
	ui.fight.active = false
	ui.fight.rest_remaining.assign([0.0, 0.0, 0.0, 0.0, 0.0])
	ui.get_node("%Tick").start(3.0)
	ui._physics_process(0.5)
	assert(not ui.fight.active)
	ui._intermission_finished()
	assert(ui.fight.active)
	ui.queue_free()
	await process_frame
	print("PASS: recovery countdown, concurrent intermission, queued booking, stop/rebook, open panels, and retained trio.")


func _check_town_grid() -> void:
	var grid := preload("res://game/town_grid.gd").new()
	assert(grid.buildings.tavern.cell == Vector2i(12, 2) and grid.buildings.barracks.cell == Vector2i(34, 2))
	assert(grid.footprint("tavern", Vector2i(12, 2)) == Rect2i(12, 2, 2, 2))
	assert(grid.can_place("tavern", Vector2i(13, 2)), "A move may overlap its own old footprint.")
	for invalid in [Vector2i(-1, 0), Vector2i(47, 0), Vector2i(1, 6), Vector2i(15, 0), Vector2i(34, 2)]:
		var before: Dictionary = grid.buildings.duplicate(true)
		assert(not grid.try_move("tavern", invalid) and grid.buildings == before)
	assert(not grid.try_move("missing", Vector2i.ZERO))
	assert(grid.try_move("tavern", Vector2i.ZERO) and grid.building_at(Vector2i(1, 1)) == "tavern")
	assert(grid.building_at(Vector2i(12, 2)).is_empty())
	assert(grid.try_move("barracks", Vector2i(45, 5)))
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	await process_frame
	var world = ui.get_node("%World")
	var stage: Control = ui.get_node("%Stage")
	var scroll: HScrollBar = ui.get_node("%TownScroll")
	assert(world.tiles is TileMapLayer and world.tiles.get_used_cells().size() == 384)
	assert(world.size.x == 2304.0 and stage.size.x == 536.0)
	assert(is_equal_approx((stage.global_position + ui._project(Vector2.ZERO)).x, root.size.x * 0.5))
	var combat_scale: float = ui._ground_scale()
	var original: Dictionary = world.grid.buildings.duplicate(true)
	ui.get_node("%Arrange").pressed.emit()
	ui.get_node("%Arrange").button_pressed = true
	assert(world.arranging)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.point_for_cell(Vector2i(12, 2))
	world._gui_input(click)
	assert(world.selected_building == "tavern")
	var motion := InputEventMouseMotion.new()
	motion.position = world.point_for_cell(Vector2i(14, 5))
	world._gui_input(motion)
	assert(world.preview_cell == Vector2i(14, 5) and world.grid.can_place("tavern", world.preview_cell))
	assert(world.grid.buildings == original, "Moving a preview must not mutate occupied cells.")
	await _capture("town-arrange")
	click.position = world.point_for_cell(Vector2i(16, 2))
	world._gui_input(click)
	assert(world.selected_building == "tavern" and world.grid.buildings == original)
	click.button_index = MOUSE_BUTTON_RIGHT
	world._gui_input(click)
	assert(world.selected_building.is_empty() and world.grid.buildings == original)
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = world.point_for_cell(Vector2i(12, 2))
	world._gui_input(click)
	ui.get_node("%Start").pressed.emit()
	assert(world.selected_building == "tavern" and world.arranging and ui.fight.active)
	var start: Vector2 = ui.fight.positions[0]
	ui._physics_process(DT)
	assert(ui.fight.positions[0] != start)
	# Scrolling moves world effects and picking together, while HUD stays fixed.
	var bank_rect: Rect2 = ui.get_node("%Bank").get_global_rect()
	scroll.value = 0.0
	assert(world.position.x == 0.0 and world.cell_for_point(world.point_for_cell(Vector2i(4, 3))) == Vector2i(4, 3))
	click.position = world.point_for_cell(Vector2i(4, 3))
	world._gui_input(click)
	assert(world.grid.buildings.tavern.cell == Vector2i(4, 3) and world.selected_building.is_empty())
	var feet: Vector2 = world.building_nodes.tavern.position
	assert(feet == Vector2(240, root.size.y - 160))
	await _capture("town-left")
	scroll.value = 100000.0
	assert(scroll.value == 2304.0 - root.size.x and world.position.x == -scroll.value)
	assert(ui.get_node("%Bank").get_global_rect() == bank_rect)
	await _capture("town-right")
	ui.get_node("%CenterArena").pressed.emit()
	assert(is_equal_approx(scroll.value, 1152.0 - root.size.x * 0.5))
	var pan := InputEventMouseButton.new()
	pan.button_index = MOUSE_BUTTON_WHEEL_DOWN
	pan.pressed = true
	pan.shift_pressed = true
	pan.position = Vector2(500, 250)
	var previous := scroll.value
	ui._input(pan)
	assert(scroll.value == previous + 96.0)
	pan.position = ui.get_node("%Bank").get_global_rect().get_center()
	ui._input(pan)
	assert(scroll.value == previous + 96.0, "HUD input must not pan the world.")
	pan.button_index = MOUSE_BUTTON_MIDDLE
	pan.position = Vector2(500, 250)
	ui._input(pan)
	motion.relative = Vector2(30, 0)
	ui._input(motion)
	assert(scroll.value == previous + 66.0)
	pan.pressed = false
	ui._input(pan)
	assert(not ui.panning)
	# Dispatch an actual click to the HUD: it must not place a pending building.
	click.position = world.point_for_cell(Vector2i(34, 2))
	world._gui_input(click)
	assert(world.selected_building == "barracks")
	var view_before_repeat := scroll.value
	_finish_ui(ui)
	ui._intermission_finished()
	ui._physics_process(Rules.REST_DURATION)
	assert(ui.fight.active and scroll.value == view_before_repeat and world.selected_building == "barracks")
	var hud_click := InputEventMouseButton.new()
	hud_click.button_index = MOUSE_BUTTON_LEFT
	hud_click.position = ui.get_node("%HeroesButton").get_global_rect().get_center()
	hud_click.pressed = true
	root.push_input(hud_click)
	hud_click = hud_click.duplicate()
	hud_click.pressed = false
	root.push_input(hud_click)
	await process_frame
	assert(world.selected_building == "barracks" and world.grid.buildings.barracks.cell == Vector2i(34, 2))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	assert(not ui.get_node("%Dismiss").visible and world.selected_building == "barracks")
	root.push_input(escape)
	await process_frame
	assert(world.selected_building.is_empty() and world.arranging)
	root.push_input(escape)
	await process_frame
	assert(not world.arranging and not ui.get_node("%Arrange").button_pressed)
	ui.fight.arena_tier = 2
	ui._center_arena()
	for viewport_size in [Vector2i(960, 420), Vector2i(1280, 420), Vector2i(1600, 560)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		assert(is_equal_approx(scroll.value + root.size.x * 0.5, 1152.0), "Resize preserves the viewed world center.")
		assert(world.grid.buildings.tavern.cell == Vector2i(4, 3) and ui._ground_scale() == combat_scale)
		assert(world.cell_for_point(world.point_for_cell(Vector2i(34, 2))) == Vector2i(34, 2))
		for name in ["Arrange", "CenterArena", "TownScroll", "Start"]:
			assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(ui.get_node("%" + name).get_global_rect()))
		ui._center_arena()
		await _capture("town-grid-%d" % viewport_size.x)
	root.size = Vector2i(1280, 420)
	ui.queue_free()
	await process_frame
	print("PASS: native town grid, atomic multi-cell placement, protected cells, input isolation, preview cancellation, scrolling, resize, and live combat.")
