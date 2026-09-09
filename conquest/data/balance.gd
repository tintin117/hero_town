class_name ConquestBalance
extends Resource

@export_group("Starting town")
@export_range(0.0, 100000.0) var starting_gold := 200.0
@export_range(0, 10000) var starting_wood := 0
@export_range(0, 10000) var starting_food := 0
@export_range(1, 1000) var starting_warriors := 3
@export_group("Economy")
@export_range(0.0, 10000.0) var base_income := 10.0
@export_range(0.0, 10000.0) var development_income := 5.0
@export_range(0, 100000) var development_cost := 60
@export_range(0, 100000) var academy_cost := 60
@export_range(0, 1000) var academy_plots := 1
@export_group("Training and research")
@export_range(1, 1000) var warrior_reward := 2
@export_range(0, 100000) var first_warrior_cost := 20
@export_range(0.1, 86400.0) var first_warrior_duration := 30.0
@export_range(0, 100000) var warrior_cost := 40
@export_range(0.1, 86400.0) var warrior_duration := 180.0
@export_range(0, 100000) var mage_cost := 30
@export_range(0.1, 86400.0) var mage_duration := 60.0
@export_range(0, 100000) var healing_cost := 60
@export_range(0.1, 86400.0) var healing_duration := 300.0
@export_group("Combat")
@export_range(0.1, 100000.0) var warrior_hp := 40.0
@export_range(0.0, 100000.0) var warrior_attack := 4.0
@export_range(0.0, 100000.0) var mage_attack := 4.0
@export_range(0.0, 100000.0) var fireball_damage := 12.0
@export_range(0.0, 100000.0) var healing_amount := 40.0
@export_range(1, 1000) var spell_interval := 3
@export_range(1, 10000) var battle_ticks := 90
@export_range(0.1, 600.0) var presentation_duration := 14.0
@export_range(0.0, 86400.0) var recovery_duration := 120.0
@export var encounters: Array[ConquestEncounter] = []
