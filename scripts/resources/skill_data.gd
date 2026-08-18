@tool
class_name SkillData
extends Resource

enum Shape { AOE, PROJECTILE }

@export var mana_cost: float = 100.0
@export var damage: float = 20.0
@export var shape: Shape = Shape.AOE
@export var radius: float = 2.5
@export var projectile_speed: float = 8.0
@export var duration: float = 0.4
@export var tick_interval: float = 0.0 ## 0 = single hit on contact; >0 = re-damage every interval while overlapping.
