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
const TOAST := preload("res://game/ui/components/toast.tscn")
const HOLD_TIME := 0.7  ## seconds to hold the Bell button to plant
const DRAWERS := {
	&"roster": "res://game/ui/drawers/roster_drawer.tscn",
	&"manager": "res://game/ui/drawers/manager_drawer.tscn",
	&"seeds": "res://game/ui/drawers/seed_tray.tscn",
}
const TOAST_ICONS := {&"fame": "laurel", &"seats": "crowd", &"fighters": "shield", &"recruit": "sword"}

var game: Node
var events: Node
var router: DrawerRouter

var _hold := -1.0  ## seconds the plant button has been held, -1 when not held
var _toasts := []  ## slot -> live toast; toasts stack upwards

@onready var _gold: StatPill = %Gold
@onready var _fame: StatPill = %Fame
@onready var _hype: HypeGauge = %Hype
@onready var _seats: StatPill = %Seats
@onready var _excitement: ExcitementGauge = %Excitement
@onready var _bell: Button = %Bell
@onready var _fill: ProgressBar = %Fill
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
	_bell.button_down.connect(_start_hold)
	_bell.button_up.connect(_stop_hold)
	events.planted_changed.connect(_refresh_bell)
	%Manager.pressed.connect(toggle_drawer.bind(&"manager"))
	%Roster.pressed.connect(toggle_drawer.bind(&"roster"))
	%Seeds.pressed.connect(toggle_drawer.bind(&"seeds"))
	events.planted_changed.connect(_sync_tray)
	events.series_started.connect(func(_info: Dictionary) -> void: _sync_tray())
	%Roster.disabled = not router.has_drawer(&"roster")
	%Roster.tip = "Roster" if router.has_drawer(&"roster") else "Roster: coming soon"

	events.gold_changed.connect(func(gold: int, _delta: int) -> void: _gold.set_value(gold))
	events.hype_changed.connect(_on_hype)
	events.fame_changed.connect(_on_fame)
	events.manager_changed.connect(_refresh_manager)
	events.roster_changed.connect(_refresh_bell)
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
	_refresh_bell()
	_refresh_seats()
	_sync_tray()


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
	_refresh_bell()
	%Manager.tip = "Bell rings at hype >= %d" % int(manager.threshold) if manager.enabled else "Auto bell is off"


# --- bottom bar ------------------------------------------------------------------------------

## The Bell button is the plant action: hold it to plant the selected lineup. Afterwards it shows
## the state (growing towards the bell, then the bout and score).
func _refresh_bell() -> void:
	var manager: Dictionary = game.state.manager
	var series: Dictionary = game.series
	var text := ""
	var tip := ""
	if not series.is_empty():
		var score := []
		var names := []
		for id: int in series.lineup:
			score.append(str(series.wins.get(id, 0)))
			names.append("%s %d" % [game.hero_defs[id].display_name, series.wins.get(id, 0)])
		text = "Bout %d\n%s" % [series.bout + 1, "-".join(score)]
		tip = "First to %d wins.  %s" % [game.tuning.series_wins, "  ".join(names)]
	elif not game.planted.is_empty():
		text = "Growing\nbell at %d" % int(manager.threshold)
		tip = "Planted. The bell rings by itself when hype reaches %d." % int(manager.threshold)
	elif not manager.enabled:
		text = "Bell off"
		tip = "The auto bell is off (see the manager)."
	elif not Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup):
		text = "Pick %d+\nfighters" % game.tuning.min_lineup
		tip = "Pick the fighters to plant from the cards on the left."
	else:
		text = "Hold to\nplant"
		tip = "Hold to plant the selected fighters. Hype grows once they are planted; the bell rings at %d." % int(manager.threshold)
	_bell.text = text
	_bell.tooltip_text = tip
	var ready: bool = series.is_empty() and game.planted.is_empty() and manager.enabled \
			and Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup)
	_bell.disabled = not ready
	if not ready:
		_stop_hold()


func _start_hold() -> void:
	_hold = 0.0


func _stop_hold() -> void:
	_hold = -1.0
	_fill.value = 0.0


## Hold-to-plant: the bar fills while the button is held; releasing early cancels.
func _process(delta: float) -> void:
	if _hold < 0.0:
		return
	_hold += delta
	_fill.value = minf(1.0, _hold / HOLD_TIME)
	if _hold >= HOLD_TIME:
		_stop_hold()
		game.plant()


## The seed tray slides up whenever nothing is planted and tucks away once a lineup is planted.
func _sync_tray() -> void:
	_refresh_bell()
	if not is_visible_in_tree():
		return  # a drawer opened behind the main menu would be laid out against a hidden parent
	if game.planted.is_empty() and game.series.is_empty():
		if router.current == &"":
			router.open(&"seeds")
	elif router.current == &"seeds":
		router.close()


func _on_fight_started(_info: Dictionary) -> void:
	_excitement.set_value(0.0)
	_excitement.set_multiplier(_multiplier_text(game.tuning.excitement_multipliers[0]))
	_excitement.visible = true
	_refresh_seats()
	_refresh_bell()


## HP lives on the fighters in the arena; the HUD only follows excitement.
func _on_combat_event(event: Dictionary) -> void:
	var excitement := float(event.get("excitement", _excitement.value))
	_excitement.set_value(excitement)
	_excitement.set_multiplier(_multiplier_text(Economy.excitement_multiplier(excitement, game.tuning)))


func _on_fight_finished(result: Dictionary) -> void:
	_excitement.visible = false
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
