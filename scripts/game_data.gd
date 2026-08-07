extends Node

var HEROES: Dictionary = {}
var ENEMIES: Dictionary = {}
var BUILDINGS: Dictionary = {}

func _ready() -> void:
	HEROES = _load_dir("res://data/heroes/")
	ENEMIES = _load_dir("res://data/enemies/")
	BUILDINGS = _load_dir("res://data/buildings/")

func _load_dir(path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("GameData: could not open %s" % path)
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			out[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	return out
