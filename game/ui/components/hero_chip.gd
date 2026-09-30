class_name HeroChip
extends VBoxContainer
## Compact hero marker for the slim bottom bar: avatar plus a thin HP bar. Driven only by setters.

@export var portrait: Texture2D:
	set(v):
		portrait = v
		_refresh()
@export var hero_name := "":
	set(v):
		hero_name = v
		tooltip_text = v

var hp := 1.0

@onready var _portrait: TextureRect = $Portrait
@onready var _bar: ProgressBar = $Hp


func _ready() -> void:
	_refresh()


func set_hp(current: float, maximum: float) -> void:
	hp = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	if is_node_ready():
		_bar.value = hp


func _refresh() -> void:
	if not is_node_ready():
		return
	if portrait is Texture2D and portrait.get_size() == Vector2(64, 64):
		var crop := AtlasTexture.new()
		crop.atlas = portrait
		crop.region = Rect2(4, 6, 56, 52)  # same crop as HeroCard
		_portrait.texture = crop
	else:
		_portrait.texture = portrait
	_bar.value = hp
