class_name ExcitementGauge
extends HBoxContainer
## Excitement 0-100 with dividers at the tier marks (25 / 60), the current tier's icon + name and the
## multiplier text, so the tier reads without colour. Setters only. Min size ~ (260, 52).

@export_range(0.0, 100.0) var value := 0.0:
	set(v):
		value = v
		_refresh()
@export var tier_marks := PackedFloat32Array([25.0, 60.0]):
	set(v):
		tier_marks = v
		_refresh()
@export var tier_names := PackedStringArray(["CALM", "EXCITED", "WILD"]):
	set(v):
		tier_names = v
		_refresh()
## One icon per tier (marks.size() + 1). Defaults to calm / star / burst.
@export var tier_icons: Array[Texture2D] = []:
	set(v):
		tier_icons = v
		_refresh()
## e.g. "x1.25"; empty hides it.
@export var multiplier_text := "":
	set(v):
		multiplier_text = v
		_refresh()

const DEFAULT_ICONS: Array[Texture2D] = [
	preload("res://resources/ui/icons/calm.png"),
	preload("res://resources/ui/icons/star.png"),
	preload("res://resources/ui/icons/burst.png"),
]

var tier := 0
var _last_tier := -1

@onready var _bar: GaugeBar = $Column/Bar
@onready var _icon: TextureRect = $Icon
@onready var _name: Label = $Column/Head/TierName
@onready var _mult: Label = $Column/Head/Multiplier
@onready var _number: Label = $Column/Head/Number


func _ready() -> void:
	_refresh()


func set_value(v: float) -> void:
	value = v


func set_multiplier(text: String) -> void:
	multiplier_text = text


func _refresh() -> void:
	if not is_node_ready():
		return
	tier = 0
	for m in tier_marks:
		if value >= m:
			tier += 1
	_bar.value = value
	_bar.marks = tier_marks
	_number.text = str(int(value))
	_name.text = tier_names[mini(tier, tier_names.size() - 1)] if tier_names.size() > 0 else ""
	_mult.text = multiplier_text
	_mult.visible = multiplier_text != ""
	if tier < tier_icons.size():
		_icon.texture = tier_icons[tier]
	else:
		_icon.texture = DEFAULT_ICONS[mini(tier, DEFAULT_ICONS.size() - 1)]
	if _last_tier >= 0 and tier != _last_tier:  # tier change: pop the icon
		_icon.pivot_offset = _icon.size / 2
		var t := create_tween()
		t.tween_property(_icon, "scale", Vector2(1.35, 1.35), 0.1)
		t.tween_property(_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_last_tier = tier
