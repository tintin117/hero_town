extends TextureButton

class_name AnimationButton

var animation_tween: Tween
var focused = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_entered.connect(_button_mouse_entered)
	mouse_exited.connect(_button_mouse_exited)
	
	focus_entered.connect(_button_focus_entered)
	focus_exited.connect(_button_focus_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _button_focus_entered() -> void:
	
	if animation_tween:
		animation_tween.kill()
	
	if not focused:
		focused = true
		animation_tween = create_tween()
		
		animation_tween.set_parallel(true)
		animation_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		animation_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.1, 1), 0.1)

func _button_focus_exited() -> void:
	if animation_tween:
		animation_tween.kill()
	
	if focused:
		focused = false
		animation_tween = create_tween()
		
		animation_tween.set_parallel(true)
		animation_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		animation_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)

func _button_mouse_entered() -> void:
	if not has_focus():
		self.grab_focus()

func _button_mouse_exited() -> void:
	if has_focus():
		self.release_focus()
