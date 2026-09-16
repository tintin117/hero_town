class_name ConquestBalance
extends Resource
## Shared by both conquest presentations. Values are gold, seconds and HP.

@export_group("New Game")
@export_range(0, 10000, 1, "or_greater") var starting_gold: float = 200.0
@export_range(1, 40, 1) var starting_warriors: int = 3
@export_group("Economy")
@export_range(0, 1000, 1, "or_greater") var base_income: float = 10.0
@export_range(0, 1000, 1, "or_greater") var development_income: float = 5.0
@export_range(0, 10000, 1, "or_greater") var development_cost: int = 60
@export_range(0, 10000, 1, "or_greater") var academy_cost: int = 60
@export_group("Training")
@export_range(0, 10000, 1, "or_greater") var first_warrior_cost: int = 20
@export_range(0.1, 3600, 0.1, "or_greater") var first_warrior_seconds: float = 30.0
@export_range(0, 10000, 1, "or_greater") var warrior_cost: int = 40
@export_range(0.1, 3600, 0.1, "or_greater") var warrior_seconds: float = 180.0
@export_range(0, 10000, 1, "or_greater") var mage_cost: int = 30
@export_range(0.1, 3600, 0.1, "or_greater") var mage_seconds: float = 60.0
@export_range(0, 10000, 1, "or_greater") var healing_cost: int = 60
@export_range(0.1, 3600, 0.1, "or_greater") var healing_seconds: float = 300.0
@export_group("Combat")
@export_range(1, 10000, 1, "or_greater") var warrior_hp: float = 40.0
@export_range(0, 1000, 0.1, "or_greater") var warrior_damage: float = 4.0
@export_range(0, 1000, 0.1, "or_greater") var mage_damage: float = 4.0
@export_range(0, 1000, 0.1, "or_greater") var fireball_damage: float = 12.0
@export_range(0, 1000, 0.1, "or_greater") var healing_amount: float = 40.0
@export_range(1, 90, 1) var spell_interval: int = 3
@export_group("Pacing")
@export_range(0, 3600, 0.1, "or_greater") var recovery_seconds: float = 120.0
@export_range(0.1, 120, 0.1, "or_greater") var presentation_seconds: float = 14.0
@export_group("Expeditions")
@export var lands: Array[ConquestLand] = []
