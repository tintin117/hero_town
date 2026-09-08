@tool
extends Control

signal node_selected(node_data: Dictionary)

const NodeButton = preload("res://scripts/research_node.gd")
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const COLORS := [Color("d6cab1"), Color("a2d076"), Color("6ec6f4"), Color("c38be8"), Color("e8bf63")]
const BAND_HEIGHT := 208.0
const ICON_SIZE := Vector2(46, 46)

@export_enum("Warrior", "Rogue", "Mage", "Cleric") var hero_class: int = 0
var preview_level: int = 1
var selected_key: String = ""
var _buttons: Array[Button] = []
var _lines: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(412, BAND_HEIGHT * 5)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_lines.clear()
	for tier in 5:
		_build_tier(tier)
	queue_redraw()

func _build_tier(tier: int) -> void:
	var top := tier * BAND_HEIGHT
	var color: Color = COLORS[tier]
	var locked := tier >= preview_level
	var center := Vector2(206, top + 36)
	var heading := Label.new()
	heading.text = "Lv %d  /  %s" % [tier + 1, RARITIES[tier]]
	heading.position = Vector2(10, top + 8)
	heading.add_theme_color_override("font_color", color)
	heading.add_theme_font_size_override("font_size", 14)
	add_child(heading)
	var milestone_color := Color("e8bf63") if tier == preview_level else color
	_add_node(center, "building", str(tier + 1), milestone_color, tier > preview_level, {
		"key": "building_%d" % tier, "kind": "building", "tier": tier,
		"title": "Building level %d" % (tier + 1),
		"description": "Unlock %s heroes.\nUpgrade reveals 3 candidates; choose 1." % RARITIES[tier],
	})
	if tier > 0:
		_line(Vector2(206, top - BAND_HEIGHT + 59), center - Vector2(0, 23), color.darkened(0.35))
	var extra := "haste" if hero_class == 1 else "skill"
	var glyphs := ["hp", "def", "atk", extra]
	var names := ["Health", "Defense", "Attack", "Agility" if hero_class == 1 else ("Healing" if hero_class == 3 else "Skill power")]
	for branch in 4:
		var x := 54.0 + branch * 100.0
		var first := Vector2(x, top + 103)
		var second := Vector2(x, top + 169)
		var edge := Color("60e4e8") if not locked else Color("726451")
		_line(center + Vector2(0, 23), first - Vector2(0, 23), edge)
		_line(first + Vector2(0, 23), second - Vector2(0, 23), edge)
		for rank in 2:
			var point := first if rank == 0 else second
			_add_node(point, glyphs[branch], "I" if rank == 0 else "II", edge, locked, {
				"key": "%d_%s_%d" % [tier, glyphs[branch], rank], "kind": "stat",
				"tier": tier, "rank": rank + 1, "stat": glyphs[branch],
				"title": "%s %s %s" % [RARITIES[tier], names[branch], "I" if rank == 0 else "II"],
				"description": "Improves %s for %s heroes.\nRank %d / 2 — values to be configured." % [names[branch].to_lower(), RARITIES[tier].to_lower(), rank + 1],
			})

func _add_node(center: Vector2, glyph: String, rank: String, color: Color, locked: bool, data: Dictionary) -> void:
	var button := NodeButton.new()
	button.position = center - ICON_SIZE / 2
	button.size = ICON_SIZE
	button.glyph = glyph
	button.rank_label = rank
	button.tint = color
	button.locked = locked
	button.toggle_mode = true
	button.button_pressed = selected_key == data.key
	button.tooltip_text = data.title + (" — locked tier" if locked else "")
	button.set_meta("research_data", data)
	button.pressed.connect(func():
		selected_key = data.key
		for other in _buttons:
			other.set_pressed_no_signal(other == button)
		node_selected.emit(data))
	add_child(button)
	_buttons.append(button)

func _line(from: Vector2, to: Vector2, color: Color) -> void:
	_lines.append({"from": from, "to": to, "color": color})

func _draw() -> void:
	for line in _lines:
		draw_line(line.from, line.to, line.color, 1.0, false)
	for tier in range(1, 5):
		draw_line(Vector2(8, tier * BAND_HEIGHT - 2), Vector2(404, tier * BAND_HEIGHT - 2), Color("776047"), 1.0)
