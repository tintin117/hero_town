class_name ConquestLand
extends Resource
## One expedition. The order in the balance resource is the conquest order.

@export var name: String = "New land"
@export_multiline var hint: String = ""
@export_group("Rewards")
@export_range(0, 1000, 1, "or_greater") var income: int = 5
@export_range(0, 10, 1, "or_greater") var plots: int = 1
@export_group("Enemies")
@export_range(1, 40, 1) var count: int = 2
@export_range(1, 10000, 1, "or_greater") var hp: float = 22.0
@export_range(0, 1000, 0.1, "or_greater") var attack: float = 3.0
