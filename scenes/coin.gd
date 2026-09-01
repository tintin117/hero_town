extends Node2D

var targetPos
var label

func _ready() -> void:
	var target = get_tree().current_scene.get_node_or_null("CanvasLayer/Coin_HUD/Sprite2D")
	label = get_tree().current_scene.get_node_or_null("CanvasLayer/Coin_HUD/CurrencyLabel")
	if target == null or label == null:
		queue_free()
		return
	targetPos = target.global_position
	# Pop in, hop up, then fly to the HUD.
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", position.y - 24.0, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_animate_collect_coin)

func _animate_collect_coin() -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", targetPos, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		fx.spawn("pickup_sparkle", targetPos)
		sfx.play("coin"))
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.05)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.08)
	tween.tween_callback(queue_free)
