extends Node

var HEROES: Dictionary = {}
var ENEMIES: Dictionary = {}
var BUILDINGS: Dictionary = {}
var RESEARCH: Dictionary = {}
var STAGES: Dictionary = {}

func _ready() -> void:
	HEROES = _load_dir("res://data/heroes/")
	ENEMIES = _load_dir("res://data/enemies/")
	BUILDINGS = _load_dir("res://data/buildings/")
	RESEARCH = _load_dir("res://data/research/")
	for number in range(1, 21):
		STAGES[number] = load("res://data/stages/stage_%02d.tres" % number)

func hero_for(building_id: String, rarity: int) -> HeroData:
	var building: BuildingData = BUILDINGS[building_id]
	for hero: HeroData in HEROES.values():
		if hero.hero_class == building.hero_class and hero.rarity == rarity:
			return hero
	return null

func research_for(building: BuildingData) -> Array[ResearchNodeData]:
	var result: Array[ResearchNodeData] = []
	for node: ResearchNodeData in RESEARCH.values():
		if node.branch != "crew" or node.rank <= TownRules.MAX_CREW - building.starting_crew:
			result.append(node)
	result.sort_custom(func(a: ResearchNodeData, b: ResearchNodeData): return a.id < b.id)
	return result

func _load_dir(path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("GameData: could not open %s" % path)
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		# Exported text resources may be listed as .tres.remap in the PCK.
		file_name = file_name.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			var res: Resource = load(path + file_name)
			if res != null: out[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	return out
