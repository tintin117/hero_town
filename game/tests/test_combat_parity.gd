extends RefCounted
## CombatSim must reproduce every fight captured from the old prototype (golden.json).

const GROWTH_PER_LEVEL := 0.05


func run() -> Array[String]:
	var problems: Array[String] = []
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/tests/golden.json"))
	for fight: Dictionary in golden.fights:
		var out := CombatSim.simulate(_lineup(golden.heroes, fight), int(fight.seed))
		for message in _compare(fight, out):
			problems.append("lineup %s L%d seed %d: %s" % [fight.lineup, fight.levels, fight.seed, message])
	problems.append_array(_check_behaviour(golden))
	return problems


func _lineup(heroes: Array, fight: Dictionary) -> Array:
	var growth := 1.0 + GROWTH_PER_LEVEL * (int(fight.levels) - 1)
	var lineup := []
	for id: int in fight.lineup:
		var hero: Dictionary = heroes[id]
		lineup.append({"id": id, "name": hero.name, "red": hero.red, "ranged": hero.ranged,
			"health": roundi(float(hero.health) * growth), "attack": roundi(float(hero.attack) * growth),
			"skill": {"kind": hero.skill.kind, "power": hero.skill.power}})
	return lineup


func _compare(fight: Dictionary, out: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var result: Dictionary = out.result
	_expect(problems, "winner", result.winner == int(fight.winner), [result.winner, fight.winner])
	_expect(problems, "duration", absf(result.duration - float(fight.elapsed)) < 1e-3, [result.duration, fight.elapsed])
	_expect(problems, "excitement", absf(result.excitement - float(fight.excitement)) < 1e-3, [result.excitement, fight.excitement])
	_expect(problems, "tips", result.tips == int(fight.crowd_tips), [result.tips, fight.crowd_tips])
	_expect(problems, "skills", result.skills == int(fight.skills), [result.skills, fight.skills])
	_expect(problems, "attacks", result.attacks == int(fight.attacks), [result.attacks, fight.attacks])
	for pair: Array in fight.health:
		_expect(problems, "hp_left[%d]" % pair[0], result.hp_left[int(pair[0])] == int(pair[1]), [result.hp_left[int(pair[0])], pair[1]])
	var trace := _trace(out.events)
	_expect(problems, "trace", trace == fight.trace, [trace.size(), fight.trace.size()])
	for id: int in result.tracks:
		_expect(problems, "track length", result.tracks[id].size() == roundi(result.duration * 60.0) + 1, [result.tracks[id].size()])
	return problems


## "step:kind:attacker:target:damage,target:damage..." per attack/skill, as captured from the old code.
func _trace(events: Array) -> Array[String]:
	var trace: Array[String] = []
	for event: Dictionary in events:
		if event.kind == "move":
			continue
		var hits := PackedStringArray()
		for hit: Dictionary in event.hits:
			hits.append("%d:%d" % [hit.target, hit.damage])
		trace.append("%d:%s:%d:%s" % [roundi(event.t * 60.0), event.kind, event.attacker, ",".join(hits)])
	return trace


func _expect(problems: Array[String], what: String, ok: bool, values: Array) -> void:
	if not ok:
		problems.append("%s mismatch %s" % [what, values])


func _check_behaviour(golden: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var fight: Dictionary = golden.fights[-1]
	var lineup := _lineup(golden.heroes, fight)
	var base := CombatSim.simulate(lineup, 42)
	var repeat := CombatSim.simulate(lineup, 42)
	_expect(problems, "determinism", var_to_str(base.events) == var_to_str(repeat.events), [])
	var other := CombatSim.simulate(lineup, 43)
	_expect(problems, "seed variety", var_to_str(base.events) != var_to_str(other.events), [])
	var neutral := CombatSim.simulate(lineup, 42, {"start_excitement": 0.0, "skill_excitement_mult": 1.0, "damage_mult": {}})
	_expect(problems, "neutral mods", var_to_str(base.events) == var_to_str(neutral.events), [])
	var excited := CombatSim.simulate(lineup, 42, {"start_excitement": 30.0})
	_expect(problems, "start_excitement", excited.result.excitement > base.result.excitement or base.result.excitement == 100.0, [])
	var duel := [lineup[0], lineup[1]]
	var boosted := CombatSim.simulate(duel, 7, {"damage_mult": {duel[0].id: 5.0}})
	_expect(problems, "damage_mult winner", boosted.result.winner == duel[0].id, [boosted.result.winner])
	var hyped := CombatSim.simulate(duel, 7, {"damage_mult": {duel[0].id: 5.0}, "skill_excitement_mult": 2.0})
	_expect(problems, "skill_excitement_mult", hyped.result.excitement > boosted.result.excitement, [hyped.result.excitement, boosted.result.excitement])
	_expect(problems, "excitement tiers", CombatSim.excitement_multiplier(24.9) == 1.0 and CombatSim.excitement_multiplier(25.0) == 1.25 and CombatSim.excitement_multiplier(60.0) == 2.5, [])
	return problems
