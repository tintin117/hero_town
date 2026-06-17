extends Node

const ENEMIES := {
	"E001": {
		"id": "E001", "name": "Cave Slime", "tier": 1,
		"hp": 45, "atk": 4, "def": 0,
		"spawn_time": 5.0,
		"gold_min": 8, "gold_max": 12,
		"shard_min": 1, "shard_max": 2
	},
	"E002": {
		"id": "E002", "name": "Tunnel Goblin", "tier": 1,
		"hp": 70, "atk": 6, "def": 1,
		"spawn_time": 7.0,
		"gold_min": 12, "gold_max": 18,
		"shard_min": 1, "shard_max": 3
	},
	"E003": {
		"id": "E003", "name": "Bone Bat", "tier": 2,
		"hp": 120, "atk": 10, "def": 2,
		"spawn_time": 10.0,
		"gold_min": 24, "gold_max": 36,
		"shard_min": 3, "shard_max": 5
	},
	"E004": {
		"id": "E004", "name": "Mold Zombie", "tier": 2,
		"hp": 180, "atk": 13, "def": 4,
		"spawn_time": 12.0,
		"gold_min": 36, "gold_max": 54,
		"shard_min": 4, "shard_max": 7
	},
	"E005": {
		"id": "E005", "name": "Grave Hound", "tier": 3,
		"hp": 300, "atk": 21, "def": 6,
		"spawn_time": 15.0,
		"gold_min": 70, "gold_max": 100,
		"shard_min": 8, "shard_max": 12
	},
	"E006": {
		"id": "E006", "name": "Cultist", "tier": 3,
		"hp": 420, "atk": 28, "def": 8,
		"spawn_time": 18.0,
		"gold_min": 100, "gold_max": 145,
		"shard_min": 12, "shard_max": 18
	},
}

const HEROES := {
	"H001": {
		"id": "H001", "name": "Militia Ratcatcher", "rarity": "common", "class": "warrior",
		"base_power": 12, "power_per_level": 2.0,
		"base_hp": 100, "atk_speed": 1.6, "crit_chance": 0.02,
		"upgrade_gold_base": 20, "upgrade_shard_base": 2, "dupe_shard": 5, "th_unlock": 1
	},
	"H002": {
		"id": "H002", "name": "Candle Apprentice", "rarity": "common", "class": "mage",
		"base_power": 10, "power_per_level": 2.4,
		"base_hp": 70, "atk_speed": 1.9, "crit_chance": 0.04,
		"upgrade_gold_base": 20, "upgrade_shard_base": 2, "dupe_shard": 5, "th_unlock": 1
	},
	"H003": {
		"id": "H003", "name": "Street Cutpurse", "rarity": "common", "class": "rogue",
		"base_power": 11, "power_per_level": 2.1,
		"base_hp": 80, "atk_speed": 1.2, "crit_chance": 0.06,
		"upgrade_gold_base": 20, "upgrade_shard_base": 2, "dupe_shard": 5, "th_unlock": 1
	},
	"H004": {
		"id": "H004", "name": "Temple Novice", "rarity": "common", "class": "cleric",
		"base_power": 9, "power_per_level": 1.8,
		"base_hp": 90, "atk_speed": 1.8, "crit_chance": 0.02,
		"upgrade_gold_base": 20, "upgrade_shard_base": 2, "dupe_shard": 5, "th_unlock": 1
	},
	"H005": {
		"id": "H005", "name": "Iron Guard", "rarity": "uncommon", "class": "warrior",
		"base_power": 22, "power_per_level": 3.1,
		"base_hp": 160, "atk_speed": 1.7, "crit_chance": 0.03,
		"upgrade_gold_base": 60, "upgrade_shard_base": 6, "dupe_shard": 15, "th_unlock": 2
	},
	"H006": {
		"id": "H006", "name": "Ember Scholar", "rarity": "uncommon", "class": "mage",
		"base_power": 20, "power_per_level": 3.6,
		"base_hp": 110, "atk_speed": 2.0, "crit_chance": 0.06,
		"upgrade_gold_base": 60, "upgrade_shard_base": 6, "dupe_shard": 15, "th_unlock": 2
	},
	"H007": {
		"id": "H007", "name": "Dagger Twin", "rarity": "uncommon", "class": "rogue",
		"base_power": 21, "power_per_level": 3.2,
		"base_hp": 120, "atk_speed": 1.1, "crit_chance": 0.08,
		"upgrade_gold_base": 60, "upgrade_shard_base": 6, "dupe_shard": 15, "th_unlock": 2
	},
	"H008": {
		"id": "H008", "name": "Field Priest", "rarity": "uncommon", "class": "cleric",
		"base_power": 18, "power_per_level": 2.8,
		"base_hp": 140, "atk_speed": 1.8, "crit_chance": 0.03,
		"upgrade_gold_base": 60, "upgrade_shard_base": 6, "dupe_shard": 15, "th_unlock": 2
	},
	"H009": {
		"id": "H009", "name": "Grave Knight", "rarity": "rare", "class": "warrior",
		"base_power": 40, "power_per_level": 4.8,
		"base_hp": 260, "atk_speed": 1.7, "crit_chance": 0.05,
		"upgrade_gold_base": 160, "upgrade_shard_base": 16, "dupe_shard": 45, "th_unlock": 3
	},
	"H010": {
		"id": "H010", "name": "Bone Oracle", "rarity": "rare", "class": "mage",
		"base_power": 36, "power_per_level": 5.3,
		"base_hp": 170, "atk_speed": 2.1, "crit_chance": 0.09,
		"upgrade_gold_base": 160, "upgrade_shard_base": 16, "dupe_shard": 45, "th_unlock": 3
	},
	"H011": {
		"id": "H011", "name": "Crypt Ranger", "rarity": "rare", "class": "rogue",
		"base_power": 38, "power_per_level": 4.9,
		"base_hp": 190, "atk_speed": 1.2, "crit_chance": 0.10,
		"upgrade_gold_base": 160, "upgrade_shard_base": 16, "dupe_shard": 45, "th_unlock": 3
	},
	"H012": {
		"id": "H012", "name": "Saint of Rust", "rarity": "rare", "class": "cleric",
		"base_power": 34, "power_per_level": 4.4,
		"base_hp": 220, "atk_speed": 1.8, "crit_chance": 0.05,
		"upgrade_gold_base": 160, "upgrade_shard_base": 16, "dupe_shard": 45, "th_unlock": 3
	},
	"H013": {
		"id": "H013", "name": "Ash Paladin", "rarity": "epic", "class": "warrior",
		"base_power": 68, "power_per_level": 7.0,
		"base_hp": 420, "atk_speed": 1.6, "crit_chance": 0.07,
		"upgrade_gold_base": 420, "upgrade_shard_base": 40, "dupe_shard": 120, "th_unlock": 4
	},
	"H014": {
		"id": "H014", "name": "Void Alchemist", "rarity": "epic", "class": "mage",
		"base_power": 62, "power_per_level": 7.8,
		"base_hp": 280, "atk_speed": 2.0, "crit_chance": 0.12,
		"upgrade_gold_base": 420, "upgrade_shard_base": 40, "dupe_shard": 120, "th_unlock": 4
	},
	"H015": {
		"id": "H015", "name": "Crowned Lichling", "rarity": "legendary", "class": "mage",
		"base_power": 100, "power_per_level": 10.0,
		"base_hp": 500, "atk_speed": 1.8, "crit_chance": 0.15,
		"upgrade_gold_base": 1000, "upgrade_shard_base": 100, "dupe_shard": 300, "th_unlock": 5
	},
}

const BUILDINGS := {
	"town_hall": {
		"display_name": "Town Hall",
		"build_cost": 0,
		"unlock_th_level": 1,
		"cells_wide": 2,
		"levels": [
			{"cost": 0,    "hero_level_cap": 10, "label": "Lv1"},
			{"cost": 250,  "hero_level_cap": 20, "label": "Lv2"},
			{"cost": 900,  "hero_level_cap": 30, "label": "Lv3"},
			{"cost": 2500, "hero_level_cap": 40, "label": "Lv4"},
			{"cost": 7000, "hero_level_cap": 50, "label": "Lv5"},
		]
	},
	"portal": {
		"display_name": "Portal",
		"build_cost": 0,
		"unlock_th_level": 1,
		"cells_wide": 2,
		"levels": [
			{"cost": 0,    "enemy_tier": 1, "active_slots": 1, "label": "Lv1"},
			{"cost": 300,  "enemy_tier": 2, "active_slots": 1, "label": "Lv2"},
			{"cost": 1000, "enemy_tier": 3, "active_slots": 2, "label": "Lv3"},
			{"cost": 3000, "enemy_tier": 4, "active_slots": 2, "label": "Lv4"},
			{"cost": 8000, "enemy_tier": 5, "active_slots": 3, "label": "Lv5"},
		]
	},
	"shrine": {
		"display_name": "Shrine",
		"build_cost": 0,
		"unlock_th_level": 2,
		"cells_wide": 1,
		"levels": [
			{
				"cost": 0,    "roll_gold": 100, "roll_shard": 10,
				"weights": {"common": 78, "uncommon": 20, "rare": 2, "epic": 0, "legendary": 0},
				"label": "Lv1"
			},
			{
				"cost": 500,  "roll_gold": 200, "roll_shard": 20,
				"weights": {"common": 68, "uncommon": 27, "rare": 5, "epic": 0, "legendary": 0},
				"label": "Lv2"
			},
			{
				"cost": 1500, "roll_gold": 400, "roll_shard": 40,
				"weights": {"common": 58, "uncommon": 32, "rare": 9, "epic": 1, "legendary": 0},
				"label": "Lv3"
			},
			{
				"cost": 4500, "roll_gold": 800, "roll_shard": 80,
				"weights": {"common": 48, "uncommon": 36, "rare": 13, "epic": 3, "legendary": 0},
				"label": "Lv4"
			},
			{
				"cost": 12000, "roll_gold": 1500, "roll_shard": 150,
				"weights": {"common": 38, "uncommon": 40, "rare": 16, "epic": 5, "legendary": 1},
				"label": "Lv5"
			},
		]
	},
	"tavern": {
		"display_name": "Tavern",
		"build_cost": 700,
		"unlock_th_level": 3,
		"cells_wide": 2,
		"levels": [
			{"cost": 0,    "visitor_interval": 180, "label": "Lv1"},
			{"cost": 1800, "visitor_interval": 150, "label": "Lv2"},
			{"cost": 4000, "visitor_interval": 120, "label": "Lv3"},
		]
	},
	"blacksmith": {
		"display_name": "Blacksmith",
		"build_cost": 600,
		"unlock_th_level": 3,
		"cells_wide": 1,
		"levels": [
			{"cost": 0,    "power_bonus_pct": 5,  "label": "Lv1"},
			{"cost": 1600, "power_bonus_pct": 10, "label": "Lv2"},
			{"cost": 4200, "power_bonus_pct": 18, "label": "Lv3"},
		]
	},
}
