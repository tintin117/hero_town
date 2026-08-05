class_name DamageNumber2D
extends Node2D

@onready var label: Label = %Label
@onready var label_container: Node2D = %LabelContainer
@onready var ap: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
	ap.animation_finished.connect(func(_anim): remove())

func set_values_and_animate(value: String, start_pos: Vector2, height: float, spread: float) -> void:
	# Reset state before animating
	label_container.modulate.a = 1.0
	label_container.position = Vector2.ZERO

	label.text = value
	ap.play("Rise and Fade")

	var tween = get_tree().create_tween()
	var end_pos = Vector2(randf_range(-spread, spread), -height) + start_pos
	var tween_length = ap.get_animation("Rise and Fade").length
	tween.tween_property(label_container, "position", end_pos, tween_length).from(start_pos)

func remove() -> void:
	ap.stop()
	# Remove from tree but DO NOT free — keeps instance alive in pool
	if is_inside_tree():
		get_parent().remove_child(self)
