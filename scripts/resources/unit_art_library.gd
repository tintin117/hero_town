class_name UnitArtLibrary
extends Resource
## Shared animation sets. Edit each SpriteFrames resource in Godot's animation panel.

@export var blue: Dictionary[String, SpriteFrames] = {}
@export var red: Dictionary[String, SpriteFrames] = {}

func frames(unit_key: String, hostile: bool = false) -> SpriteFrames:
	var faction := red if hostile else blue
	return faction.get(unit_key, faction.get("warrior"))
