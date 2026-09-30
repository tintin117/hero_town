class_name StoryLook
extends RefCounted
## How a story looks everywhere (seed tray chips, stories drawer, HUD): kind icon, kind name, status text and the
## Main Event payout multiplier. Static helpers only; the story dictionaries come from the game layer.

const ICON_DIR := "res://resources/ui/icons/"
const KIND_ICONS := {&"win_streak": "flame", &"rivalry": "sword", &"grudge": "shield", &"comeback": "star", &"legend": "trophy"}
const KIND_NAMES := {&"win_streak": "Win streak", &"rivalry": "Rivalry", &"grudge": "Grudge", &"comeback": "Comeback", &"legend": "Legend"}


## An icon by file stem in resources/ui/icons/ ("info" when the file does not exist yet).
static func icon_named(stem: StringName) -> Texture2D:
	var path := ICON_DIR + String(stem) + ".png"
	return load(path if ResourceLoader.exists(path) else ICON_DIR + "info.png")


static func kind_icon(kind: StringName) -> Texture2D:
	return icon_named(KIND_ICONS.get(kind, "scroll"))


## Cash-in payout multiplier for a ripeness 0..100: x1 .. x3.
static func multiplier(ripeness: float) -> float:
	return 1.0 + 2.0 * clampf(ripeness, 0.0, 100.0) / 100.0


static func multiplier_text(value: float) -> String:
	return "x%.1f" % value


static func status(story: Dictionary) -> String:
	if story.get("cooling", false):
		return "Overripe - cooling"
	return "Ripe" if story.get("ripe", false) else "Growing"


## Ripe stories first, otherwise the game's order.
static func ripe_first(stories: Array) -> Array:
	var ordered := stories.duplicate()
	var ripe := ordered.filter(func(s: Dictionary) -> bool: return s.get("ripe", false))
	var rest := ordered.filter(func(s: Dictionary) -> bool: return not s.get("ripe", false))
	return ripe + rest


## Tooltip line for a trait: "Showman: Skills add +50% excitement".
static func trait_tip(name: String, description: String) -> String:
	return "%s: %s" % [name, description] if description != "" else name
