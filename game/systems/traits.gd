class_name Traits
extends RefCounted
## Hero traits: what each id does to a bout's combat mods, the series afterglow and story ripening.
## Each TraitDef carries one number (`value`); the id gives it its meaning. Pure.

const SHOWMAN := &"showman"  ## skill excitement x value, per showman in the lineup
const BRAWLER := &"brawler"  ## that hero's damage x value
const CROWD_PLEASER := &"crowd_pleaser"  ## series-end afterglow x value when in the lineup
const GRUDGE_HOLDER := &"grudge_holder"  ## stories involving the hero ripen x value
const UNDERDOG := &"underdog"  ## start excitement + value when an opponent has a higher level


static func def(catalog: Catalog, id: StringName) -> TraitDef:
	for d in catalog.traits:
		if d.id == id:
			return d
	return null


static func of_hero(catalog: Catalog, hero_id: int) -> Array[TraitDef]:
	var result: Array[TraitDef] = []
	for id in catalog.heroes[hero_id].trait_ids:
		var d := def(catalog, id)
		if d != null:
			result.append(d)
	return result


## Adds the lineup's trait effects to `mods` (CombatSim's dictionary); keys stay absent while neutral.
static func combat_mods(state: GameState, catalog: Catalog, lineup: Array[int], mods := {}) -> Dictionary:
	for id in lineup:
		for d in of_hero(catalog, id):
			match d.id:
				SHOWMAN:
					mods.skill_excitement_mult = float(mods.get("skill_excitement_mult", 1.0)) * d.value
				BRAWLER:
					var damage: Dictionary = mods.get("damage_mult", {})
					damage[id] = float(damage.get(id, 1.0)) * d.value
					mods.damage_mult = damage
				UNDERDOG:
					if lineup.any(func(other: int) -> bool: return state.heroes[other].level > state.heroes[id].level):
						mods.start_excitement = float(mods.get("start_excitement", 0.0)) + d.value
	return mods


## Multiplier on the afterglow when a series ends (crowd pleasers count once).
static func afterglow_mult(catalog: Catalog, lineup: Array[int]) -> float:
	return _best(catalog, lineup, CROWD_PLEASER)


## Multiplier on a story's ripening: grudge holders among `heroes` count once.
static func ripen_mult(catalog: Catalog, heroes: Array) -> float:
	return _best(catalog, heroes, GRUDGE_HOLDER)


static func _best(catalog: Catalog, heroes: Array, trait_id: StringName) -> float:
	for id: int in heroes:
		for d in of_hero(catalog, id):
			if d.id == trait_id:
				return d.value
	return 1.0
