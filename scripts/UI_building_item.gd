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
const HOVER_SCALE := 0.9
const NORMAL_SCALE := 1
const HOVER_PULSE_TIME := 0.4

var _hover_tween: Tween

func _ready() -> void:
	# Start hidden
	hover.modulate.a = 0.0
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered() -> void:
	_start_hover_pulse()

func _on_mouse_exited() -> void:
	_stop_hover_pulse()
	
func _start_hover_pulse() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_loops()
	hover.modulate.a = 1.0
	_hover_tween.tween_property(hover, "scale", Vector2.ONE * HOVER_SCALE, HOVER_PULSE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(hover, "scale", Vector2.ONE * NORMAL_SCALE, HOVER_PULSE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_hover_pulse() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	var exit_tween := create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(hover, "modulate:a", 0.0, HOVER_FADE_TIME)
	exit_tween.tween_property(hover, "scale", Vector2.ONE * NORMAL_SCALE, HOVER_FADE_TIME)

func _animate_hover(target_alpha: float) -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(hover, "modulate:a", target_alpha, HOVER_FADE_TIME)

func setup(texture: Texture2D = null, building_name_text: String = "", price: Variant = null, can_afford: bool = true) -> void:
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

	disabled = not can_afford
	if not can_afford:
		modulate = Color(1, 1, 1, 0.55)
		price_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2))
