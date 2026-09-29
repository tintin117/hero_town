class_name RosterDrawer
extends Drawer
## Roster screen: recruit heroes, pick the preferred lineup, buy seats / fighter slots.
## Open it with open() inside a full-rect Control (best: the strip between the top and bottom bars, so
## the bars stay visible). Bottom edge, sized to the parent. Emits `closed` (from Drawer).
##
## `Game` / `Events` are autoloads in the real game and absent in --script tests, so they are plain
## fields: set `game` and `events` before add_child (tests) or leave them and _ready() finds the autoloads.
## Reads game.state for display, writes only through Game commands, refreshes only from Events.

const ENTRY := preload("res://game/ui/drawers/roster_entry.tscn")
const MAX_WIDTH := 1240.0
const MAX_HEIGHT := 264.0  # the strip between the bars is ~272 tall

var game: Node
var events: Node
var entries: Array[RosterEntry] = []

@onready var hint: Label = $Column/Body/Footer/Hint
@onready var seats_buy: CostButton = $Column/Body/Footer/Seats/Buy
@onready var fighters_buy: CostButton = $Column/Body/Footer/Fighters/Buy
@onready var _row: HBoxContainer = $Column/Body/Scroll/Entries


func _ready() -> void:
	super._ready()
	if game == null:
		game = get_node_or_null("/root/Game")
	if events == null:
		events = get_node_or_null("/root/Events")
	if game == null:
		return
	for def: HeroDef in game.hero_defs:
		var entry: RosterEntry = ENTRY.instantiate()
		_row.add_child(entry)
		entry.picked.connect(_toggle_lineup)
		entry.recruit_requested.connect(func(id: int) -> void: game.recruit(id))
		entries.append(entry)
	seats_buy.pressed.connect(func() -> void:
		game.expand_seats()
		refresh())  # Game.expand_seats emits gold_changed before the tier moves and nothing after
	fighters_buy.pressed.connect(func() -> void: game.expand_fighters())
	if events:
		for signal_name in [&"roster_changed", &"hero_changed", &"gold_changed", &"fight_started", &"fight_finished"]:
			events.connect(signal_name, _on_event)
	var p := get_parent() as Control
	if p:
		p.resized.connect(_on_parent_resized)
	refresh()


func open() -> void:
	_fit()
	super.open()


func refresh() -> void:
	var s: GameState = game.state
	var t: Tuning = game.tuning
	for i in entries.size():
		var def: HeroDef = game.hero_defs[i]
		var hero := s.heroes[i]
		entries[i].show_hero(def, hero, Roster.xp_needed(hero.level, t), s.preferred_lineup.find(i) + 1,
				game.can_afford(def.price))
	_show_expansion($Column/Body/Footer/Seats, "Seats", t.seat_tiers, s.seats_tier, Economy.seats_cost(s, t))
	_show_expansion($Column/Body/Footer/Fighters, "Fighters", t.fighter_tiers, s.fighter_tier, Economy.fighters_cost(s, t))
	hint.text = _lineup_hint(s, t)


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


## Game.set_preferred_lineup is the rule keeper (2..capacity, owned, no duplicates); we only explain a refusal.
func _toggle_lineup(id: int) -> void:
	var lineup: Array[int] = game.state.preferred_lineup.duplicate()
	if id in lineup:
		lineup.erase(id)
	else:
		lineup.append(id)
	if not game.set_preferred_lineup(lineup):
		hint.text = "Keep at least %d fighters" % game.tuning.min_lineup if id in game.state.preferred_lineup \
				else "Lineup full - remove a fighter first"


func _lineup_hint(s: GameState, t: Tuning) -> String:
	var count := s.preferred_lineup.size()
	var capacity := Roster.fighter_capacity(s, t)
	var text := "Lineup %d/%d" % [count, capacity]
	if count < t.min_lineup:
		text += " - needs %d fighters" % t.min_lineup
	elif count >= capacity:
		text += " - full"
	else:
		text += " - click to add or remove"
	if not game.fight.is_empty():
		text += " (next bout)"
	return text


## `cost` < 0 means maxed: show "(max)" and no button.
func _show_expansion(box: Control, title: String, tiers: PackedInt32Array, tier: int, cost: int) -> void:
	var label: Label = box.get_node("Label")
	var buy: CostButton = box.get_node("Buy")
	buy.visible = cost >= 0
	if cost < 0:
		label.text = "%s %d (max)" % [title, tiers[tier]]
		return
	label.text = "%s %d > %d" % [title, tiers[tier], tiers[tier + 1]]
	buy.cost = cost
	buy.unaffordable = not game.can_afford(cost)


func _fit() -> void:
	var ps := _parent_size()
	panel_size = Vector2(minf(MAX_WIDTH, ps.x - 2.0 * margin), minf(MAX_HEIGHT, ps.y - 2.0 * margin))


func _on_parent_resized() -> void:
	if is_open:
		_fit()
		size = panel_size
		_snap()
