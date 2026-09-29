extends RefCounted
## The arena scene against a real Game + CombatSim: idle lineup, full fights, roster changes,
## and a fight cut short by new_game(). Script errors show up in the runner output.

const Kit := preload("res://game/tests/core_kit.gd")
const ArenaScene := preload("res://game/combat/arena.tscn")
const DT := 1.0 / 60.0


func run() -> Array[String]:
	var problems: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = Kit.game()
	g.new_game()
	g.state.hype = 100.0
	var arena: Node2D = ArenaScene.instantiate()
	arena.game = g
	tree.root.add_child(arena)
	Kit.check(problems, arena.fighter_count() == g.state.preferred_lineup.size(), "idle fighters match preferred lineup")
	Kit.check(problems, not arena.is_fighting(), "idle arena is not fighting")

	# Roster change while idle.
	g.state.heroes[2].owned = true
	g.state.fighter_tier = 1
	g.set_preferred_lineup([0, 1, 2] as Array[int])
	Kit.check(problems, arena.fighter_count() == 3, "lineup change adds a fighter")

	# A full 3-fighter fight, then the celebration, then back to idle.
	var lineup: Array[int] = [0, 1, 2]
	Kit.check(problems, g.book_fight(lineup, {"seed": 3}), "book_fight")
	Kit.check(problems, arena.is_fighting() and arena.fighter_count() == 3, "fight shows its lineup")
	var steps := _play(g, arena, 60 * 300)
	Kit.check(problems, g.fight.is_empty(), "fight settled after %d steps" % steps)
	Kit.check(problems, not arena.is_fighting() and arena.fighter_count() == 3, "winner celebrates with the pit intact")
	_run_arena(arena, 4.0)
	Kit.check(problems, arena.fighter_count() == 3, "idle lineup restored after the celebration")

	# Five fighters, one of the heavier cases.
	for hero in g.state.heroes:
		hero.owned = true
	g.state.fighter_tier = 3
	g.state.hype = 100.0
	var five: Array[int] = [0, 1, 2, 3, 5]
	Kit.check(problems, g.book_fight(five, {"seed": 11}), "book five fighters")
	Kit.check(problems, arena.fighter_count() == 5, "five fighters shown")
	_play(g, arena, 60 * 300)
	_run_arena(arena, 4.0)

	# new_game in the middle of a fight.
	g.state.hype = 100.0
	g.set_preferred_lineup([0, 1] as Array[int])
	g.book_fight([0, 1] as Array[int], {"seed": 5})
	_play(g, arena, 120)
	Kit.check(problems, arena.is_fighting(), "mid-fight")
	g.new_game()
	_run_arena(arena, 0.1)
	Kit.check(problems, not arena.is_fighting(), "interrupted fight leaves the arena idle")
	Kit.check(problems, arena.fighter_count() == g.state.preferred_lineup.size(), "idle lineup after new_game")

	arena.free()
	Kit.dispose(g)
	return problems


## Advances the game and the arena together until the fight settles; returns the steps used.
func _play(g: Node, arena: Node2D, limit: int) -> int:
	var steps := 0
	while not g.fight.is_empty() and steps < limit:
		g.advance(DT)
		arena._process(DT)
		steps += 1
	return steps


func _run_arena(arena: Node2D, seconds: float) -> void:
	for i in int(seconds / DT):
		arena._process(DT)
