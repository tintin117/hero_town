class_name BuildingData
extends Resource

@export var id: String
@export var display_name: String
@export var build_cost: int
@export var unlock_th_level: int
@export var thumbnail: Texture2D
@export var sprite_texture: Texture2D
@export var model_scene: PackedScene
@export var levels: Array[Dictionary] = []

## Hero class this building produces (Warrior/Rogue/Mage/Cleric). Only meaningful
## for hero-producing buildings (e.g. Barracks); ignored by Portal/Town Hall/etc.
@export var hero_class: HeroData.HeroClass = HeroData.HeroClass.WARRIOR
## Possible upgrade rewards {"type": "tier_up"|"count_up"|"stat_buff", "weight": int, ...}.
## Only meaningful for hero-producing buildings.
@export var reward_pool: Array[Dictionary] = []
