extends Node2D
var targetPos
var label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var target = get_tree().current_scene.get_node_or_null("CanvasLayer/Coin_HUD/Sprite2D")
	label = get_tree().current_scene.get_node_or_null("CanvasLayer/Coin_HUD/CurrencyLabel")
	if target == null or label == null:
		return
	targetPos = target.global_position
	await get_tree().create_timer(1).timeout
	_animate_collect_coin()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _animate_collect_coin() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", targetPos, 0.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(self, "visible", false, 0.0)
	tween.tween_property(label, "scale", Vector2(1.1,1.1), 0.05)
	#replace global.coin with new coin number
	#tween.tween_property(label, "text", str(global.coins), 0.0)
	tween.chain().tween_property(label, "scale", Vector2(1.0,1.0), 0.05)
	tween.chain().tween_callback(queue_free)
