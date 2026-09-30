extends RefCounted
## Stories drawer against FakeStories: the story list (states, portraits, Main Event set / clear), the props shop
## (Buy goes through, disabled when unaffordable), Events-only refresh, and the HUD wiring: the Stories button, its
## ripe badge, the status pill naming the Main Event with the prop icon, the bout toast, layout at 960 / 1280 wide.

const Kit := preload("res://game/tests/core_kit.gd")
const Stories := preload("res://game/tests/fake_stories.gd")
const SCENE := "res://game/ui/drawers/stories_drawer.tscn"

var problems: Array[String] = []
var _game: Node
var _drawer: StoriesDrawer


func run() -> Array[String]:
	problems.clear()
	var tree := Engine.get_main_loop() as SceneTree
	_game = Stories.make()
	_game.demo()
	var host := Control.new()
	host.size = Vector2(1280, 368)
	tree.root.add_child(host)
	_drawer = (load(SCENE) as PackedScene).instantiate()
	_drawer.game = _game
	_drawer.events = _game.events
	host.add_child(_drawer)

	_list()
	_main_event()
	_shop()
	_events_only()
	host.free()
	Kit.dispose(_game)

	for size in [Vector2i(960, 420), Vector2i(1280, 420)]:
		_hud_at(size)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _entry(i: int) -> StoryEntry:
	return _drawer.story_entries[i]


func _status(i: int) -> String:
	return _entry(i).get_node("%Status").text


func _prop(id: StringName) -> PropEntry:
	return _drawer.prop_entries[id]


func _set_gold(gold: int) -> void:
	_game.state.gold = gold
	_game.events.gold_changed.emit(gold, 0)


func _list() -> void:
	_check(_drawer.story_entries.size() == 3, "one entry per story, got %d" % _drawer.story_entries.size())
	_check(_drawer.story_entries.map(func(e: StoryEntry) -> int: return e.story_id) == [1, 3, 2], "ripe stories first")
	_check(not _drawer.empty.visible and _drawer.title == "Stories 3/3", "title counts the slots: %s" % _drawer.title)
	_check(_entry(0).get_node("%Title").text == "Rex on a roll" and _status(0) == "Ripe", "ripe entry: title and status (%s)" % _status(0))
	_check(_status(1) == "Overripe - cooling" and _entry(1).modulate.r < 1.0, "a cooling story says so and is greyed (%s)" % _status(1))
	_check(_status(2) == "Growing", "an unripe story is Growing")
	_check(_entry(0).get_node("%Heroes").get_child_count() == 1 and _entry(2).get_node("%Heroes").get_child_count() == 2, "one portrait per fighter of the story")
	_check(_entry(0).get_node("%Bar").value == 62.0, "the ripeness bar")
	_check(_entry(0).action.text == "Main Event" and not _entry(0).action.disabled and _entry(1).action.text == "Main Event" and not _entry(1).action.disabled,
			"ripe stories can be made the Main Event")
	_check(_entry(2).action.disabled and _entry(2).action.tooltip_text == "Not ripe yet", "an unripe story cannot")
	_game.story_list = [] as Array[Dictionary]
	_game.events.story_changed.emit(-1)
	_check(_drawer.empty.visible and _drawer.empty.text == "Stories appear as fighters win streaks, meet twice or make comebacks" and _drawer.story_entries.is_empty(),
			"empty state text")
	_game.demo()
	_game.events.story_changed.emit(1)


func _main_event() -> void:
	_entry(0).action.pressed.emit()
	_check(_game.main_event_id == 1, "Main Event sets the story")
	_check(_entry(0).action.text == "Clear" and _status(0) == "Main Event x2.2", "the entry shows it is the Main Event (%s, %s)" % [_entry(0).action.text, _status(0)])
	_entry(0).action.pressed.emit()
	_check(_game.main_event_id == -1 and _entry(0).action.text == "Main Event", "Clear drops it again")
	_entry(2).action.pressed.emit()
	_check(_game.main_event_id == -1, "an unripe story is refused by the game")


func _shop() -> void:
	_check(_drawer.prop_entries.size() == 4, "four props")
	_set_gold(400)
	var fireworks := _prop(&"fireworks")
	_check(fireworks.get_node("%Owned").text == "x2" and fireworks.buy.cost == 120 and not fireworks.buy.disabled, "Fireworks: owned 2, 120 gold, affordable")
	_check(_prop(&"announcer").buy.cost == 300 and not _prop(&"announcer").buy.disabled, "the 300 Announcer is affordable at 400")
	_check(_prop(&"spotlights").buy.disabled and _prop(&"ringside_bar").buy.disabled, "500 and 800 are not")
	_check(_drawer.get_node("%Selected").text == "Selected prop: none", "nothing selected: %s" % _drawer.get_node("%Selected").text)
	fireworks.buy.pressed.emit()
	_check(_game.props_owned(&"fireworks") == 3 and _game.state.gold == 280, "Buy calls buy_prop (gold %d)" % _game.state.gold)
	_check(fireworks.get_node("%Owned").text == "x3" and _prop(&"announcer").buy.disabled, "the shop follows: count up, Announcer now out of reach")
	_prop(&"spotlights").buy_requested.emit(&"spotlights")
	_check(_game.props_owned(&"spotlights") == 0 and _game.state.gold == 280, "an unaffordable Buy does nothing")
	_set_gold(1000)
	_check(not _prop(&"ringside_bar").buy.disabled, "gold_changed re-enables Buy")
	_game.select_prop(&"fireworks")
	_check(_drawer.get_node("%Selected").text == "Selected prop: Fireworks" and fireworks.get_node("%Name").text.contains("(in use)"), "the selected prop is named")
	_game.select_prop(&"")
	_check(_drawer.get_node("%Selected").text == "Selected prop: none", "and cleared")


func _events_only() -> void:
	_game.story_list[0].ripeness = 90.0
	_check(_entry(0).get_node("%Bar").value == 62.0, "no redraw without a signal")
	_game.events.story_ripe.emit(1)
	_check(_entry(0).get_node("%Bar").value == 90.0, "story_ripe refreshes the list")


# --- HUD wiring ---------------------------------------------------------------------------------

func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _hud_at(size: Vector2i) -> void:
	var label := str(size)
	var g: Node = Stories.make()
	g.demo()
	var vp := SubViewport.new()
	vp.size = size
	(Engine.get_main_loop() as SceneTree).root.add_child(vp)
	var hud: Control = (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.game = g
	hud.events = g.events
	vp.add_child(hud)
	var button: IconButton = hud.get_node("%Stories")
	var badge: Badge = hud.get_node("%Ripe")

	_check(not button.disabled and button.get_node_or_null("Lock") == null, "%s: Stories is unlocked, no lock badge" % label)
	_check(badge.visible and badge.count == 2 and badge.pulsing, "%s: badge counts the ripe stories (%d)" % [label, badge.count])
	g.set_main_event(1)
	_check(badge.count == 1, "%s: the Main Event no longer counts (%d)" % [label, badge.count])
	g.set_story(3, {"ripe": false})
	_check(badge.count == 0 and not badge.visible, "%s: the badge hides at zero" % label)
	g.set_story(3, {"ripe": true})
	g.clear_main_event()
	_check(badge.count == 2, "%s: clearing brings it back (%d)" % [label, badge.count])

	button.pressed.emit()
	_check(hud.router.current == &"stories", "%s: the Stories button opens the drawer" % label)
	var drawer: StoriesDrawer = hud.router.get_drawer(&"stories")
	for i in 3:
		_layout(hud)
	var middle: Control = hud.get_node("Layout/Middle")
	_check(drawer.panel_size.x + 2.0 * drawer.margin <= size.x and drawer.panel_size.y + 2.0 * drawer.margin <= middle.size.y,
			"%s: the drawer fits the Middle area (%s in %s)" % [label, drawer.panel_size, middle.size])
	var need := drawer.get_combined_minimum_size()
	_check(need.x <= size.x - 2.0 * drawer.margin and need.y <= middle.size.y - 2.0 * drawer.margin, "%s: its content fits (%s)" % [label, need])
	_check(drawer.size.y <= drawer.panel_size.y + 0.5, "%s: content is not taller than the drawer (%s > %s)" % [label, drawer.size.y, drawer.panel_size.y])
	var entry: StoryEntry = drawer.story_entries[0]
	entry.action.pressed.emit()
	_check(g.main_event_id == 1 and badge.count == 1, "%s: the drawer's Main Event button reaches the game and the badge" % label)
	button.pressed.emit()
	_check(hud.router.current == &"", "%s: the button toggles the drawer closed" % label)

	_pill_and_toast(hud, g, label)
	vp.free()
	Kit.dispose(g)


func _pill_and_toast(hud: Control, g: Node, label: String) -> void:
	var pill: Label = hud.get_node("%Text")
	var icon: TextureRect = hud.get_node("%PropIcon")
	_check(not icon.visible, "%s: no prop icon while idle" % label)
	g.set_main_event(1)
	g.plant()
	_check(pill.text == "Main Event: Rex on a roll x2.2 - bell at 70", "%s: planted with a Main Event: %s" % [label, pill.text])
	_check(not icon.visible, "%s: no prop planted, no icon" % label)
	g.select_prop(&"fireworks")
	_check(icon.visible and icon.texture == StoryLook.icon_named(&"fireworks") and icon.tooltip_text.contains("Fireworks"), "%s: the planted prop shows next to the pill" % label)
	var main := {"id": 1, "kind": &"win_streak", "title": "Rex on a roll", "ripeness": 62.0, "multiplier": 2.6}
	g.planted = [] as Array[int]
	g.series = {"lineup": [0, 1] as Array[int], "wins": {0: 1}, "bout": 1, "attendance": 60, "seats": 100, "main_event": main, "prop": &"fireworks"}
	g.events.series_started.emit({"lineup": [0, 1], "attendance": 60, "seats": 100, "wins_needed": 3, "main_event": main, "prop": &"fireworks"})
	_check(pill.text == "Bout 2  1-0  Main Event: Rex on a roll x2.6" and icon.visible, "%s: in the series: %s" % [label, pill.text])
	var toasts: Control = hud.get_node("%Toasts")
	g.events.fight_finished.emit({"winner": 0, "payout": 100, "multiplier": 1.0, "fame_gained": 1})
	_check(toasts.get_child_count() == 1 and toasts.get_child(0).text.contains("Main Event x2.6"), "%s: the bout toast shows the Main Event multiplier: %s" % [label, toasts.get_child(0).text])
	g.events.toast.emit("A story is ripe", &"story")
	_check(toasts.get_child_count() == 2 and hud.TOAST_ICONS[&"story"] == "scroll", "%s: story toasts have an icon" % label)
	g.series = {}
	g.events.series_finished.emit({"winner": 0, "wins": {0: 3, 1: 1}, "bouts": 4, "fame_bonus": 5, "lineup": [0, 1]})
	_check(pill.text.begins_with("Hold the arena") and not icon.visible, "%s: after the series the pill and icon reset: %s" % [label, pill.text])
	g.events.fight_finished.emit({"winner": 0, "payout": 100, "multiplier": 1.0, "fame_gained": 1})
	_check(not toasts.get_child(toasts.get_child_count() - 1).text.contains("Main Event"), "%s: a plain bout toast has no Main Event text" % label)
