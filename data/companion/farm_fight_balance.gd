class_name FarmFightBalance
extends Resource

@export_group("Opening")
@export var starting_gold := 25.0
@export var starting_wood := 20.0
@export var starting_farmers := 4
@export var starting_warriors := 1
@export var starting_tower := true
@export_group("Farming")
@export var spot_capacity := 5
@export var production_per_second := 0.3
@export var land_yield_growth := 0.25
@export var farmer_gold := 50.0
@export var efficiency_gold := 60.0
@export var efficiency_wood := 30.0
@export var efficiency_per_rank := 0.25
@export var cost_exponent := 1.5
@export_group("Heroes")
@export var heroes: Array[FarmHeroData] = []
@export var hero_cap := 12
@export var stat_per_rank := 0.2
@export var spawn_per_rank := 0.15
@export var minimum_spawn_seconds := 2.0
@export var recruit_seconds := 20.0
@export_group("Frontier")
@export var enemy_cap := 40
@export var wave_seconds := 20.0
@export var wave_size := 1
@export var enemy_health := 125.0
@export var enemy_power := 10.0
@export var enemy_attack_seconds := 1.5
@export var tower_health := 1800.0
@export var enemy_growth := 0.4
@export var enemy_growth_exponent := 1.5
@export var land_names := PackedStringArray(["Sunlit Meadow", "Amber Quarry", "River Watch"])
@export var wave_patterns: Array[PackedStringArray] = [PackedStringArray(["warrior"]), PackedStringArray(["warrior", "archer", "warrior"]), PackedStringArray(["lancer", "warrior", "archer"])]

func hero(id: String) -> FarmHeroData:
	for entry in heroes:
		if entry.id == id: return entry
	return null

func cost(base: float, rank: int) -> float:
	return ceil(base * pow(1.0 + rank, cost_exponent))

func land_name(index: int) -> String:
	return "Home" if index == 0 else "%s %d" % [land_names[(index - 1) % land_names.size()], index]

func strength(index: int) -> float:
	return pow(1.0 + max(0, index - 1) * enemy_growth, enemy_growth_exponent)
