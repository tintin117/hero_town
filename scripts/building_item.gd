extends Button

class_name BuildingItem

@onready var building_image: TextureRect = $VBoxContainer/BuildingImage
@onready var building_name: Label = $VBoxContainer/BuildingName
@onready var price_label: Label = $VBoxContainer/HBoxContainer/Price
@onready var hover: Control = $Hover
## Fallback values used when incoming data is missing/invalid
const DEFAULT_TEXTURE_PATH := "res://icon.svg"  # swap for your own placeholder icon
const DEFAULT_NAME := "Unknown Building"
const DEFAULT_PRICE := 0

const HOVER_FADE_TIME := 0.15

var _hover_tween: Tween

func _ready() -> void:
	# Start hidden
	hover.modulate.a = 0.0

	# If root is a Button, these signals exist natively.
	# If root is a plain Control/PanelContainer, make sure mouse_filter = Stop,
	# then these same signals still work.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered() -> void:
	_animate_hover(1.0)

func _on_mouse_exited() -> void:
	_animate_hover(0.0)

func _animate_hover(target_alpha: float) -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover, "modulate:a", target_alpha, HOVER_FADE_TIME)

func setup(texture: Texture2D = null, building_name_text: String = "", price: Variant = null) -> void:
	# Texture fallback
	if texture == null:
		texture = load(DEFAULT_TEXTURE_PATH)
	building_image.texture = texture

	# Name fallback
	if building_name_text.is_empty():
		building_name_text = DEFAULT_NAME
	building_name.text = building_name_text

	# Price fallback — handles null, non-numeric, or negative values
	var safe_price: int = DEFAULT_PRICE
	if price != null and (price is int or price is float):
		safe_price = max(int(price), 0)
	price_label.text = str(safe_price)
