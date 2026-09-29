class_name HeroPortraits
extends RefCounted
## Shared hero id -> avatar mapping so every screen shows the same face for a hero.

const PATH := "res://resources/ui/avatars/avatar_%02d.png"


static func portrait(hero_id: int) -> Texture2D:
	return load(PATH % (hero_id + 1))
