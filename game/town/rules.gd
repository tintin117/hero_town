class_name TownRules
extends RefCounted

const PREP_SECONDS := 0.0
const RESULT_SECONDS := 0.8
const MAX_CREW := 6
const MAX_ENEMIES := 20
const OFFLINE_CAP := 28800.0
const SAVE_VERSION := 1
const GRID_SIZE := Vector2i(8, 3)
const CELL_SIZE := 64.0
const ORIGIN := Vector2(-544, -64)
const ARMY_TYPES := ["barracks", "mage_tower", "cleric_hall", "rogue_den"]
const CLASS_NAMES := ["Warrior", "Lancer", "Ranger", "Cleric"]
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color("dfd4b8"), Color("99d677"), Color("72c9f4"), Color("c49bed"), Color("ffd578")]
const TRAINING := ["damage", "health", "haste", "specialty"]

static func cell_position(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL_SIZE

static func world_cell(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - ORIGIN) / CELL_SIZE + Vector2(0.5, 0.5)).floor())

static func cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y and cell != Vector2i(0, 1)

static func capacity(cleared: int) -> int:
	if cleared >= 15: return 8
	if cleared >= 10: return 6
	if cleared >= 5: return 4
	return 3

static func normal_stage(stage: int) -> int:
	var result := clampi(stage, 1, 19)
	if result % 5 == 0: result -= 1
	return result

static func training_rank(record: Dictionary, branch: String) -> int:
	var result := 0
	for key: String in record.get("research", {}):
		if key.begins_with(branch + "_"):
			result += 1
	return result

static func crew(record: Dictionary, data: BuildingData) -> int:
	return mini(MAX_CREW, data.starting_crew + training_rank(record, "crew"))

static func rarity(record: Dictionary) -> int:
	return mini(4, training_rank(record, "rarity"))

static func stats(hero: HeroData, record: Dictionary) -> Dictionary:
	var specialization: String = record.get("specialization", "balanced") if record.type == "barracks" else "balanced"
	return {
		"guard_strength": 0.40 if specialization == "bulwark" else (0.15 if specialization == "vanguard" else 0.25),
		"hp": (1.30 if specialization == "bulwark" else (0.90 if specialization == "vanguard" else 1.0)) * hero.base_hp * (1.0 + 0.2 * training_rank(record, "health")),
		"damage": (1.30 if specialization == "vanguard" else (0.90 if specialization == "bulwark" else 1.0)) * hero.base_power * (1.0 + 0.2 * training_rank(record, "damage")),
		"interval": hero.atk_speed / (1.0 + 0.15 * training_rank(record, "haste")),
		"specialty": 1.0 + 0.25 * training_rank(record, "specialty"),
	}
