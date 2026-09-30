extends RefCounted
## Roster drawer against a real Game + Events pair built by CoreKit (no autoloads under --script).

const Kit := preload("res://game/tests/core_kit.gd")
const Fake := preload("res://game/tests/fake_buildings.gd")  # the real Game plus the Recruitment Hall capacity
const SCENE := "res://game/ui/drawers/roster_drawer.tscn"

var problems: Array[String] = []
var _game: Node
var _drawer: RosterDrawer
var _host: Control


func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	_game = Fake.make()
	_host = Control.new()
	_host.size = Vector2(1280, 272)
	tree.root.add_child(_host)
	_drawer = (load(SCENE) as PackedScene).instantiate()
	_drawer.game = _game
	_drawer.events = _game.events
	_host.add_child(_drawer)

	_states()
	_recruit()
	_hall_capacity()
	_lineup()
	_expansions()
	_events_only()
	_open_close()

	_host.free()  # frees the drawer too
	Kit.dispose(_game)
	return problems


func _check(condition: bool, message: String) -> void:
	Kit.check(problems, condition, message)


func _lineup_is(ids: Array) -> bool:
	return Array(_game.state.preferred_lineup) == ids


func _set_gold(gold: int) -> void:
	_game.state.gold = gold
	_game.events.gold_changed.emit(gold, 0)


func _states() -> void:
	_check(_drawer.entries.size() == 8, "shows 8 hero entries, got %d" % _drawer.entries.size())
	for i in 8:
		var e := _drawer.entries[i]
		var owned: bool = _game.state.heroes[i].owned
		_check(e.buy.visible == not owned, "hero %d: recruit button only while for sale" % i)
		_check(e.card.hero_name == _game.hero_defs[i].display_name, "hero %d: card shows the name" % i)
	_check(_drawer.entries[0].card.selected and _drawer.entries[1].card.selected, "starting lineup is highlighted")
	_check(_drawer.entries[0].slot.count == 1 and _drawer.entries[1].slot.count == 2, "lineup slots numbered 1, 2")
	_check(not _drawer.entries[2].card.selected and _drawer.entries[2].slot.count == 0, "for-sale hero is not in the lineup")
	# gold 0 at the start: every price is unaffordable
	_check(_drawer.entries[2].buy.disabled and _drawer.entries[2].card.disabled, "unaffordable hero: button disabled, card dimmed with lock")
	_check(_drawer.entries[2].buy.cost == 100, "Nia costs 100")
	_set_gold(1000)
	_check(not _drawer.entries[2].buy.disabled and not _drawer.entries[2].card.disabled, "affordable hero: button enabled")
	_check(_drawer.entries[6].buy.disabled, "350000 hero stays disabled at 1000 gold")
	_drawer.entries[6].buy.pressed.emit()
	_check(not _game.state.heroes[6].owned and _game.state.gold == 1000, "pressing an unaffordable recruit changes nothing")


func _recruit() -> void:
	_drawer.entries[2].buy.pressed.emit()
	_check(_game.state.heroes[2].owned and _game.state.gold == 900, "recruit went through Game (owned, 100 spent)")
	_check(not _drawer.entries[2].buy.visible, "entry flips to owned after the signal")
	_check(_drawer.entries[2].card.hero_name == "Nia" and not _drawer.entries[2].card.disabled, "recruited card is selectable")


func _hall_capacity() -> void:
	# Nia made it 3 of 3: the hall is full, so the other recruit buttons are off with a reason, whatever the gold
	_check(_drawer.club.text == "Club 3/3 heroes", "club line shows owned / capacity: %s" % _drawer.club.text)
	_check(_drawer.entries[3].buy.disabled and _drawer.entries[3].buy.tooltip_text == "Recruitment Hall full - upgrade it", "full hall: recruit disabled with the reason")
	_check(_drawer.entries[2].buy.tooltip_text == "" and not _drawer.entries[2].buy.visible, "an owned hero has no recruit button")
	_game.capacity = 5
	_game.events.roster_changed.emit()
	_check(_drawer.club.text == "Club 3/5 heroes", "club line follows the capacity: %s" % _drawer.club.text)
	_check(not _drawer.entries[3].buy.disabled and _drawer.entries[3].buy.tooltip_text == "", "room in the hall: recruit works again")
	_game.capacity = 3
	_game.events.roster_changed.emit()
	_check(_drawer.entries[3].buy.disabled, "capacity back to 3: disabled again")
	_game.capacity = 5
	_game.events.roster_changed.emit()


func _lineup() -> void:
	# capacity 2 and lineup [0, 1]: a pick into the full lineup swaps out the oldest one (no need to remove first)
	_drawer.entries[2].card.pressed.emit()
	_check(_lineup_is([1, 2]), "picking into a full lineup swaps out the oldest pick")
	_game.set_preferred_lineup([0, 1] as Array[int])
	_drawer.entries[0].card.pressed.emit()
	_check(_lineup_is([0, 1]), "lineup keeps the minimum of 2")
	_check("at least 2" in _drawer.hint.text, "hint explains the minimum: %s" % _drawer.hint.text)
	# for-sale hero click does nothing
	_drawer.entries[3].card.pressed.emit()
	_check(_lineup_is([0, 1]), "clicking a for-sale hero does not touch the lineup")
	_set_gold(2000)
	_drawer.fighters_buy.pressed.emit()
	_drawer.entries[2].card.pressed.emit()
	_check(_lineup_is([0, 1, 2]), "capacity 3 accepts Nia")
	_check(_drawer.entries[2].card.selected and _drawer.entries[2].slot.count == 3, "Nia highlighted in slot 3")
	_check("3/3" in _drawer.hint.text and "full" in _drawer.hint.text, "hint shows full lineup: %s" % _drawer.hint.text)
	_drawer.entries[0].card.pressed.emit()
	_check(_lineup_is([1, 2]), "toggling an owned fighter removes them")
	_check(not _drawer.entries[0].card.selected and _drawer.entries[1].slot.count == 1, "slots renumber after a removal")
	_game.state.preferred_lineup = [] as Array[int]
	_game.events.roster_changed.emit()
	_check("needs 2" in _drawer.hint.text, "hint asks for fighters when the lineup is short: %s" % _drawer.hint.text)
	_game.set_preferred_lineup([0, 1] as Array[int])


func _expansions() -> void:
	_check(_drawer.fighters_buy.cost == 700000 and _drawer.fighters_buy.disabled, "next fighter slot shows its price, unaffordable")
	_check(_drawer.seats_buy.cost == 5500 and _drawer.seats_buy.disabled, "seats show 5500, unaffordable at 500 gold")
	_check(_drawer.seats_buy.get_parent().get_node("Label").text.contains("100 > 150"), "seats label shows current > next")
	_set_gold(10000000)
	_drawer.seats_buy.pressed.emit()
	_check(_game.state.seats_tier == 1 and _game.state.gold == 10000000 - 5500, "seats button calls expand_seats")
	_check(_drawer.seats_buy.get_parent().get_node("Label").text.contains("150 > 200"), "seats label moves to the next tier right after buying")
	_drawer.seats_buy.pressed.emit()
	_drawer.fighters_buy.pressed.emit()
	_drawer.fighters_buy.pressed.emit()
	_check(_game.state.seats_tier == 2 and _game.state.fighter_tier == 3, "both expansions reach their last tier")
	_check(not _drawer.seats_buy.visible and not _drawer.fighters_buy.visible, "maxed expansions hide their buttons")
	_check(_drawer.seats_buy.get_parent().get_node("Label").text.contains("max"), "maxed label says max")


func _events_only() -> void:
	# state changed behind the drawer's back: nothing redraws until an Events signal arrives (no polling)
	_game.state.heroes[3].level = 5
	_check(_drawer.entries[3].card.level == 1, "no redraw without a signal")
	_game.events.hero_changed.emit(3)
	_check(_drawer.entries[3].card.level == 5, "hero_changed refreshes the entry")
	_game.state.heroes[0].wins = 7
	_game.events.fight_finished.emit({})
	_check(_drawer.entries[0].card.level == 1, "fight_finished refreshes the entries")
	_game.fight = {"lineup": [0, 1]}
	_game.events.fight_started.emit({})
	_check("next bout" in _drawer.hint.text, "hint says edits apply from the next bout while fighting")
	_game.fight = {}
	_game.events.fight_finished.emit({})
	_check(not ("next bout" in _drawer.hint.text), "hint clears after the fight")


func _open_close() -> void:
	var closed := [0]
	_drawer.closed.connect(func() -> void: closed[0] += 1)
	_drawer.open()
	_check(_drawer.is_open, "open() opens")
	_check(_drawer.panel_size.x <= 1240.0 and _drawer.panel_size.y <= 264.0, "panel sized to the host")
	_drawer.close()
	_check(not _drawer.is_open and closed[0] == 1, "close() closes and emits closed")
