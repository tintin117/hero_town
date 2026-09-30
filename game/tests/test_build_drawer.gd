extends RefCounted
## Build drawer against FakeBuildings (the real Game plus a fake of the building contract): entries, Build / Upgrade / Max,
## placement requests, Gym training, Events-only refresh, layout at 960 / 1280 wide, and the HUD's Build button.

const Kit := preload("res://game/tests/core_kit.gd")
const Fake := preload("res://game/tests/fake_buildings.gd")
const Stories := preload("res://game/tests/fake_stories.gd")  # the HUD part needs the stories contract too
const SCENE := "res://game/ui/drawers/build_drawer.tscn"
const IDS: Array[StringName] = [&"promotion_office", &"recruitment_hall", &"gym", &"restaurant"]

var problems: Array[String] = []
var _game: Node
var _drawer: BuildDrawer
var _host: Control
var _placed: Array = []


func run() -> Array[String]:
	problems.clear()
	var tree := Engine.get_main_loop() as SceneTree
	_game = Fake.make()
	_host = Control.new()
	_host.size = Vector2(1280, 272)
	tree.root.add_child(_host)
	_drawer = (load(SCENE) as PackedScene).instantiate()
	_drawer.game = _game
	_drawer.events = _game.events
	_host.add_child(_drawer)
	_drawer.place_requested.connect(func(id: StringName, moving: bool) -> void: _placed.append([id, moving]))

	_entries()
	_states()
	_actions()
	_gym()
	_events_only()
	_host.free()
	Kit.dispose(_game)

	for size in [Vector2i(960, 420), Vector2i(1280, 420)]:
		_layout_and_hud(size)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _entry(id: StringName) -> BuildEntry:
	return _drawer.entries[id]


func _label(id: StringName, node: String) -> String:
	return _entry(id).get_node("%" + node).text


func _set_gold(gold: int) -> void:
	_game.state.gold = gold
	_game.events.gold_changed.emit(gold, 0)


func _set_level(id: StringName, level: int) -> void:
	Fake.set_level(_game, id, level)
	_game.events.building_changed.emit(id)


func _lit_pips(id: StringName) -> int:
	return _entry(id).get_node("%Pips").get_children().filter(func(p: TextureRect) -> bool: return p.visible and p.texture == BuildEntry.STAR).size()


func _entries() -> void:
	_check(_drawer.entries.size() == 4, "one entry per building, got %d" % _drawer.entries.size())
	for i in 4:
		var id := IDS[i]
		_check(_drawer.entries.has(id) and _drawer.scroll.get_child(0).get_child(i) == _entry(id), "%s is entry %d, in catalog order" % [id, i])
		_check(_label(id, "Name") == _game.building_defs()[i].display_name, "%s: shows its name" % id)
		_check(_entry(id).tooltip_text == _game.building_defs()[i].description, "%s: the tooltip is the description" % id)
		_check(_entry(id)._icon.texture != null, "%s: has an icon" % id)
	_check(_drawer.training != null and _entry(&"gym").extra.get_child(0) == _drawer.training, "the Gym entry carries the training panel")
	_check(_drawer.training.get_parent() != _entry(&"restaurant").extra, "only the Gym has one")


func _states() -> void:
	# nothing built, no gold: every button says Build and is unaffordable
	for id in IDS:
		var e := _entry(id)
		_check(e.level == 0 and _lit_pips(id) == 0, "%s: unbuilt shows no lit pip" % id)
		_check(e.get_node("%Pips").get_child_count() == 3, "%s: three level pips" % id)
		_check(e.buy.text.begins_with("Build") and e.buy.cost == _game.building_next_cost(id), "%s: Build at the level-1 cost (%s)" % [id, e.buy.text])
		_check(e.buy.disabled, "%s: unaffordable Build is disabled" % id)
		_check(not e.move.visible, "%s: no Move before it is built" % id)
		_check(_label(id, "Now") == "Not built", "%s: says Not built" % id)
		_check(_label(id, "Next") == "Next: " + Buildings.describe(_game.catalog, id, 1), "%s: next line describes level 1 (%s)" % [id, _label(id, "Next")])
	_set_gold(300)
	_check(not _entry(&"promotion_office").buy.disabled, "300 gold affords the 300 Promotion Office")
	_check(not _entry(&"gym").buy.disabled and _entry(&"recruitment_hall").buy.disabled == false, "the cheaper Gym and Hall are affordable too")
	# built, mid level: Upgrade with the next cost, the pips, the Move button
	_set_level(&"promotion_office", 2)
	var e := _entry(&"promotion_office")
	_check(e.buy.text.begins_with("Upgrade") and e.buy.cost == 2700000 and e.buy.cost == _game.building_next_cost(&"promotion_office"), "level 2: Upgrade to level 3 (%s)" % e.buy.text)
	_check(e.buy.disabled and _lit_pips(&"promotion_office") == 2, "level 2: two lit pips, upgrade unaffordable at 300 gold")
	_check(e.move.visible, "built: Move shows")
	_check(_label(&"promotion_office", "Now") == Buildings.describe(_game.catalog, &"promotion_office", 2), "current effect text: %s" % _label(&"promotion_office", "Now"))
	_check(_label(&"promotion_office", "Next") == "Next: " + Buildings.describe(_game.catalog, &"promotion_office", 3), "next effect text: %s" % _label(&"promotion_office", "Next"))
	_set_gold(3000000)
	_check(not e.buy.disabled, "upgrade affordable with gold")
	# maxed
	_set_level(&"promotion_office", 3)
	_check(e.buy.text == "Max" and e.buy.disabled and _lit_pips(&"promotion_office") == 3, "level 3: disabled Max button, three pips")
	_check(_label(&"promotion_office", "Next") == "Max level" and e.move.visible, "maxed: no next effect, still movable")
	_set_level(&"promotion_office", 1)
	_check(e.buy.text.begins_with("Upgrade") and not e.buy.disabled, "back to level 1: Upgrade again")
	_set_gold(0)
	_check(e.buy.disabled, "gold spent: Upgrade unaffordable again")


func _actions() -> void:
	_set_gold(100000)
	_drawer.open()
	_entry(&"restaurant").buy.pressed.emit()
	_check(_placed == [[&"restaurant", false]], "Build asks for a placement (moving=false): %s" % [_placed])
	_check(not _drawer.is_open, "Build closes the drawer")
	_check(_game.building_level(&"restaurant") == 0, "Build itself does not build: the shell does after placing")
	_placed.clear()
	_drawer.open()
	_entry(&"promotion_office").move.pressed.emit()
	_check(_placed == [[&"promotion_office", true]] and not _drawer.is_open, "Move asks for a placement (moving=true) and closes: %s" % [_placed])
	_placed.clear()
	_drawer.open()
	var gold: int = _game.state.gold
	var cost: int = _game.building_next_cost(&"promotion_office")
	_entry(&"promotion_office").buy.pressed.emit()
	_check(_game.building_level(&"promotion_office") == 2 and _game.state.gold == gold - cost, "Upgrade calls Game.upgrade")
	_check(_placed.is_empty() and _drawer.is_open, "Upgrade asks for no placement and keeps the drawer open")
	_check(_entry(&"promotion_office").level == 2 and _lit_pips(&"promotion_office") == 2, "the entry follows the upgrade through Events")
	_drawer.close()
	_set_gold(0)


func _gym() -> void:
	var training: GymTraining = _drawer.training
	_check(training.hint.visible and training.hint.text.contains("Build the Gym"), "unbuilt Gym: hint says to build it (%s)" % training.hint.text)
	_check(training.trainees.get_child_count() == 0 and training.candidates.get_child_count() == 0, "unbuilt Gym: nobody listed")
	_check(training.modulate.a < 1.0, "unbuilt Gym: the section is dimmed")
	Fake.set_level(_game, &"gym", 1)  # level 1 = one slot
	_check(training.modulate.a == 1.0 and _label(&"gym", "Now") == Buildings.describe(_game.catalog, &"gym", 1), "built Gym: enabled")
	var candidates := training.candidates.get_children()
	_check(candidates.size() == 2, "two owned benched fighters can be sent, got %d" % candidates.size())
	_check(candidates[0].tooltip_text.contains("Lv 1"), "candidates show level / XP (%s)" % candidates[0].tooltip_text)
	candidates[1].pressed.emit()
	_check(Array(_game.training_heroes()) == [1], "picking a benched fighter calls assign_training")
	_check(training.trainees.get_child_count() == 1 and training.candidates.get_child_count() == 0, "the trainee is listed, the one slot is full")
	_check(training.hint.visible and training.hint.text.contains("busy") and "Training 1/1" in training.get_node("%Title").text, "full gym says so (%s)" % training.hint.text)
	var row: HBoxContainer = training.trainees.get_child(0)
	_check((row.get_child(1) as Label).text.contains(_game.hero_defs[1].display_name) and (row.get_child(1) as Label).text.contains("XP 0/"), "trainee row: name and XP hint (%s)" % (row.get_child(1) as Label).text)
	(row.get_child(2) as Button).pressed.emit()
	_check(_game.training_heroes().is_empty() and training.trainees.get_child_count() == 0, "Recall calls recall_training")
	_check(training.candidates.get_child_count() == 2, "the recalled fighter is a candidate again")
	# two slots; a planted or serving fighter is not offered; a capped fighter is not offered
	_set_level(&"gym", 2)
	_game.planted = [0] as Array[int]
	_game.events.planted_changed.emit()
	_check(training.candidates.get_child_count() == 1, "a planted fighter cannot be sent")
	_game.planted = [] as Array[int]
	_game.series = {"lineup": [0, 1]}
	_game.events.series_started.emit({})
	_check(training.candidates.get_child_count() == 0 and training.hint.visible, "series fighters cannot be sent")
	_game.series = {}
	_game.state.heroes[0].level = _game.tuning.level_cap
	_game.events.series_finished.emit({})
	_check(training.candidates.get_child_count() == 1, "a level-capped fighter is not offered")
	_game.state.heroes[0].level = 1
	_game.events.hero_changed.emit(0)


func _events_only() -> void:
	# state changed behind the drawer's back: nothing redraws until an Events signal arrives
	_game.state.buildings["restaurant"] = {"level": 3, "cell": [14, 3]}
	_check(_entry(&"restaurant").level == 0, "no redraw without a signal")
	_game.events.building_changed.emit(&"restaurant")
	_check(_entry(&"restaurant").level == 3 and _entry(&"restaurant").buy.text == "Max", "building_changed refreshes the entry")
	_game.state.heroes[0].xp = 7
	_game.events.hero_changed.emit(0)
	_check(_drawer.training.candidates.get_child(0).tooltip_text.contains("XP 7/"), "hero_changed refreshes the training candidates")
	_game.state.heroes[3].owned = true
	_game.events.roster_changed.emit()
	_check(_drawer.training.candidates.get_child_count() == 3, "roster_changed picks up a new hero")
	Fake.set_level(_game, &"restaurant", 0)
	_game.state.gold = 5000
	_game.events.gold_changed.emit(5000, 5000)
	_check(_entry(&"restaurant").buy.text.begins_with("Build") and not _entry(&"restaurant").buy.disabled, "gold_changed refreshes affordability")
	# focus_building scrolls to and rings the entry
	_drawer.focus(&"restaurant")
	_check(_entry(&"restaurant").get_node("%Ring").visible and not _entry(&"gym").get_node("%Ring").visible, "focus rings that entry only")


# --- layout and HUD -----------------------------------------------------------------------------

func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _layout_and_hud(size: Vector2i) -> void:
	var label := str(size)
	var g: Node = Stories.make()
	g.new_game()
	for id in range(2, 8):
		g.state.heroes[id].owned = true
	g.state.gold = 1000000
	for id in IDS:
		Fake.set_level(g, id, 3)
	g.state.training = {0: 0.0, 1: 0.0, 2: 0.0}
	var vp := SubViewport.new()
	vp.size = size
	(Engine.get_main_loop() as SceneTree).root.add_child(vp)
	var hud: Control = (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.game = g
	hud.events = g.events
	vp.add_child(hud)
	var build: IconButton = hud.get_node("%Build")
	var requests: Array = []
	hud.placement_requested.connect(func(id: StringName, moving: bool) -> void: requests.append([id, moving]))
	_check(not build.disabled and build.tip == "Build" and build.get_child_count() == 0, "%s: Build is unlocked, no lock badge" % label)
	build.pressed.emit()
	_check(hud.router.current == &"build", "%s: the Build button opens the build drawer" % label)
	var drawer: BuildDrawer = hud.router.get_drawer(&"build")
	for i in 3:
		_layout(hud)
	var middle: Control = hud.get_node("Layout/Middle")
	_check(drawer.panel_size.x + 2.0 * drawer.margin <= size.x and drawer.panel_size.y + 2.0 * drawer.margin <= middle.size.y,
			"%s: the drawer fits the Middle area (%s in %s)" % [label, drawer.panel_size, middle.size])
	_check(drawer.size.y <= drawer.panel_size.y + 0.5, "%s: content is not taller than the drawer (%s > %s)" % [label, drawer.size.y, drawer.panel_size.y])
	var tallest := 0.0
	for e: BuildEntry in drawer.entries.values():
		tallest = maxf(tallest, e.get_combined_minimum_size().y)
	_check(tallest <= drawer.scroll.size.y + 0.5, "%s: the tallest entry (%s) fits the scroll area (%s)" % [label, tallest, drawer.scroll.size.y])
	_check(drawer.entries[&"gym"].get_combined_minimum_size().y <= drawer.scroll.size.y + 0.5, "%s: the Gym with 3 trainees fits" % label)
	drawer.entries[&"gym"].move.pressed.emit()
	_check(requests == [[&"gym", true]] and hud.router.current == &"", "%s: the HUD re-emits placement_requested and the drawer closes" % label)
	hud.focus_building(&"restaurant")
	_check(hud.router.current == &"build" and drawer.entries[&"restaurant"].get_node("%Ring").visible, "%s: focus_building opens the drawer on that entry" % label)
	build.pressed.emit()
	_check(hud.router.current == &"", "%s: the Build button toggles the drawer closed" % label)
	if size.x == 1280:
		_toast(hud, g)
	vp.free()
	Kit.dispose(g)


func _toast(hud: Control, g: Node) -> void:
	var toasts: Control = hud.get_node("%Toasts")
	g.events.fight_finished.emit({"winner": 0, "payout": 100, "multiplier": 1.0, "fame_gained": 1, "concessions": 12})
	g.events.fight_finished.emit({"winner": 0, "payout": 100, "multiplier": 1.0, "fame_gained": 1, "concessions": 0})
	g.events.fight_finished.emit({"winner": 0, "payout": 100, "multiplier": 1.0, "fame_gained": 1})
	_check(toasts.get_child_count() == 3, "three bout toasts, got %d" % toasts.get_child_count())
	if toasts.get_child_count() == 3:
		_check(toasts.get_child(0).text.contains("+12 snacks"), "the bout toast shows the concessions: %s" % toasts.get_child(0).text)
		_check(not toasts.get_child(1).text.contains("snacks") and not toasts.get_child(2).text.contains("snacks"), "no snacks text without concessions")
