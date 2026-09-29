class_name HeroState
extends Resource
## Mutable progress of one fighter, indexed like Catalog.heroes.

var owned := false
var level := 1
var xp := 0
var wins := 0
var losses := 0
var streak := 0


func to_dict() -> Dictionary:
	return {"owned": owned, "level": level, "xp": xp, "wins": wins, "losses": losses, "streak": streak}


static func from_dict(d: Dictionary) -> HeroState:
	var hero := HeroState.new()
	hero.owned = bool(d.get("owned", false))
	hero.level = int(d.get("level", 1))
	hero.xp = int(d.get("xp", 0))
	hero.wins = int(d.get("wins", 0))
	hero.losses = int(d.get("losses", 0))
	hero.streak = int(d.get("streak", 0))
	return hero
