extends Node

func _ready() -> void:
	assert(not GameState.persistence_enabled, "Preview must never load or save player progression")
	GameState.settings.volume = 0.0
	GameState.settings.compact = true
	GameState.settings.always_on_top = true
	GameState.gold = 1000
	GameState.cleared_stage = 4
	GameState.place_building("barracks", Vector2i(3, 1))
	GameState.place_building("mage_tower", Vector2i(6, 1))
	GameState.tutorial = 3
	var town := preload("res://game/town/town.tscn").instantiate()
	get_tree().root.add_child.call_deferred(town)
	get_tree().set_deferred("current_scene", town)
