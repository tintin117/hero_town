extends PanelContainer


func _ready() -> void:
	visible = false
func open() -> void:
	visible = true
func close() -> void:
	visible = false


func _on_close_button_pressed() -> void:
	visible = false
