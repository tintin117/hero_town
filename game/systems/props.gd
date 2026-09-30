class_name Props
extends RefCounted
## Consumable arena props. Each PropDef carries one number (`value`); the id gives it its meaning. Pure.

const FIREWORKS := &"fireworks"  ## + value start excitement every bout
const ANNOUNCER := &"announcer"  ## skill excitement x value (stacks with showmen)
const SPOTLIGHTS := &"spotlights"  ## series-end afterglow x value
const RINGSIDE_BAR := &"ringside_bar"  ## + value gold per attendee each bout


static func def(catalog: Catalog, id: StringName) -> PropDef:
	for d in catalog.props:
		if d.id == id:
			return d
	return null


static func owned(state: GameState, id: StringName) -> int:
	return int(state.props.get(String(id), 0))


## Base price scales with the arena's seats.
static func price(d: PropDef, seats: int, t: Tuning) -> int:
	return roundi(float(d.base_price * seats) / t.prop_price_seats)


## Adds the prop's effect to a bout's combat mods (a null prop changes nothing).
static func apply(d: PropDef, mods: Dictionary) -> void:
	if d == null:
		return
	match d.id:
		FIREWORKS:
			mods.start_excitement = float(mods.get("start_excitement", 0.0)) + d.value
		ANNOUNCER:
			mods.skill_excitement_mult = float(mods.get("skill_excitement_mult", 1.0)) * d.value


static func afterglow_mult(d: PropDef) -> float:
	return d.value if d != null and d.id == SPOTLIGHTS else 1.0


static func concession_bonus(d: PropDef) -> float:
	return d.value if d != null and d.id == RINGSIDE_BAR else 0.0
