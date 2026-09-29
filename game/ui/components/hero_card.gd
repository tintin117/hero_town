class_name HeroCard
extends MarginContainer
## Compact hero card: portrait, name, level, HP / mana bars, trait chips. Click = `pressed`.
## States: selected (gold ring), disabled (dimmed + lock, no click). Setters only. Min size ~ (184, 80).
## Portrait: a 64x64 Avatars texture is cropped 1:1 (no rescale); other sizes are shown as-is.

signal pressed

const CHIP := preload("res://game/ui/components/trait_chip.tscn")

@export var portrait: Texture2D:
	set(v):
		portrait = v
		_refresh()
@export var hero_name := "":
	set(v):
		hero_name = v
		_refresh()
@export var level := 1:
	set(v):
		level = v
		_refresh()
@export_range(0.0, 1.0, 0.01) var hp := 1.0:
	set(v):
		hp = v
		_refresh()
@export_range(0.0, 1.0, 0.01) var mana := 1.0:
	set(v):
		mana = v
		_refresh()
@export var selected := false:
	set(v):
		selected = v
		_refresh()
@export var disabled := false:
	set(v):
		disabled = v
		_refresh()

var _traits: Array[Texture2D] = []
var _trait_tips := PackedStringArray()
var _hover: Tween

@onready var _portrait: TextureRect = $Card/Row/Frame/Portrait
@onready var _name: Label = $Card/Row/Info/Top/Name
@onready var _level: Label = $Card/Row/Info/Top/Level
@onready var _hp: PixelBar = $Card/Row/Info/Bars/Hp
@onready var _mana: PixelBar = $Card/Row/Info/Bars/Mana
@onready var _chips: HBoxContainer = $Card/Row/Info/Traits
@onready var _ring: Control = $Ring
@onready var _lock: TextureRect = $Card/Row/Frame/Lock


func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh()


func set_hp(current: float, maximum: float) -> void:
	hp = current / maxf(maximum, 1.0)
	if is_node_ready():
		_hp.tooltip_text = "HP %d/%d" % [current, maximum]


func set_mana(current: float, maximum: float) -> void:
	mana = current / maxf(maximum, 1.0)
	if is_node_ready():
		_mana.tooltip_text = "Mana %d/%d" % [current, maximum]


## Trait icons (any size, shown 24px) with matching tooltips.
func set_traits(icons: Array[Texture2D], tips := PackedStringArray()) -> void:
	_traits = icons
	_trait_tips = tips
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()


func _on_hover(inside: bool) -> void:
	if disabled:
		return
	if _hover:
		_hover.kill()
	_hover = create_tween()
	var lit := 1.12 if inside else 1.0
	_hover.tween_property(self, "modulate", Color(lit, lit, lit), 0.08)


func _refresh() -> void:
	if not is_node_ready():
		return
	if portrait is Texture2D and portrait.get_size() == Vector2(64, 64):
		var a := AtlasTexture.new()
		a.atlas = portrait
		a.region = Rect2(4, 6, 56, 52)
		_portrait.texture = a
	else:
		_portrait.texture = portrait
	_name.text = hero_name
	_level.text = "Lv %d" % level
	_hp.ratio = hp
	_mana.ratio = mana
	_ring.visible = selected
	_lock.visible = disabled
	modulate = Color(0.62, 0.62, 0.7) if disabled else Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	for c in _chips.get_children():
		c.queue_free()
		_chips.remove_child(c)
	for i in _traits.size():
		var chip := CHIP.instantiate()
		_chips.add_child(chip)
		chip.set_icon(_traits[i], _trait_tips[i] if i < _trait_tips.size() else "")
