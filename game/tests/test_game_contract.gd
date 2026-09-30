extends RefCounted
## Guards the Game API the UI is written against (docs/ARCHITECTURE.md §5): UI tests run on fakes, so a
## missing or renamed method would otherwise only show up when playing.

const Kit := preload("res://game/tests/core_kit.gd")
const METHODS := [
	"new_game", "continue_game", "save", "set_paused", "book_fight", "plant", "uproot", "toggle_lineup",
	"set_preferred_lineup", "set_manager", "recruit", "expand_seats", "expand_fighters", "can_afford",
	"attendance_if_booked_now", "crowd_now", "income_preview",
	"build", "upgrade", "move_building", "assign_training", "recall_training", "building_level",
	"building_cell", "can_place", "building_at", "building_next_cost", "building_defs", "training_heroes",
	"training_slots", "hero_capacity",
	"hero_traits", "stories", "story", "story_slots", "set_main_event", "clear_main_event", "preview",
	"prop_defs", "prop_price", "props_owned", "buy_prop", "select_prop", "plant_block_reason"]


func run() -> Array[String]:
	var p: Array[String] = []
	var g: Node = Kit.game(Kit.FakeSim.new())
	for method: String in METHODS:
		Kit.check(p, g.has_method(method), "Game.%s exists" % method)
	Kit.check(p, g.stories() is Array and g.stories().is_empty(), "no stories at the start")
	# planting is refused with a reason (never silently) while a picked fighter trains in the Gym
	g.new_game()
	Kit.check(p, g.plant_block_reason() == "", "a fresh game can plant")
	g.state.gold = 1000000
	g.state.buildings["gym"] = {"level": 1, "cell": [10, 0]}
	g.state.heroes[2].owned = true
	Kit.check(p, g.assign_training(2), "Nia can train")
	g.state.preferred_lineup = [0, 2] as Array[int]
	Kit.check(p, g.plant_block_reason().contains("training") and not g.plant(), "a trainee blocks planting with a reason: %s" % g.plant_block_reason())
	g.recall_training(2)
	Kit.check(p, g.plant_block_reason() == "" and g.plant(), "recalled, it plants")
	Kit.dispose(g)
	return p
