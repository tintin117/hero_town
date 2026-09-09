extends Control

func _ready() -> void:
	pass


func _on_play_button_pressed() -> void:
	GameState.update_setting("compact", false)
	get_tree().change_scene_to_file("res://scenes/town_2d.tscn")


func _on_compact_button_pressed() -> void:
	get_tree().change_scene_to_file("res://conquest/companion.tscn")
	



func _on_quit_button_pressed() -> void:
	get_tree().quit()
