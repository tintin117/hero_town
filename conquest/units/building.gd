class_name ConquestBuilding
extends Node2D

signal action_requested(action: String, anchor: Node2D)
@export_enum("home", "barracks", "academy", "army", "frontier") var action := "home"

func _ready() -> void:
	$Hit.tooltip_text = action.capitalize()
	$Hit.pressed.connect(func(): action_requested.emit(action, $PopupAnchor))

func refresh(state: Dictionary, activity_text: String) -> void:
	$Activity.text = activity_text
	if action == "academy":
		$Visual.visible = state.academy
		$LockedVisual.visible = not state.academy
