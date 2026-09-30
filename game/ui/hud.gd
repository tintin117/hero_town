extends Control
## The in-game HUD: top bar (gold, fame, hype, crowd, menu), bottom bar (lineup, bell status, manager, roster, locked tabs),
## the fight excitement gauge, a drawer host and a toast layer. It never writes state: it calls Game commands
## and redraws from Events signals. Only its own widgets take the mouse, so the town below stays draggable.
##
## `game` / `events` default to the autoloads (which do not exist under --script); tests assign them before add_child.
## Shell API: signals main_menu_requested / quit_requested (forwarded from the pause menu), `router` (open drawers),
## open_pause(). Named nodes for tests: %Gold %Fame %Hype %Seats %Bell %Manager %Roster %Excitement %Cards.

signal main_menu_requested
signal quit_requested

const ICONS := "res://resources/ui/icons/"
const CARD := preload("res://game/ui/components/hero_card.tscn")
const TOAST := preload("res://game/ui/components/toast.tscn")
const DRAWERS := {
	&"roster": "res://game/ui/drawers/roster_drawer.tscn",
	&"manager": "res://game/ui/drawers/manager_drawer.tscn",
}
const TOAST_ICONS := {&"fame": "laurel", &"seats": "crowd", &"fighters": "shield", &"recruit": "sword"}

var game: Node
var events: Node
var router: DrawerRouter

var _hp := {}  ## hero id -> hit points during a fight (empty when idle)
var _mana := {}
var _cards := {}  ## hero id -> HeroCard
var _toasts := []  ## slot -> live toast; toasts stack upwards

@onready var _gold: StatPill = %Gold
@onready var _fame: StatPill = %Fame
@onready var _hype: HypeGauge = %Hype
@onready var _seats: StatPill = %Seats
@onready var _excitement: ExcitementGauge = %Excitement
@onready var _bell: Control = %Bell
@onready var _bell_text: Label = %Text
@onready var _pause: Control = %PauseMenu


func _ready() -> void:
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	router = DrawerRouter.new()
	router.host = %Drawers
	router.context = {"game": game, "events": events}
	for key: StringName in DRAWERS:
		router.register(key, DRAWERS[key])
	add_child(router)
	_pause.game = game
	_pause.main_menu_requested.connect(main_menu_requested.emit)
	_pause.quit_requested.connect(quit_requested.emit)

	var marks := PackedFloat32Array()
	for mark in game.tuning.excitement_thresholds.slice(1):
		marks.append(mark)
	_excitement.tier_marks = marks

	%Menu.pressed.connect(open_pause)
	%Manager.pressed.connect(toggle_drawer.bind(&"manager"))
	%Roster.pressed.connect(toggle_drawer.bind(&"roster"))
	%Roster.disabled = not router.has_drawer(&"roster")
	%Roster.tip = "Roster" if router.has_drawer(&"roster") else "Roster: coming soon"

	events.gold_changed.connect(func(gold: int, _delta: int) -> void: _gold.set_value(gold))
	events.hype_changed.connect(_on_hype)
	events.fame_changed.connect(_on_fame)
	events.manager_changed.connect(_refresh_manager)
	events.roster_changed.connect(_rebuild_cards)
	events.hero_changed.connect(_on_hero_changed)
	events.fight_started.connect(_on_fight_started)
	events.combat_event.connect(_on_combat_event)
	events.fight_finished.connect(_on_fight_finished)
	events.series_started.connect(func(_info: Dictionary) -> void: _refresh_seats(); _refresh_bell())
	events.series_finished.connect(_on_series_finished)
	events.paused_changed.connect(func(_paused: bool) -> void: _refresh_bell())
	events.toast.connect(func(text: String, icon: StringName) -> void: show_toast(TOAST_ICONS.get(icon, "info"), text))
	sync_all()


## Redraws everything from `game.state` (also what new_game / continue_game trigger through Events).
func sync_all() -> void:
	_gold.value = game.state.gold
	_hype.value = game.state.hype
	_on_fame(game.state.fame_points, Fame.tier(game.state.fame_points, game.tuning))
	_refresh_manager()
	_rebuild_cards()
	_refresh_seats()


func open_pause() -> void:
	router.close()
	_pause.open()


func toggle_drawer(key: StringName) -> void:
	if router.current == key:
		router.close()
	else:
		router.open(key)


func show_toast(icon: String, text: String, life := 2.4) -> void:
	var slot := _toasts.find_custom(func(t) -> bool: return not is_instance_valid(t))
	if slot < 0:
		_toasts.append(null)
		slot = _toasts.size() - 1
	var toast := (TOAST.instantiate() as Toast).setup(load(ICONS + icon + ".png"), text, life)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_top = -8.0 - slot * 48.0
	toast.offset_bottom = toast.offset_top
	_toasts[slot] = toast
	%Toasts.add_child(toast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and router.current == &"" and not _pause.visible:
		get_viewport().set_input_as_handled()
		open_pause()


# --- top bar ---------------------------------------------------------------------------------

func _on_hype(hype: float) -> void:
	_hype.set_value(hype)
	_refresh_seats()
	_refresh_bell()


func _on_fame(points: int, tier: int) -> void:
	var t: Tuning = game.tuning
	_fame.text = t.fame_tier_names[tier]
	_fame.progress = Fame.progress(points, t)
	var top := tier >= t.fame_tier_points.size() - 1
	_fame.tooltip_text = "Fame %d%s" % [points, "" if top else " / %d" % t.fame_tier_points[tier + 1]]


## The crowd of the running series, or what the bell would draw now.
func _refresh_seats() -> void:
	var live: bool = not game.series.is_empty()
	var seats: int = game.series.seats if live else Roster.seats(game.state, game.tuning)
	var crowd: int = game.crowd_now()
	_seats.text = "%d/%d" % [crowd, seats]
	_seats.tooltip_text = ("Crowd in the arena: %d of %d seats" if live else "Crowd when the bell rings now: %d of %d seats") % [crowd, seats]


func _refresh_manager() -> void:
	var manager: Dictionary = game.state.manager
	_hype.set_threshold(manager.threshold if manager.enabled else -1.0)
	%ManagerCaption.text = "Auto %d" % int(manager.threshold) if manager.enabled else "Manual"
	%Manager.tip = "Bell rings at hype >= %d" % int(manager.threshold) if manager.enabled else "Auto bell is off"


# --- bottom bar ------------------------------------------------------------------------------

## The bell rings by itself once hype reaches the threshold: idle it shows the target, during a
## series the bout number and score.
func _refresh_bell() -> void:
	var manager: Dictionary = game.state.manager
	var series: Dictionary = game.series
	if series.is_empty():
		_bell_text.text = "Bell at
hype %d" % int(manager.threshold) if manager.enabled else "Bell off"
		_bell.tooltip_text = "The bell rings by itself when hype reaches %d. First to %d wins the series." 				% [int(manager.threshold), game.tuning.series_wins]
		return
	var score := []
	var names := []
	for id: int in series.lineup:
		score.append(str(series.wins.get(id, 0)))
		names.append("%s %d" % [game.hero_defs[id].display_name, series.wins.get(id, 0)])
	_bell_text.text = "Bout %d
%s" % [series.bout + 1, "-".join(score)]
	_bell.tooltip_text = "First to %d wins.  %s" % [game.tuning.series_wins, "  ".join(names)]


func _rebuild_cards() -> void:
	for card in %Cards.get_children():
		%Cards.remove_child(card)
		card.queue_free()
	_cards.clear()
	for id: int in game.state.preferred_lineup:
		var card := CARD.instantiate() as HeroCard
		card.portrait = HeroPortraits.portrait(id)
		card.hero_name = game.hero_defs[id].display_name
		card.level = game.state.heroes[id].level
		card.pressed.connect(func() -> void: router.open(&"roster"))
		%Cards.add_child(card)
		_cards[id] = card
		_paint_card(id)
	_refresh_bell()


func _on_hero_changed(id: int) -> void:
	if _cards.has(id):
		_cards[id].level = game.state.heroes[id].level
		_paint_card(id)


func _max_hp(id: int) -> int:
	return Roster.stats_for(game.hero_defs[id], game.state.heroes[id].level, game.tuning).health


## Idle fighters show full HP and empty mana; during a fight the tracked values.
func _paint_card(id: int) -> void:
	if _cards.has(id):
		_cards[id].set_hp(_hp.get(id, _max_hp(id)), _max_hp(id))
		_cards[id].set_mana(_mana.get(id, 0), CombatSim.MANA_MAX)


# --- fight -----------------------------------------------------------------------------------

func _on_fight_started(info: Dictionary) -> void:
	_hp.clear()
	_mana.clear()
	for id: int in info.lineup:
		_hp[id] = _max_hp(id)
		_mana[id] = 0
		_paint_card(id)
	_excitement.set_value(0.0)
	_excitement.set_multiplier(_multiplier_text(game.tuning.excitement_multipliers[0]))
	_excitement.visible = true
	_refresh_seats()
	_refresh_bell()


## Replays the sim's event onto the bars. The mana numbers come from CombatSim's own constants.
func _on_combat_event(event: Dictionary) -> void:
	var attacker: int = event.get("attacker", -1)
	if str(event.get("kind")) == "skill":
		_mana[attacker] = 0
	elif str(event.get("kind")) == "attack" and _mana.has(attacker):
		_mana[attacker] = mini(CombatSim.MANA_MAX, _mana[attacker] + CombatSim.MANA_ON_HIT)
	for hit: Dictionary in event.get("hits", []):
		var victim: int = hit.target
		_hp[victim] = maxi(0, _hp.get(victim, 0) - int(hit.damage))
		if str(event.get("kind")) == "attack" and _hp[victim] > 0:
			_mana[victim] = mini(CombatSim.MANA_MAX, _mana.get(victim, 0) + CombatSim.MANA_ON_HURT)
	if _hp.has(attacker):
		_hp[attacker] = mini(_max_hp(attacker), _hp[attacker] + int(event.get("healing", 0)))
	for id: int in _hp:
		_paint_card(id)
	var excitement := float(event.get("excitement", _excitement.value))
	_excitement.set_value(excitement)
	_excitement.set_multiplier(_multiplier_text(Economy.excitement_multiplier(excitement, game.tuning)))


func _on_fight_finished(result: Dictionary) -> void:
	_excitement.visible = false
	var ids: Array = _hp.keys()
	_hp.clear()
	_mana.clear()
	for id: int in ids:
		_paint_card(id)
	_refresh_seats()
	_refresh_bell()
	var winner := int(result.get("winner", -1))
	if winner >= 0 and winner < game.hero_defs.size():
		show_toast("trophy", "%s wins!  +%d gold (%s)  +%d fame" % [game.hero_defs[winner].display_name,
				result.payout, _multiplier_text(result.multiplier), result.fame_gained], 4.0)


func _on_series_finished(result: Dictionary) -> void:
	_refresh_seats()
	_refresh_bell()
	var winner := int(result.winner)
	if winner >= 0:
		var lost := 0
		for id: int in result.wins:
			if id != winner:
				lost += int(result.wins[id])
		show_toast("trophy", "%s takes the series %d-%d!  +%d fame" % [game.hero_defs[winner].display_name,
				result.wins[winner], lost, result.fame_bonus], 4.5)


static func _multiplier_text(multiplier: float) -> String:
	return "x%s" % snappedf(multiplier, 0.01)
