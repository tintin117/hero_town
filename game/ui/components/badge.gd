class_name Badge
extends Control
## Small round marker: a count, a short text ("!") or an icon, tinted. Hides itself when empty (unless show_empty).
## Used for "story ripe", "shop open", "upgrade affordable". Size 24x24.

@export var count := 0:
	set(v):
		count = v
		_refresh()
@export var text := "":
	set(v):
		text = v
		_refresh()
@export var icon: Texture2D:
	set(v):
		icon = v
		_refresh()
@export var tint := Color("e0453f"):
	set(v):
		tint = v
		_refresh()
@export var pulsing := false:
	set(v):
		pulsing = v
		_sync_pulse()
@export var show_empty := false:
	set(v):
		show_empty = v
		_refresh()

var _tween: Tween

@onready var _circle: TextureRect = $Circle
@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Count


func _ready() -> void:
	_refresh()
	_sync_pulse()


func set_count(n: int) -> void:
	count = n


func _refresh() -> void:
	if not is_node_ready():
		return
	var has_text := text != "" or count > 0
	visible = show_empty or has_text or icon != null
	_circle.self_modulate = tint
	_icon.texture = icon
	_icon.visible = icon != null
	_label.visible = icon == null and has_text
	_label.text = text if text != "" else (str(mini(count, 99)))


func _sync_pulse() -> void:
	if not is_node_ready():
		return
	if _tween:
		_tween.kill()
	scale = Vector2.ONE
	if pulsing:
		pivot_offset = size / 2
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
