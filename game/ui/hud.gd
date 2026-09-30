extends Control
## The in-game HUD: top bar (gold, fame, hype, crowd, menu), a status pill, a tool column (manager, roster, locked tabs),
## the fight excitement gauge, a drawer host and a toast layer. It never writes state: it calls Game commands
## and redraws from Events signals. Only its own widgets take the mouse, so the town below stays draggable.
##
## `game` / `events` default to the autoloads (which do not exist under --script); tests assign them before add_child.
## Shell API: signals main_menu_requested / quit_requested (forwarded from the pause menu), `router` (open drawers),
## open_pause(). Named nodes for tests: %Gold %Fame %Hype %Seats %Text (status) %Manager %Roster %Build %Excitement.
## Build: signal placement_requested(id, moving) for the shell, focus_building(id) from the town. Arena gestures: press_arena() / release_arena().
## Stories: %Stories opens the stories drawer, its %Ripe badge counts ripe stories that are not the Main Event; the status pill
## names the Main Event (and shows the prop icon, %PropIcon) of what is planted or running.

signal main_menu_requested
signal quit_requested
signal plant_progress(ratio: float)  ## 0..1 while the arena is held to plant
signal placement_requested(id: StringName, moving: bool)  ## the build drawer asked to place / move a building (the shell asks the town)

const ICONS := "res://resources/ui/icons/"
const TOAST := preload("res://game/ui/components/toast.tscn")
const HOLD_TIME := 0.9  ## seconds to hold the arena to plant
const TAP_TIME := 0.25  ## a press shorter than this is a tap
const DRAWERS := {
	&"roster": "res://game/ui/drawers/roster_drawer.tscn",
	&"manager": "res://game/ui/drawers/manager_drawer.tscn",
	&"seeds": "res://game/ui/drawers/seed_tray.tscn",
	&"build": "res://game/ui/drawers/build_drawer.tscn",
	&"stories": "res://game/ui/drawers/stories_drawer.tscn",
}
const TOAST_ICONS := {&"fame": "laurel", &"seats": "crowd", &"fighters": "shield", &"recruit": "sword", &"story": "scroll"}

var game: Node
var events: Node
var router: DrawerRouter

var _hold := -1.0  ## seconds the arena has been held for planting, -1 when not held
var _pressed_for := 0.0
var _taps := false  ## an arena press is in progress
var _toasts := []  ## slot -> live toast; toasts stack upwards
var _main_event := {}  ## the running series' Main Event {id, kind, title, ripeness, multiplier}, {} if none (kept for the last bout's toast)
var _prop: StringName = &""  ## the prop the running series uses

@onready var _gold: StatPill = %Gold
@onready var _fame: StatPill = %Fame
@onready var _hype: HypeGauge = %Hype
@onready var _seats: StatPill = %Seats
@onready var _excitement: ExcitementGauge = %Excitement
@onready var _status: Label = %Text
@onready var _prop_icon: TextureRect = %PropIcon
@onready var _ripe_badge: Badge = %Ripe
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
	events.planted_changed.connect(_refresh_status)
	%Manager.pressed.connect(toggle_drawer.bind(&"manager"))
	%Roster.pressed.connect(toggle_drawer.bind(&"roster"))
	%Build.pressed.connect(toggle_drawer.bind(&"build"))
	%Stories.pressed.connect(toggle_drawer.bind(&"stories"))
	router.drawer_changed.connect(_on_drawer_changed)
	events.planted_changed.connect(_sync_tray)
	events.series_started.connect(_on_series_started)
	%Roster.disabled = not router.has_drawer(&"roster")
	%Roster.tip = "Roster" if router.has_drawer(&"roster") else "Roster: coming soon"
	%Build.disabled = not router.has_drawer(&"build")
	%Stories.disabled = not router.has_drawer(&"stories")

	events.gold_changed.connect(func(gold: int, _delta: int) -> void: _gold.set_value(gold))
	events.hype_changed.connect(_on_hype)
	events.fame_changed.connect(_on_fame)
	events.manager_changed.connect(_refresh_manager)
	events.roster_changed.connect(_refresh_status)
	events.fight_started.connect(_on_fight_started)
	events.combat_event.connect(_on_combat_event)
	events.fight_finished.connect(_on_fight_finished)
	events.series_started.connect(func(_info: Dictionary) -> void: _refresh_seats(); _refresh_status())
	events.series_finished.connect(_on_series_finished)
	for signal_name in [&"story_changed", &"story_ripe", &"roster_changed", &"series_started", &"series_finished", &"planted_changed"]:
		events.get(signal_name).connect(func(_a: Variant = null) -> void: _refresh_ripe_badge())
	events.prop_changed.connect(_refresh_status)
	events.paused_changed.connect(func(_paused: bool) -> void: _refresh_status())
	events.toast.connect(func(text: String, icon: StringName) -> void: show_toast(TOAST_ICONS.get(icon, "info"), text))
	sync_all()


## Redraws everything from `game.state` (also what new_game / continue_game trigger through Events).
func sync_all() -> void:
	_gold.value = game.state.gold
	_hype.value = game.state.hype
	_on_fame(game.state.fame_points, Fame.tier(game.state.fame_points, game.tuning))
	_refresh_manager()
	_refresh_status()
	_refresh_seats()
	_refresh_ripe_badge()
	_sync_tray()


func open_pause() -> void:
	router.close()
	_pause.open()


func toggle_drawer(key: StringName) -> void:
	if router.current == key:
		router.close()
	else:
		router.open(key)


## Opens the build drawer on a building's entry (the shell calls this when the player clicks a building in the town).
func focus_building(id: StringName) -> void:
	if router.open(&"build"):
		(router.get_drawer(&"build") as BuildDrawer).focus(id)


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


## The build drawer is created lazily by the router: hook its placement request when it first opens.
func _on_drawer_changed(key: StringName) -> void:
	if key != &"build":
		return
	var drawer: BuildDrawer = router.get_drawer(key) as BuildDrawer
	if not drawer.place_requested.is_connected(_on_place_requested):
		drawer.place_requested.connect(_on_place_requested)


func _on_place_requested(id: StringName, moving: bool) -> void:
	placement_requested.emit(id, moving)


# --- top bar ---------------------------------------------------------------------------------

func _on_hype(hype: float) -> void:
	_hype.set_value(hype)
	_refresh_seats()
	_refresh_status()


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
	_refresh_status()
	%Manager.tip = "Bell rings at hype >= %d" % int(manager.threshold) if manager.enabled else "Auto bell is off"


# --- bottom bar ------------------------------------------------------------------------------

## The status pill says what the arena wants next: pick, plant, wait, or the series score.
func _refresh_status() -> void:
	var manager: Dictionary = game.state.manager
	var series: Dictionary = game.series
	var text := ""
	var tip := ""
	var main := ""
	var prop: StringName = &""
	if not series.is_empty():
		_main_event = series.get("main_event", _main_event)
		_prop = series.get("prop", _prop)
		main = _main_event_text(_main_event)
		prop = _prop
		var score := []
		var names := []
		for id: int in series.lineup:
			score.append(str(series.wins.get(id, 0)))
			names.append("%s %d" % [game.hero_defs[id].display_name, series.wins.get(id, 0)])
		text = "Bout %d  %s" % [series.bout + 1, "-".join(score)]
		tip = "First to %d wins.  %s" % [game.tuning.series_wins, "  ".join(names)]
		if main != "":
			text += "  " + main
	elif not game.planted.is_empty():
		var chosen := _story(game.main_event_id)
		main = _main_event_text(chosen)
		prop = game.selected_prop
		text = "Growing - bell at %d" % int(manager.threshold)
		tip = "Planted. The bell rings by itself when hype reaches %d." % int(manager.threshold)
		if main != "":
			text = "%s - bell at %d" % [main, int(manager.threshold)]
	elif not manager.enabled:
		text = "Bell off"
		tip = "The auto bell is off (see the manager)."
	elif not Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup):
		text = "Tap the arena: pick %d+ fighters" % game.tuning.min_lineup
		tip = "Tap the arena to pick the fighters to plant."
	else:
		text = "Hold the arena to plant"
		tip = "Hold the arena to plant the picked fighters. Tap it to change them. The bell rings at hype %d." % int(manager.threshold)
	_status.text = text
	_status.tooltip_text = tip
	_show_prop(prop)
	if main != "":
		_status.tooltip_text += "  Main Event: every bout pays more."
	if not _can_plant():
		_stop_hold()


## "Main Event: <title> x2.6" for a story or series dictionary, "" when there is none.
func _main_event_text(story: Dictionary) -> String:
	if story.is_empty():
		return ""
	var mult := float(story.get("multiplier", StoryLook.multiplier(float(story.get("ripeness", 0.0)))))
	return "Main Event: %s %s" % [story.title, StoryLook.multiplier_text(mult)]


func _story(id: int) -> Dictionary:
	for story: Dictionary in game.stories():
		if story.id == id:
			return story
	return {}


func _show_prop(id: StringName) -> void:
	_prop_icon.visible = id != &""
	if _prop_icon.visible:
		for def in game.prop_defs():
			if def.id == id:
				_prop_icon.texture = StoryLook.icon_named(def.icon_name)
				_prop_icon.tooltip_text = "Prop: " + def.display_name


## The Stories button's badge: ripe stories that are not already the Main Event.
func _refresh_ripe_badge() -> void:
	var n := 0
	for story: Dictionary in game.stories():
		if story.ripe and story.id != game.main_event_id:
			n += 1
	_ripe_badge.set_count(n)
	_ripe_badge.pulsing = n > 0
	%Stories.tip = "Stories: %d ripe" % n if n > 0 else "Stories"


func _on_series_started(info: Dictionary) -> void:
	_main_event = info.get("main_event", {})
	_prop = info.get("prop", &"")
	_sync_tray()


func _can_plant() -> bool:
	return game.series.is_empty() and game.planted.is_empty() and game.state.manager.enabled 			and Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup)


## Arena gestures (the shell forwards the pointer): a tap opens the seed tray, a hold plants.
func press_arena() -> void:
	_pressed_for = 0.0
	_hold = 0.0 if _can_plant() else -1.0
	_taps = true


func release_arena() -> void:
	var was_tap := _taps and _pressed_for < TAP_TIME
	_stop_hold()
	_taps = false
	if was_tap and game.planted.is_empty() and game.series.is_empty():
		toggle_drawer(&"seeds")


func _stop_hold() -> void:
	_hold = -1.0
	plant_progress.emit(0.0)


func _process(delta: float) -> void:
	if not _taps:
		return
	_pressed_for += delta
	if _hold < 0.0 or _pressed_for < TAP_TIME:
		return
	_hold += delta
	plant_progress.emit(minf(1.0, _hold / HOLD_TIME))
	if _hold >= HOLD_TIME:
		_taps = false
		_stop_hold()
		game.plant()


## The seed tray tucks away once a lineup is planted. It only pops up by itself when the pick is
## unusable (tap the arena to open it otherwise): the last pick is remembered, so replanting is one hold.
func _sync_tray() -> void:
	_refresh_status()
	if not is_visible_in_tree():
		return  # a drawer opened behind the main menu would be laid out against a hidden parent
	if game.planted.is_empty() and game.series.is_empty():
		if router.current == &"" and not Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup):
			router.open(&"seeds")
	elif router.current == &"seeds":
		router.close()


func _on_fight_started(_info: Dictionary) -> void:
	_excitement.set_value(0.0)
	_excitement.set_multiplier(_multiplier_text(game.tuning.excitement_multipliers[0]))
	_excitement.visible = true
	_refresh_seats()
	_refresh_status()


## HP lives on the fighters in the arena; the HUD only follows excitement.
func _on_combat_event(event: Dictionary) -> void:
	var excitement := float(event.get("excitement", _excitement.value))
	_excitement.set_value(excitement)
	_excitement.set_multiplier(_multiplier_text(Economy.excitement_multiplier(excitement, game.tuning)))


func _on_fight_finished(result: Dictionary) -> void:
	_excitement.visible = false
	_refresh_seats()
	_refresh_status()
	var winner := int(result.get("winner", -1))
	if winner >= 0 and winner < game.hero_defs.size():
		var snacks := int(result.get("concessions", 0))
		var main_mult := float(_main_event.get("multiplier", 1.0))
		show_toast("trophy", "%s wins!  +%d gold (%s)  +%d fame%s%s" % [game.hero_defs[winner].display_name,
				result.payout, _multiplier_text(result.multiplier), result.fame_gained,
				"  Main Event %s" % _multiplier_text(main_mult) if main_mult > 1.0 else "",
				"  +%d snacks" % snacks if snacks > 0 else ""], 4.0)


func _on_series_finished(result: Dictionary) -> void:
	_main_event = {}
	_prop = &""
	_refresh_seats()
	_refresh_status()
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
