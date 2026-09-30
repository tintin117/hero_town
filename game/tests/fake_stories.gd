extends "res://game/core/game.gd"
## FAKE of the stories / traits / preview / props contract (docs: G4+G5) on top of the real Game, until CORE merges.
## UI tests and the screenshot demo use `Stories.make()` instead of `Kit.game()`. DELETE this file after the merge:
## its overrides have looser types than the real ones (which use Array[TraitDef] / Array[PropDef]), so they clash.
## Stand-ins (`FakeTrait`, `FakeProp`) have the real classes' fields: id, display_name, description, icon_name (+ base_price).

const Kit := preload("res://game/tests/core_kit.gd")
const SELF := "res://game/tests/fake_stories.gd"


class FakeTrait extends RefCounted:
	var id: StringName
	var display_name: String
	var description: String
	var icon_name: StringName

	func _init(i: StringName, n: String, d: String, icon: StringName) -> void:
		id = i
		display_name = n
		description = d
		icon_name = icon


class FakeProp extends RefCounted:
	var id: StringName
	var display_name: String
	var description: String
	var icon_name: StringName
	var base_price: int

	func _init(i: StringName, n: String, d: String, icon: StringName, price: int) -> void:
		id = i
		display_name = n
		description = d
		icon_name = icon
		base_price = price


var story_list: Array[Dictionary] = []
var story_capacity := 3
var main_event_id := -1
var selected_prop: StringName = &""
var trait_map := {}  ## hero id -> Array[FakeTrait]
var stock := {}  ## prop id -> owned count
var props: Array = [
	FakeProp.new(&"fireworks", "Fireworks", "Start the fight with excitement 15", &"fireworks", 120),
	FakeProp.new(&"announcer", "Announcer", "Skills add +50% excitement", &"megaphone", 300),
	FakeProp.new(&"spotlights", "Spotlights", "Afterglow x1.5", &"spotlight", 500),
	FakeProp.new(&"ringside_bar", "Ringside Bar", "Concessions x2 this fight", &"drink", 800),
]
var preview_calls: Array = []  ## [lineup, opts] of every preview() call


## A Game like Kit.game() (never touches the player's save, fake simulator) with this contract.
static func make(fake_sim: Object = null) -> Node:
	var sim: Object = fake_sim if fake_sim else Kit.FakeSim.new()
	var g: Node = load(SELF).new()
	g.events = Kit.EventsScript.new()
	g.tuning = g.tuning.duplicate()
	g.catalog = g.catalog.duplicate()
	g.catalog.tuning = g.tuning
	g.tuning.series_wins = 1
	g.tuning.series_max_bouts = 1
	g.tuning.series_pause = 0.0
	g.tuning.series_fame_bonus = 0
	g.autosave = false
	g.save_path = Kit.SAVE_DIR + "/game_save.json"
	g.sim = Callable(sim, &"simulate")
	g.set_meta("fake_sim", sim)  # a Callable does not keep a RefCounted alive
	return g


## Four owned heroes with traits, three stories (ripe streak, growing rivalry, cooling legend), two Fireworks.
func demo() -> void:
	new_game()
	for id in range(2, 4):
		state.heroes[id].owned = true
	state.fighter_tier = 3  # room for five fighters
	state.preferred_lineup = [0, 1] as Array[int]
	state.gold = 400
	trait_map = {
		0: [FakeTrait.new(&"showman", "Showman", "Skills add +50% excitement", &"star")],
		1: [FakeTrait.new(&"brawler", "Brawler", "Fights end faster; more damage", &"sword"),
			FakeTrait.new(&"grudge", "Grudge Holder", "Rivalries ripen faster", &"shield")],
		2: [FakeTrait.new(&"crowd_pleaser", "Crowd Pleaser", "Afterglow x1.5", &"crowd")],
	}
	story_list = [
		{"id": 1, "kind": &"win_streak", "title": "Rex on a roll", "heroes": [0] as Array[int], "ripeness": 62.0, "ripe": true, "cooling": false, "full_bouts": 4},
		{"id": 2, "kind": &"rivalry", "title": "Rex vs Mira", "heroes": [0, 1] as Array[int], "ripeness": 35.0, "ripe": false, "cooling": false, "full_bouts": 2},
		{"id": 3, "kind": &"legend", "title": "The old guard", "heroes": [2, 3] as Array[int], "ripeness": 100.0, "ripe": true, "cooling": true, "full_bouts": 9},
	]
	stock = {&"fireworks": 2}


func set_story(id: int, changes: Dictionary) -> void:
	for story in story_list:
		if story.id == id:
			story.merge(changes, true)
	events.story_changed.emit(id)


# --- the contract ---------------------------------------------------------------------------------

func hero_traits(hero_id: int) -> Array:
	return trait_map.get(hero_id, [])


func stories() -> Array[Dictionary]:
	return story_list


func story_slots() -> int:
	return story_capacity


func set_main_event(story_id: int) -> bool:
	for story in story_list:
		if story.id == story_id and story.ripe:
			main_event_id = story_id
			var ids: Array[int] = []
			ids.assign(story.heroes)
			set_preferred_lineup(ids)
			events.story_changed.emit(story_id)
			return true
	return false


func clear_main_event() -> bool:
	if main_event_id < 0:
		return false
	var old := main_event_id
	main_event_id = -1
	events.story_changed.emit(old)
	return true


## Two stars for a pair, half a star more per extra fighter, +1 with a Main Event; gold scales with the fighters.
func preview(lineup: Array[int], opts := {}) -> Dictionary:
	preview_calls.append([lineup.duplicate(), opts])
	if lineup.size() < tuning.min_lineup:
		return {"stars_min": 0.0, "stars_max": 0.0, "income_min": 0, "income_max": 0}
	var bonus := 1.0 if int(opts.get("main_event", -1)) >= 0 else 0.0
	var lo := minf(5.0, 1.0 + 0.5 * lineup.size() + bonus)
	return {"stars_min": lo, "stars_max": minf(5.0, lo + 1.5), "income_min": 55 * lineup.size(), "income_max": 95 * lineup.size()}


func prop_defs() -> Array:
	return props


func prop_price(id: StringName) -> int:
	for def in props:
		if def.id == id:
			return def.base_price
	return 0


func props_owned(id: StringName) -> int:
	return int(stock.get(id, 0))


func buy_prop(id: StringName) -> bool:
	var price := prop_price(id)
	if price <= 0 or not can_afford(price):
		return false
	stock[id] = props_owned(id) + 1
	_spend(price)  # emits gold_changed
	events.prop_changed.emit()
	return true


func select_prop(id: StringName) -> bool:
	if id != &"" and props_owned(id) < 1:
		return false
	selected_prop = id
	events.prop_changed.emit()
	return true
