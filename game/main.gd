extends Control
## Thin shell. G0: boots empty. Later gates add MainMenu, World and HUD here — never rules or drawing.


func _ready() -> void:
	get_window().title = "Fight club"
