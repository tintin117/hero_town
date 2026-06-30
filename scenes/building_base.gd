extends Node3D


func is_overlapping() -> bool:
	return $Area3D.get_overlapping_areas().size() > 1
