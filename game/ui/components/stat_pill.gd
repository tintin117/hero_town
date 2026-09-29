class_name StatPill
extends PanelContainer
## Icon + short number (gold, seats, fame tier ...). Optional thin progress bar under the number.
## Driven by setters only. Min size ~ (56, 37).

@export var icon: Texture2D:
	set(v):
		icon = v
		_refresh()
## Shown instead of the number when not empty (e.g. "Tier 2").
@export var text := "":
	set(v):
		text = v
		_refresh()
@export var prefix := ""
@export var suffix := ""
@export var value := 0.0:
	set(v):
		_value = v
		_shown = v
		_refresh()
	get:
		return _value
## 0..1 progress bar under the number; negative hides it.
@export_range(-1.0, 1.0, 0.01) var progress := -1.0:
	set(v):
		progress = v
		_refresh()

var _value := 0.0
var _shown := 0.0
var _tween: Tween

@onready var _icon: TextureRect = $Row/Icon
@onready var _label: Label = $Row/Column/Value
@onready var _bar: ProgressBar = $Row/Column/Progress


func _ready() -> void:
	_refresh()


## Counts up/down to `v` and pops the label. Use this for live changes; the `value` property snaps.
func set_value(v: float, animate := true) -> void:
	if not animate or not is_node_ready() or is_equal_approx(v, value):
		value = v
		return
	var from := _shown
	_value = v
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(x: float) -> void:
		_shown = x
		_refresh(), from, v, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_label.pivot_offset = _label.size / 2
	var pop := create_tween()
	pop.tween_property(_label, "scale", Vector2(1.2, 1.2), 0.08)
	pop.tween_property(_label, "scale", Vector2.ONE, 0.16)


func set_text(t: String) -> void:
	text = t


func set_progress(p: float) -> void:
	progress = p


func _refresh() -> void:
	if not is_node_ready():
		return
	_icon.texture = icon
	_icon.visible = icon != null
	_label.text = text if text != "" else prefix + _fmt(int(roundf(_shown))) + suffix
	_bar.visible = progress >= 0.0
	_bar.value = clampf(progress, 0.0, 1.0)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
