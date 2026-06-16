extends Node

const ENEMIES := {
	"E001": {
		"id": "E001", "name": "Cave Slime", "tier": 1,
		"hp": 45, "atk": 4, "def": 0,
		"spawn_time": 1.0,
		"gold_min": 50, "gold_max": 50,
		"shard_min": 1, "shard_max": 2
	},
	"E002": {
		"id": "E002", "name": "Tunnel Goblin", "tier": 2,
		"hp": 70, "atk": 6, "def": 1,
		"spawn_time": 7.0,
		"gold_min": 12, "gold_max": 18,
		"shard_min": 1, "shard_max": 3
	},
}

const HEROES := {
	"H001": {
		"id": "H001", "name": "Militia Ratcatcher", "rarity": "Common", "class": "Warrior",
		"base_power": 12, "power_per_level": 2.0,
		"hp": 100, "atk": 8, "def": 0,
		"atk_speed": 1.6,
		"upgrade_gold_base": 20, "upgrade_shard_base": 2
	},
}

const BUILDINGS := {
	"town_hall": {
		"display_name": "Town Hall",
		"build_cost": 0,
		"unlock_th_level": 1,
		"cells_wide": 2,
		"levels": [
			{"cost": 0,   "hero_level_cap": 10, "label": "Lv1"},
			{"cost": 250, "hero_level_cap": 20, "label": "Lv2"},
		]
	},
	"portal": {
		"display_name": "Portal",
		"build_cost": 0,
		"unlock_th_level": 1,
		"cells_wide": 2,
		"levels": [
			{"cost": 0,   "enemy_tier": 1, "label": "Lv1"},
			{"cost": 300, "enemy_tier": 2, "label": "Lv2"},
		]
	},
	"shrine": {
		"display_name": "Shrine",
		"build_cost": 0,
		"unlock_th_level": 2,
		"cells_wide": 1,
		"levels": [
			{"cost": 0, "label": "Lv1"},
		]
	},
	"tavern": {
		"display_name": "Tavern",
		"build_cost": 700,
		"unlock_th_level": 3,
		"cells_wide": 2,
		"levels": [
			{"cost": 0, "label": "Lv1"},
		]
	},
	"blacksmith": {
		"display_name": "Blacksmith",
		"build_cost": 600,
		"unlock_th_level": 3,
		"cells_wide": 1,
		"levels": [
			{"cost": 0, "label": "Lv1"},
		]
	},
}
