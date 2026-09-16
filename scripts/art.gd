class_name Art

## Animation assets are authored in resources/art/unit_library.tres.
const UNIT_LIBRARY = preload("res://resources/art/unit_library.tres")
const DECOR_ROOT := "res://asset/Tiny Swords (Free Pack)/Terrain/Decorations/"
const ROCKS := [DECOR_ROOT + "Rocks/Rock1.png", DECOR_ROOT + "Rocks/Rock2.png", DECOR_ROOT + "Rocks/Rock3.png", DECOR_ROOT + "Rocks/Rock4.png"]
const CLOUDS := [DECOR_ROOT + "Clouds/Clouds_01.png", DECOR_ROOT + "Clouds/Clouds_03.png", DECOR_ROOT + "Clouds/Clouds_05.png"]

## Hero visual class -> unit. Rogue/Mage don't have direct pack equivalents,
## so Lancer (agile skirmisher) and Archer (ranged) stand in.
const CLASS_UNIT := {
	HeroData.HeroClass.WARRIOR: "warrior",
	HeroData.HeroClass.ROGUE: "lancer",
	HeroData.HeroClass.MAGE: "archer",
	HeroData.HeroClass.CLERIC: "monk",
}

## Enemy tier -> unit (Red faction), reusing the same 4 combat units. Monk (healer)
## is deliberately excluded -- it doesn't read as hostile.
const TIER_UNIT := {
	1: "warrior",
	2: "archer",
	3: "lancer",
	4: "warrior",
	5: "lancer",
}

static func unit_frames(unit_key: String, red: bool = false) -> SpriteFrames:
	return UNIT_LIBRARY.frames(unit_key, red)

static func hero_sprite_frames(hero_class: HeroData.HeroClass) -> SpriteFrames:
	return unit_frames(CLASS_UNIT.get(hero_class, "warrior"))

static func enemy_sprite_frames(tier: int) -> SpriteFrames:
	return unit_frames(TIER_UNIT.get(clampi(tier, 1, 5), "warrior"), true)
