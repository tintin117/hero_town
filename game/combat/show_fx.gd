extends Node2D
## The series show layer: the MAIN EVENT banner and the bought prop (fireworks, announcer,
## spotlights, ringside bar). begin(info) at the bell, finish() at the end of the series;
## everything is presentation and reads only the series_started payload. Old payloads without
## `main_event` / `prop` simply show nothing.

const ANNOUNCER_LOUD := 1.6

var active := false
var prop := &""
var _crowd: Node2D
var _fx: Node2D
var _sfx: Node
@onready var _banner: Node2D = $Banner
@onready var _props: Node2D = $Props
@onready var _bar: Node2D = $Bar


func setup(crowd: Node2D, fx: Node2D, sfx: Node) -> void:
	_crowd = crowd
	_sfx = sfx
	_fx = fx


func begin(info: Dictionary) -> void:
	finish()
	active = true
	var event: Variant = info.get("main_event")
	if event is Dictionary and not event.is_empty():
		_banner.show_event(event)
		_crowd.cheer(1.0)
	var named: Variant = info.get("prop")
	prop = StringName(named) if named is String or named is StringName else &""
	_props.start(prop, _fx)
	if prop == &"ringside_bar":
		_bar.start()
	_crowd.loud = ANNOUNCER_LOUD if prop == &"announcer" else 1.0


func finish() -> void:
	active = false
	prop = &""
	_banner.hide_now()
	_props.stop()
	_bar.stop()
	if _crowd != null:
		_crowd.loud = 1.0


func banner_visible() -> bool:
	return _banner.is_showing()


func props_running() -> bool:
	return _props.is_running() or _bar.is_running()


## Concessions were paid for a bout: the bar stall throws coins.
func bout_paid(result: Dictionary) -> void:
	if _bar.is_running():
		_bar.pay(int(result.get("concessions", 20)))
		_sfx.play(&"coin")


func tick(delta: float) -> void:
	_banner.tick(delta)
	_props.tick(delta)
	_bar.tick(delta)
