@tool
extends Button

## -- Icon / Label --------------------------------------------------
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_update_visuals()

@export var label_text: String = "Settings":
	set(value):
		label_text = value
		_update_visuals()

@export var icon_size: Vector2 = Vector2(24, 24):
	set(value):
		icon_size = value
		_update_visuals()

## -- Size ------------------------------------------------------------
@export var collapsed_width: float = 48.0:
	set(value):
		collapsed_width = value
		_update_visuals()

@export var expanded_width: float = 150.0:
	set(value):
		expanded_width = value
		_update_visuals()

@export var button_height: float = 48.0:
	set(value):
		button_height = value
		_update_visuals()

@export var animation_time: float = 0.2

## -- Corner radius (all 4 corners together, for quick tweaking) ------
@export_range(0, 100, 1) var corner_radius: int = 20:
	set(value):
		corner_radius = value
		_update_visuals()

## -- Color -------------------------------------------------------------
@export var bg_color: Color = Color(0.2, 0.55, 0.9):
	set(value):
		bg_color = value
		_update_visuals()

@export var bg_color_hover: Color = Color(0.25, 0.6, 0.95)

## -- Editor preview toggle ---------------------------------------------
@export var preview_expanded: bool = true:
	set(value):
		preview_expanded = value
		_update_visuals()

@onready var hbox: HBoxContainer = $HBox
@onready var icon_rect: TextureRect = $HBox/Icon
@onready var label: Label = $HBox/Label
@onready var collapse_timer: Timer = $CollapseTimer

var style: StyleBoxFlat
var tween: Tween

func _ready() -> void:
	text = ""
	flat = false
	clip_text = true

	style = StyleBoxFlat.new()
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)

	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	_update_visuals()

	if not Engine.is_editor_hint():
		custom_minimum_size.x = collapsed_width
		size.x = collapsed_width
		label.modulate.a = 0.0
		mouse_entered.connect(_on_hover)
		mouse_exited.connect(_on_unhover)
		collapse_timer.wait_time = 0.08
		collapse_timer.one_shot = true
		collapse_timer.timeout.connect(_on_collapse_timeout)

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if style:
		style.bg_color = bg_color
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.corner_radius_bottom_right = corner_radius

	if icon_rect:
		icon_rect.texture = icon_texture
		icon_rect.custom_minimum_size = icon_size
		icon_rect.size = icon_size

	if label:
		label.text = label_text

	custom_minimum_size.y = button_height

	var target_w: float = expanded_width if (Engine.is_editor_hint() and preview_expanded) else collapsed_width
	if Engine.is_editor_hint() and not preview_expanded:
		target_w = collapsed_width

	custom_minimum_size.x = target_w
	size = Vector2(target_w, button_height)

	if label:
		label.modulate.a = 1.0 if (Engine.is_editor_hint() and preview_expanded) else (0.0 if Engine.is_editor_hint() else label.modulate.a)

	queue_redraw()

func _on_hover() -> void:
	collapse_timer.stop()
	_animate(expanded_width, 1.0, bg_color_hover)

func _on_unhover() -> void:
	collapse_timer.start()
	#_animate(collapsed_width, 0.0, bg_color)
	
func _on_collapse_timeout() -> void:
	_animate(collapsed_width, 0.0, bg_color)

func _animate(target_width: float, label_alpha: float, target_color: Color) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "custom_minimum_size:x", target_width, animation_time)
	tween.tween_property(label, "modulate:a", label_alpha, animation_time)
	tween.tween_property(style, "bg_color", target_color, animation_time)
