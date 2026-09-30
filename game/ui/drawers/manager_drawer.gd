extends Drawer
## Manager settings: on/off and "Bell at hype >= X", plus a live "Bell in ~N s" estimate.
## `game` / `events` default to the autoloads; tests set them before add_child.

var game: Node
var events: Node
var _dragging := false

@onready var _toggle: CheckButton = %Toggle
@onready var _threshold: Label = %Threshold
@onready var _slider: HSlider = %Slider
@onready var _estimate: Label = %Estimate


func _ready() -> void:
	super._ready()
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	_toggle.toggled.connect(func(_on: bool) -> void: _commit())
	_slider.drag_started.connect(func() -> void: _dragging = true)
	_slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		_commit())
	_slider.value_changed.connect(_on_slider)
	events.manager_changed.connect(_refresh)
	events.hype_changed.connect(func(_h: float) -> void: _update_texts())
	events.fight_started.connect(func(_i: Dictionary) -> void: _update_texts())
	events.fight_finished.connect(func(_r: Dictionary) -> void: _update_texts())
	events.roster_changed.connect(_update_texts)
	_refresh()


func _refresh() -> void:
	var manager: Dictionary = game.state.manager
	_toggle.set_pressed_no_signal(manager.enabled)
	_slider.set_value_no_signal(clampf(manager.threshold, _slider.min_value, _slider.max_value))
	_update_texts()


func _on_slider(_value: float) -> void:
	_update_texts()
	if not _dragging:  # keyboard steps commit at once; a mouse drag commits on release (each commit autosaves)
		_commit()


func _commit() -> void:
	game.set_manager(_toggle.button_pressed, _slider.value)


func _update_texts() -> void:
	_threshold.text = "Bell at hype >= %d" % int(_slider.value)
	_estimate.text = _estimate_text()


func _estimate_text() -> String:
	if not _toggle.button_pressed:
		return "Auto bell is off: no fights start."
	if not game.fight.is_empty():
		return "Fight in progress."
	if not Roster.valid_lineup(game.state, game.tuning, game.state.preferred_lineup):
		return "Needs a valid lineup."
	var hype: float = game.state.hype
	if hype >= _slider.value:
		return "Bell rings now."
	# Inverse of Hype.grow: time for hype to climb from `hype` to the threshold.
	var t: Tuning = game.tuning
	return "Bell in ~%d s" % ceili(t.hype_tau * Buildings.hype_tau_multiplier(game.state, game.catalog) * log((t.hype_max - hype) / (t.hype_max - _slider.value)))
