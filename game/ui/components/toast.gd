class_name Toast
extends PanelContainer
## Icon + short text that slides up, holds, fades and frees itself. Add to a plain Control layer (not a container),
## anchored where toasts should appear; the toast slides relative to the position it was given.
## setup() before add_child. Signal: finished().

signal finished

@export var icon: Texture2D
@export var text := ""
@export var life := 2.2

@onready var _icon: TextureRect = $Row/Icon
@onready var _label: Label = $Row/Text


func setup(p_icon: Texture2D, p_text: String, p_life := 2.2) -> Toast:
	icon = p_icon
	text = p_text
	life = p_life
	return self


func _ready() -> void:
	_icon.texture = icon
	_icon.visible = icon != null
	_label.text = text
	modulate.a = 0.0
	await get_tree().process_frame  # let the parent layer place us first
	var rest := position
	position = rest + Vector2(0, 16)
	var t := create_tween().set_parallel()
	t.tween_property(self, "position", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.chain().tween_interval(life)
	t.chain().tween_property(self, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(func() -> void:
		finished.emit()
		queue_free())
