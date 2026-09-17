extends SceneTree
## Kept as the documented native-test entry point.
func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	root.add_child(load("res://tests/companion/farm_fight_ui.tscn").instantiate())
