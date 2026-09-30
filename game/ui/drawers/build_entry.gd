class_name BuildEntry
extends PanelContainer
## One building in the build drawer: icon, name, level pips, current and next effect, and a Build / Upgrade / Max
## button plus Move once built. Dumb view: the drawer pushes state with show_building() and listens to the signals.
## `extra` is a slot to the right of the info column (the Gym puts its training panel there).

signal action_requested(id: StringName)  ## Build (level 0) or Upgrade
signal move_requested(id: StringName)

const STAR := preload("res://resources/ui/icons/star.png")
const STAR_EMPTY := preload("res://resources/ui/icons/star_empty.png")

var building_id: StringName = &""
var level := 0
var maxed := false

@onready var extra: HBoxContainer = %Extra
@onready var buy: CostButton = %Buy
@onready var move: Button = %Move
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _pips: HBoxContainer = %Pips
@onready var _now: Label = %Now
@onready var _next: Label = %Next
@onready var _ring: Panel = %Ring


func _ready() -> void:
	buy.pressed.connect(func() -> void: action_requested.emit(building_id))
	move.pressed.connect(func() -> void: move_requested.emit(building_id))


## `cost` < 0 means maxed. `next_text` is ignored then.
func show_building(id: StringName, title: String, tip: String, icon: Texture2D, lvl: int, max_level: int,
		now_text: String, next_text: String, cost: int, affordable: bool) -> void:
	building_id = id
	level = lvl
	maxed = cost < 0
	tooltip_text = tip
	_icon.texture = icon
	_name.text = title
	for i in _pips.get_child_count():
		(_pips.get_child(i) as TextureRect).texture = STAR if i < lvl else STAR_EMPTY
		_pips.get_child(i).visible = i < max_level
	_now.text = now_text
	_next.text = "Max level" if maxed else "Next: " + next_text
	buy.cost = 0 if maxed else cost
	buy.label = "Max" if maxed else "Upgrade" if lvl > 0 else "Build"
	buy.icon = null if maxed else buy.currency_icon
	buy.theme_type_variation = &"" if maxed else &"CostButton"  # a maxed building is done, not "too expensive" red
	buy.unaffordable = not maxed and not affordable
	if maxed:
		buy.text = "Max"
		buy.disabled = true
	move.visible = lvl > 0


## A short gold ring so the player sees which entry a click in the town pointed at.
func highlight() -> void:
	_ring.visible = true
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_callback(_ring.hide)
