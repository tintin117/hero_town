extends RefCounted
## Seed tray against FakeStories (the real Game plus the stories / traits / preview / props contract): hero cards with
## trait chips, story chips (ripe = tap to make it the Main Event, tap again to clear), the live star / gold preview,
## the prop selector, Events-only refresh and the tray's size at 960 / 1280 wide.

const Kit := preload("res://game/tests/core_kit.gd")
const Stories := preload("res://game/tests/fake_stories.gd")
const SCENE := "res://game/ui/drawers/seed_tray.tscn"

var problems: Array[String] = []
var _game: Node
var _tray: SeedTray


func run() -> Array[String]:
	problems.clear()
	var tree := Engine.get_main_loop() as SceneTree
	_game = Stories.make()
	_game.demo()
	var host := Control.new()
	host.size = Vector2(1280, 368)
	tree.root.add_child(host)
	_tray = (load(SCENE) as PackedScene).instantiate()
	_tray.game = _game
	_tray.events = _game.events
	host.add_child(_tray)

	_cards()
	_chips()
	_preview()
	_props()
	_events_only()
	host.free()
	Kit.dispose(_game)

	for size in [Vector2i(960, 420), Vector2i(1280, 420)]:
		_layout_at(size)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _chips_now() -> Array:
	return _tray.chips.get_children().filter(func(c: Node) -> bool: return c is StoryChip)


func _props_now() -> Array:
	return _tray.props.get_children()


func _text(node: String) -> String:
	return _tray.get_node("%" + node).text


func _trait_chips(card: HeroCard) -> Array:
	return card.get_node("Card/Row/Info/Traits").get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())


func _cards() -> void:
	var cards := _tray.cards.get_children()
	_check(cards.size() == 4, "one card per owned fighter, got %d" % cards.size())
	_check(_trait_chips(cards[0]).size() == 1 and _trait_chips(cards[1]).size() == 2 and _trait_chips(cards[3]).size() == 0,
			"trait chips per card: 1 / 2 / 1 / 0, got %d %d %d" % [_trait_chips(cards[0]).size(), _trait_chips(cards[1]).size(), _trait_chips(cards[3]).size()])
	_check(_trait_chips(cards[0])[0].tooltip_text == "Showman: Skills add +50% excitement", "a trait chip's tooltip is name and description: %s" % _trait_chips(cards[0])[0].tooltip_text)
	_check(cards[0].selected and cards[1].selected and not cards[2].selected, "the preferred lineup is ringed")
	cards[2].pressed.emit()
	_check(_game.state.preferred_lineup == [0, 1, 2], "a card tap toggles the fighter: %s" % [_game.state.preferred_lineup])
	_check(_tray.cards.get_child(2).selected, "the card follows roster_changed")
	_tray.cards.get_child(2).pressed.emit()
	_check(_game.state.preferred_lineup == [0, 1], "a second tap drops the fighter again")
	_check(not _tray.get_node("Column/Header").visible, "the tray has no header (compact)")


func _chips() -> void:
	var chips := _chips_now()
	_check(chips.size() == 3, "three story chips for three slots, got %d" % chips.size())
	_check(chips.map(func(c: StoryChip) -> int: return c.story_id) == [1, 3, 2], "ripe stories first: %s" % [chips.map(func(c: StoryChip) -> int: return c.story_id)])
	_check(chips[0]._ripe_mark.visible and chips[1]._ripe_mark.visible and not chips[2]._ripe_mark.visible, "ripe chips carry the star mark, growing ones do not")
	_check(chips[1].modulate.r < 0.8 and chips[0].modulate == Color.WHITE, "a cooling story is greyed")
	_check(not chips[0]._ring.visible and not chips[0]._tag.visible and chips[0]._bar.value == 62.0, "unselected: no ring, no tag, the ripeness bar")
	chips[2].pressed.emit(2)
	_check(_game.main_event_id == -1, "tapping an unripe chip does nothing")
	chips[0].pressed.emit(1)
	_check(_game.main_event_id == 1, "tapping a ripe chip makes it the Main Event")
	chips = _chips_now()
	_check(chips[0]._ring.visible and chips[0]._tag.visible and chips[0]._tag.text == "MAIN EVENT x2.2" and not chips[0]._bar.visible,
			"the selected chip: gold ring and a MAIN EVENT tag (%s)" % chips[0]._tag.text)
	_check(not chips[0]._ripe_mark.visible, "the selected chip drops the ripe star")
	chips[0].pressed.emit(1)
	_check(_game.main_event_id == -1 and not _chips_now()[0]._tag.visible, "tapping the selected chip clears the Main Event")
	_game.story_capacity = 2
	_game.events.story_changed.emit(1)
	_check(_chips_now().size() == 2, "only as many chips as story slots")
	_game.story_capacity = 3
	_game.story_list = [] as Array[Dictionary]
	_game.events.story_changed.emit(-1)
	_check(_chips_now().is_empty() and _tray.get_node("%NoStories").visible, "no stories: the empty hint shows")
	_game.demo()
	_game.events.story_changed.emit(1)
	_check(_chips_now().size() == 3 and not _tray.get_node("%NoStories").visible, "stories are back")


func _preview() -> void:
	_game.state.preferred_lineup = [0, 1] as Array[int]
	_game.events.roster_changed.emit()
	var last: Array = _game.preview_calls.back()
	_check(last[0] == [0, 1] and last[1] == {"main_event": -1}, "preview asks for the lineup and the Main Event id: %s" % [last])
	_check(_tray.stars.min_value == 2.0 and _tray.stars.max_value == 3.5, "stars show the range (%s-%s)" % [_tray.stars.min_value, _tray.stars.max_value])
	_check(_text("PreviewText") == "~110-190 gold per bout", "gold range text: %s" % _text("PreviewText"))
	_game.toggle_lineup(2)
	_check(_tray.stars.min_value == 2.5 and _text("PreviewText") == "~165-285 gold per bout", "the preview follows the lineup: %s, %s" % [_tray.stars.min_value, _text("PreviewText")])
	_game.set_main_event(1)  # the fake also sets the preferred lineup, but a single fighter is refused: the pick stays
	_check(_game.preview_calls.back()[1] == {"main_event": 1} and _tray.stars.min_value == 3.5, "a Main Event raises the preview (%s)" % _tray.stars.min_value)
	_game.clear_main_event()
	_game.state.preferred_lineup = [0] as Array[int]
	_game.events.roster_changed.emit()
	_check(_tray.stars.max_value == 0.0 and _text("PreviewText") == "Pick 2+ fighters", "too few fighters: no stars, a hint (%s)" % _text("PreviewText"))
	_game.state.preferred_lineup = [0, 1] as Array[int]
	_game.events.roster_changed.emit()


func _props() -> void:
	var buttons := _props_now()
	_check(buttons.size() == 4, "four prop buttons, got %d" % buttons.size())
	_check(buttons.map(func(b: PropButton) -> String: return b._caption.text) == ["x2", "300", "500", "800"], "owned count or price under each: %s" % [buttons.map(func(b: PropButton) -> String: return b._caption.text)])
	_check(not buttons[0].button.disabled and buttons[1].button.disabled, "an unowned prop is disabled")
	_check(buttons[1].button.tooltip_text.contains("Stories drawer") and buttons[0].button.tooltip_text.contains("Fireworks"), "unowned tooltip points to the shop: %s" % buttons[1].button.tooltip_text)
	buttons[0].button.pressed.emit()
	_check(_game.selected_prop == &"fireworks" and _props_now()[0].button.button_pressed, "tapping an owned prop selects it")
	_props_now()[0].button.pressed.emit()
	_check(_game.selected_prop == &"" and not _props_now()[0].button.button_pressed, "tapping it again deselects")
	_props_now()[1].button.pressed.emit()
	_check(_game.selected_prop == &"", "an unowned prop cannot be selected")
	_game.state.gold = 1000
	_game.buy_prop(&"announcer")
	_check(_props_now()[1]._caption.text == "x1" and not _props_now()[1].button.disabled, "buying (prop_changed) enables the prop and shows the count")


func _events_only() -> void:
	_game.story_list[1].ripeness = 80.0
	_check(_chips_now()[2]._bar.value == 35.0, "no redraw without a signal")
	_game.events.story_changed.emit(2)
	_check(_chips_now()[2]._bar.value == 80.0, "story_changed refreshes the chip")
	_game.state.heroes[3].level = 4
	_game.events.hero_changed.emit(3)
	_check(_tray.cards.get_child(3).level == 4, "hero_changed refreshes the cards")
	_game.state.heroes[4].owned = true
	_game.events.roster_changed.emit()
	_check(_tray.cards.get_child_count() == 5, "roster_changed picks up a new fighter")
	_game.state.heroes[4].owned = false
	_game.events.roster_changed.emit()


# --- layout ------------------------------------------------------------------------------------

func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _layout_at(size: Vector2i) -> void:
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
	hud.router.open(&"seeds")
	var tray: SeedTray = hud.router.get_drawer(&"seeds")
	for i in 6:
		_layout(hud)
	var middle: Control = hud.get_node("Layout/Middle")
	# the content decides the height (a headless layout never flushes the cached minimum of the scroll containers)
	var extras: Control = tray.get_node("Column/Body/Extras")
	var height := tray.cards.get_combined_minimum_size().y + extras.get_combined_minimum_size().y + 2.0 			+ tray.get_theme_stylebox(&"panel").get_minimum_size().y
	_check(height <= 172.0, "%s: the tray is compact (%s tall)" % [label, height])
	_check(tray.panel_size.x + 2.0 * tray.margin <= size.x and tray.panel_size.y + 2.0 * tray.margin <= middle.size.y, "%s: the tray fits the Middle area (%s in %s)" % [label, tray.panel_size, middle.size])
	_check(tray.get_combined_minimum_size().x <= size.x - 2.0 * tray.margin, "%s: its content is not wider than the window (%s)" % [label, tray.get_combined_minimum_size().x])
	for part: Control in [extras.get_node("Stories"), extras.get_node("Preview"), extras.get_node("Props")]:
		_check(part.size.x > 0.0 and part.get_rect().end.x <= extras.size.x + 0.5, "%s: %s stays inside the row" % [label, part.name])
	# a full house: six fighters (the cards scroll sideways, the story row still fits)
	for id in range(4, 6):
		g.state.heroes[id].owned = true
	g.events.roster_changed.emit()
	for i in 3:
		_layout(hud)
	_check(tray.cards.get_child_count() == 6 and tray.cards.get_combined_minimum_size().y <= 80.0, "%s: six fighters, the card row keeps its height" % label)
	vp.free()
	Kit.dispose(g)
