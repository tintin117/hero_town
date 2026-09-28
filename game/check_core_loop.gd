extends SceneTree
## Focused rule checks; never touches the player's save or editor settings.
const Rules := preload("res://game/fight.gd")
const DT := 1.0 / 60.0
const CELLS := {"training": Vector2i(10, 4), "hall": Vector2i(13, 4), "infirmary": Vector2i(32, 4), "tavern": Vector2i(35, 4)}
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _injure(fight: RefCounted, id: int) -> void:
	for loss in range(3):
		fight._record_defeat(id)


func _finish(fight: RefCounted) -> bool:
	var steps := 0
	while fight.active and steps < 7200:
		fight.advance(DT)
		steps += 1
	_expect(not fight.active and fight.survivors().size() == 1, "Every started fight must finish with one survivor within 120 seconds.")
	return not fight.active


func _run() -> void:
	_check_opening()
	_check_conditions()
	_check_hospital()
	_check_gym()
	_check_food()
	_check_matchups()
	_check_unattended()
	print("CORE LOOP: %s" % ("PASS: two starters, eligibility, separate fatigue/injury, Hospital, Gym, food, duels and unattended recovery." if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)


func _check_opening() -> void:
	var fight := Rules.new()
	_expect(fight.owned_count() == 2 and fight.fighter_capacity() == 2 and fight.roster_capacity() == 3, "New estates start with Bram/Ivo, two fighter places and one reserve vacancy.")
	_expect(fight.next_milestone().id == "recruit" and fight.next_milestone().target == 2, "The first recommendation must recruit Nia.")
	_expect(not fight.start([0]) and not fight.start([0, 1, 2]) and not fight.start([0, 0]), "Invalid or unowned lineups must be rejected.")
	_expect(fight.start([0, 1]), "The starter duel must be legal.")
	_expect(fight.availability(0).state == "fighting" and not fight.ready(0), "Active participants are unavailable for management.")
	_finish(fight)
	_expect(fight.coins >= 100 and fight.recruit(2), "The first fight must fund Nia without a Hall.")
	fight.coins = 3000000
	for expected in [3, 4, 5]:
		_expect(fight.purchase_upgrade("fighters") and fight.fighter_capacity() == expected, "Fighter expansions must progress through three, four and five.")
	_expect(not fight.purchase_upgrade("fighters"), "Five is the fighter capacity limit.")


func _check_conditions() -> void:
	var fight := Rules.new()
	for bout in range(3):
		_expect(fight.start([0, 1]), "A fighter below three defeats remains available.")
		fight.health[1] = 1
		var event := fight._act(0, false)
		_expect(event.winner == 0 and fight.defeat_strain[1] == bout + 1, "Only the loser receives one strain per settled fight.")
	_expect(fight.injury_remaining[1] == 180.0 and fight.defeat_strain[0] == 0, "Third defeat causes an injury independently of remaining stamina.")
	_expect(fight.heroes[1].stamina == 7 and not fight.start([0, 1]), "Injured heroes cannot fight even with stamina.")
	_expect(fight.next_lineup([0, 1]) == [0], "Unavailable preferred heroes must be excluded without Auto-fill.")
	fight.heroes[1].stamina = 0
	fight.rest_remaining[1] = 60.0
	fight.advance(60.0)
	_expect(fight.heroes[1].stamina == 10 and fight.injury_remaining[1] == 120.0 and not fight.ready(1), "Fatigue and injury recover concurrently without clearing each other.")
	fight.advance(120.0)
	_expect(fight.ready(1) and fight.defeat_strain[1] == 0 and fight.injury_order[1] == 0, "Free injury recovery restores eligibility and clears strain/order.")
	fight._record_defeat(0)
	fight._record_defeat(0)
	fight.advance(59.0)
	_expect(fight.defeat_strain[0] == 2, "Bench strain decay requires sixty complete seconds.")
	_expect(fight.start([0, 1]) and fight.bench_elapsed[0] == 0.0, "Entering combat resets uninterrupted bench time.")
	fight.health[1] = 1
	fight._act(0, false)
	fight.advance(60.0)
	_expect(fight.defeat_strain[0] == 1, "One bench minute removes one defeat marker.")
	fight.advance(60.0)
	_expect(fight.defeat_strain[0] == 0 and fight.bench_elapsed[0] == 0.0, "Idle time cannot bank future strain removal.")
	fight.heroes[0].stamina = 1
	_expect(fight.start([0, 1]), "A last stamina point still permits a fight.")
	fight.health[1] = 1
	fight._act(0, false)
	_expect(fight.rest_remaining[0] == 60.0 and fight.injury_remaining[0] == 0.0, "Exhaustion creates fatigue, not an injury.")
	var before := fight.rest_remaining[0]
	for invalid in [-1.0, 0.0, INF, NAN]:
		fight.advance(invalid)
	_expect(fight.rest_remaining[0] == before, "Invalid elapsed time must not advance management.")
	# Old saves may still have an in-flight 120-second fatigue countdown.
	fight.rest_remaining[0] = 100.0
	fight.advance(40.0)
	_expect(fight.rest_remaining[0] == 60.0, "Legacy remaining recovery time is preserved rather than truncated.")


func _check_hospital() -> void:
	var fight := Rules.new()
	_expect(fight.upgrade_cost("infirmary") == 450, "The first Hospital costs 450 gold to support early injuries.")
	fight.coins = 3000000
	_expect(fight.purchase_upgrade("infirmary", CELLS.infirmary), "Hospital construction must succeed.")
	_injure(fight, 1)
	_injure(fight, 0)
	_expect(fight.hospital_patients() == [1] and fight.hospital_waiting() == [0], "The oldest injury receives the first bed, independent of hero index.")
	fight.advance(90.0)
	_expect(fight.injury_remaining[1] == 0.0 and fight.injury_remaining[0] == 90.0 and fight.hospital_patients() == [0], "Waiting heroes still heal naturally and enter a newly free bed.")
	fight.advance(45.0)
	_expect(fight.hospital_patients().is_empty() and fight.ready(0), "Treatment completes automatically and returns its patient.")
	_injure(fight, 0)
	_injure(fight, 1)
	fight.advance(135.0)
	_expect(fight.hospital_patients().is_empty(), "A large time step must reassign beds at the completion boundary.")
	_expect(fight.purchase_upgrade("infirmary") and fight.hospital_capacity() == 2 and fight.hospital_rate() == 3.0, "Hospital level two provides two beds at total speed three.")
	_expect(fight.purchase_upgrade("infirmary") and fight.hospital_capacity() == 3 and fight.hospital_rate() == 4.0, "Hospital level three provides three beds at total speed four.")
	_injure(fight, 0)
	fight.advance(45.0)
	_expect(fight.ready(0), "A level-three Hospital heals one 180-work injury in 45 seconds.")


func _check_gym() -> void:
	var fight := Rules.new()
	fight.coins = 10000
	_expect(fight.recruit(2) and fight.purchase_upgrade("training", CELLS.training), "The first reserve and Gym must be affordable independently.")
	_expect(fight.max_stamina() == 15 and fight.training_capacity() == 1, "Gym retains stamina growth and adds one assignment slot.")
	_expect(not fight.training_assign(0, [0, 1]), "Booked heroes cannot be assigned to training.")
	_expect(fight.training_assign(2, [0, 1]), "A healthy bench reserve may train.")
	_expect(not fight.ready(2) and not fight.start([0, 2]), "Training heroes are excluded from fights.")
	var coins := fight.coins
	fight.advance(30.0)
	_expect(fight.heroes[2].xp == 5 and fight.heroes[2].stamina == 15 and fight.coins == coins, "Training gives five XP per thirty seconds with no stamina or gold cost.")
	fight.advance(15.0)
	_expect(fight.training_recall(2) and fight.ready(2) and fight.heroes[2].xp == 5, "Recall is immediate and unfinished intervals grant no XP.")
	fight.heroes[2].level = 9
	fight.heroes[2].xp = 185
	_expect(fight.training_assign(2, [0, 1]), "A hero approaching max level can still train.")
	fight.advance(30.0)
	_expect(fight.heroes[2].level == 10 and fight.heroes[2].xp == 0 and not fight.training_elapsed.has(2), "Max-level trainees automatically leave the Gym.")
	_expect(not fight.training_assign(2), "Max-level heroes cannot occupy a training slot.")
	fight.heroes[2].level = 1
	_injure(fight, 1)
	_expect(not fight.training_assign(2), "Training must leave two healthy heroes outside the Gym.")


func _check_food() -> void:
	var fight := Rules.new()
	fight.coins = 1000000
	_expect(fight.purchase_upgrade("tavern", CELLS.tavern), "Restaurant construction must succeed.")
	var coins := fight.coins
	_expect(not fight.feed(0, "light") and fight.coins == coins, "Full stamina must not consume food gold.")
	fight.heroes[0].stamina = 0
	fight.rest_remaining[0] = 60.0
	_expect(fight.feed(0, "light") and fight.heroes[0].stamina == 5 and fight.rest_remaining[0] == 0.0, "A light meal costs twenty and immediately ends fatigue with five stamina.")
	_expect(fight.coins == coins - 20 and fight.restaurant_cooldown == 30.0, "Successful manual food service starts the shared cooldown.")
	fight.heroes[1].stamina = 1
	coins = fight.coins
	_expect(not fight.feed(1, "feast") and fight.coins == coins, "Restaurant cooldown is shared across heroes.")
	fight.advance(30.0)
	_expect(fight.feed(1, "feast") and fight.heroes[1].stamina == 10 and fight.coins == coins - 50, "Feast fully restores its chosen hero for fifty gold.")
	fight.advance(30.0)
	_injure(fight, 0)
	coins = fight.coins
	_expect(not fight.feed(0, "light") and fight.coins == coins and fight.injury_remaining[0] > 0.0, "Food never heals injury or spends gold on an ineligible hero.")
	fight.advance(180.0)
	_expect(fight.start([0, 1]) and not fight.feed(0, "light"), "Food cannot change an active participant.")
	_finish(fight)
	fight.restaurant_cooldown = 30.0
	_expect(fight.purchase_upgrade("tavern") and fight.restaurant_cooldown == 30.0 and fight.meal_cooldown_duration() == 20.0, "Restaurant upgrades shorten future services without resetting an active cooldown.")
	fight.advance(30.0)
	fight.coins = 19
	fight.heroes[0].stamina = 1
	_expect(not fight.feed(0, "light") and fight.coins == 19, "Food never overdraws the bank.")
	_expect(not fight.feed(-1, "light") and not fight.feed(0, "unknown"), "Invalid meal requests are rejected safely.")


func _check_matchups() -> void:
	var longest := 0.0
	for first in range(8):
		for second in range(first + 1, 8):
			for seed_value in [7, 42]:
				var fight := Rules.new()
				fight.heroes[first].owned = true
				fight.heroes[second].owned = true
				fight.rng.seed = seed_value
				_expect(fight.start([first, second]), "Every owned pair should support a duel.")
				_finish(fight)
				longest = maxf(longest, fight.elapsed)
	print("DUELS: 56 seeded matchups / longest %.2fs" % longest)


func _check_unattended() -> void:
	var fight := Rules.new()
	fight.building_levels.hall = 2
	fight.building_levels.infirmary = 1
	fight.fighter_tier = 1
	fight.auto_fill_owned = true
	fight.auto_fill_enabled = true
	fight.rng.seed = 123
	for id in range(6):
		fight.heroes[id].owned = true
	var wait := 0.0
	var saw_injury := false
	for step in range(36000):
		if not fight.active and wait <= 0.0:
			fight.start(fight.next_lineup([0, 1]))
		var was_active := fight.active
		fight.advance(DT)
		wait = maxf(0.0, wait - DT)
		if was_active and not fight.active:
			wait = 3.0
		for remaining in fight.injury_remaining:
			saw_injury = saw_injury or remaining > 0.0
	_expect(saw_injury and fight.completed > 15, "An unattended arena must rotate, recover and continue after repeated injuries.")
	print("UNATTENDED: %d fights / ten simulated minutes" % fight.completed)
