extends RefCounted
## Game + the real CombatSim (core tests use a fake sim): a full fight books, plays back and settles.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var problems: Array[String] = []
	var g: Node = Kit.game()
	g.new_game()
	g.state.hype = 100.0
	var lineup: Array[int] = [0, 1]
	if not g.book_fight(lineup, {"seed": 7}):
		Kit.dispose(g)
		return ["book_fight failed with the real sim"]
	var steps := 0
	while not g.fight.is_empty() and steps < 60 * 300:
		g.advance(1.0 / 60.0)
		steps += 1
	if not g.fight.is_empty():
		problems.append("fight never settled")
	if g.state.gold <= 0:
		problems.append("no gold paid")
	if g.state.fame_points <= 0:
		problems.append("no fame gained")
	if g.state.hype >= 100.0:
		problems.append("hype not reset to afterglow")
	if g.state.fight_count != 1:
		problems.append("fight_count = %d" % g.state.fight_count)
	var winner_wins := int(g.state.heroes[0].wins) + int(g.state.heroes[1].wins)
	if winner_wins != 1:
		problems.append("expected exactly one win recorded, got %d" % winner_wins)
	Kit.dispose(g)
	return problems
