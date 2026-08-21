class_name HeroData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum HeroClass { WARRIOR, ROGUE, MAGE, CLERIC }
enum UnitType { MELEE, RANGED }

@export var id: String
@export var display_name: String
@export var rarity: Rarity = Rarity.COMMON
@export var hero_class: HeroClass = HeroClass.WARRIOR
@export var unit_type: UnitType = UnitType.MELEE
@export var base_power: float
@export var power_per_level: float
@export var base_hp: float
@export var atk_speed: float
@export var mana_per_hit: float = 20.0
@export var upgrade_gold_base: int
@export var upgrade_shard_base: int
@export var dupe_shard: int
@export var th_unlock: int
