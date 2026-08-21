class_name EnemyData
extends Resource

enum UnitType { MELEE, RANGED }

@export var id: String
@export var display_name: String
@export var tier: int
@export var unit_type: UnitType = UnitType.MELEE
@export var hp: float
@export var atk: float
@export var spawn_time: float
@export var gold_min: int
@export var gold_max: int
@export var shard_min: int
@export var shard_max: int
