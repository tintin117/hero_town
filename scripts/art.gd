class_name Art

## Every Tiny Swords art path used by the game routes through this file.
## Re-pointing to different sprites/factions later is a one-file edit.

const UNIT_ROOT := "res://asset/Tiny Swords (Free Pack)/Units/"
const BUILDING_ROOT := "res://asset/Tiny Swords (Free Pack)/Buildings/"
const TERRAIN_ROOT := "res://asset/Tiny Swords (Free Pack)/Terrain/"
const DECOR_ROOT := TERRAIN_ROOT + "Decorations/"

enum Faction { BLUE, RED }
const FACTION_FOLDER := {
	Faction.BLUE: "Blue Units",
	Faction.RED: "Red Units",
}

## unit key -> per-animation {file, frames}. "attack" is always the one-shot
## action Character._on_attack_timeout()/_cast_skill() play.
const UNIT_ANIM := {
	"warrior": {
		"idle": {"file": "Warrior/Warrior_Idle.png", "frames": 8},
		"run": {"file": "Warrior/Warrior_Run.png", "frames": 6},
		"attack": {"file": "Warrior/Warrior_Attack1.png", "frames": 4},
	},
	"archer": {
		"idle": {"file": "Archer/Archer_Idle.png", "frames": 6},
		"run": {"file": "Archer/Archer_Run.png", "frames": 4},
		"attack": {"file": "Archer/Archer_Shoot.png", "frames": 8},
	},
	"lancer": {
		"idle": {"file": "Lancer/Lancer_Idle.png", "frames": 12},
		"run": {"file": "Lancer/Lancer_Run.png", "frames": 6},
		# ponytail: Lancer's real animation set is 8-directional (Up/Down/Right +
		# diagonals, Attack+Defence each). We only need left/right facing (flip_h),
		# so a single direction stands in for all facings. Add direction switching
		# later if true 8-way combat art is wanted.
		"attack": {"file": "Lancer/Lancer_Right_Attack.png", "frames": 3},
	},
	"monk": {
		"idle": {"file": "Monk/Idle.png", "frames": 6},
		"run": {"file": "Monk/Run.png", "frames": 4},
		"attack": {"file": "Monk/Heal.png", "frames": 11},
	},
}

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

const BUILDING_TEXTURE := {
	"town_hall": "Blue Buildings/Castle.png",
	"portal": "Red Buildings/Tower.png",
	"shrine": "Blue Buildings/Monastery.png",
	"blacksmith": "Blue Buildings/Barracks.png",
	"tavern": "Blue Buildings/House1.png",
}

## 64x64 crops picked from Tilemap_color1.png that are interior to the big
## grass/stone chunks (verified seamless when tiled -- see git history for the
## swatch check). ponytail: hand-picked repeatable swatches, not a real
## autotiled TileSet -- the pack's tileset is chunk-based (whole platform
## pieces), not per-cell edge/corner bits, so true Godot terrain autotiling
## doesn't apply cleanly here. Upgrade path: hand-author precise edge/corner
## atlas regions if pixel-perfect shorelines matter later.
const TILESET_IMAGE := TERRAIN_ROOT + "Tileset/Tilemap_color1.png"
const GRASS_SWATCH := Rect2(96, 96, 64, 64)
const STONE_SWATCH := Rect2(416, 256, 64, 64)
const WATER_TILE := TERRAIN_ROOT + "Tileset/Water Background color.png"

const ROCKS := [
	DECOR_ROOT + "Rocks/Rock1.png",
	DECOR_ROOT + "Rocks/Rock2.png",
	DECOR_ROOT + "Rocks/Rock3.png",
	DECOR_ROOT + "Rocks/Rock4.png",
]
const CLOUDS := [
	DECOR_ROOT + "Clouds/Clouds_01.png",
	DECOR_ROOT + "Clouds/Clouds_03.png",
	DECOR_ROOT + "Clouds/Clouds_05.png",
]

static func hero_sprite_frames(hero_class: HeroData.HeroClass) -> SpriteFrames:
	return _build_sprite_frames(CLASS_UNIT.get(hero_class, "warrior"), Faction.BLUE)

static func enemy_sprite_frames(tier: int) -> SpriteFrames:
	return _build_sprite_frames(TIER_UNIT.get(clampi(tier, 1, 5), "warrior"), Faction.RED)

static func _build_sprite_frames(unit_key: String, faction: Faction) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var anim_table: Dictionary = UNIT_ANIM[unit_key]
	var faction_folder: String = FACTION_FOLDER[faction]
	var folder: String = UNIT_ROOT + faction_folder + "/"
	for anim_name in anim_table:
		var entry: Dictionary = anim_table[anim_name]
		var tex: Texture2D = load(folder + entry["file"])
		var frame_count: int = entry["frames"]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, anim_name != "attack")
		frames.set_animation_speed(anim_name, 10.0 if anim_name != "attack" else float(frame_count) / 0.4)
		var frame_w := tex.get_width() / frame_count
		var frame_h := tex.get_height()
		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frames.add_frame(anim_name, atlas)
	return frames

static func building_texture(building_id: String) -> Texture2D:
	var rel: String = BUILDING_TEXTURE.get(building_id, "")
	return load(BUILDING_ROOT + rel) if rel != "" else null
