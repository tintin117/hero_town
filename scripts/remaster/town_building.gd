class_name ArmyBuildingView
extends Node2D

var record: Dictionary
var sprite: Sprite2D
var selected: bool = false
var ghost: bool = false
var valid: bool = true
var shown_rarity: int = -1

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = GameData.BUILDINGS[record.type].sprite_texture
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height())
	sprite.scale = Vector2.ONE * 0.31
	add_child(sprite)
	refresh()
	sprite.scale *= 0.72
	create_tween().tween_property(sprite, "scale", Vector2.ONE * 0.31, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func refresh() -> void:
	var tier := TownRules.rarity(record)
	if shown_rarity >= 0 and tier > shown_rarity and is_instance_valid(sprite):
		sprite.modulate = Color("ffe3a5")
		create_tween().tween_property(sprite,"modulate",Color.WHITE,0.7)
	shown_rarity = tier
	position = TownRules.cell_position(Vector2i(record.cell[0], record.cell[1]))
	z_index = int(position.y) + 190
	queue_redraw()

func hit_test(point: Vector2) -> bool:
	return Rect2(position + Vector2(-32, -70), Vector2(64, 86)).has_point(point)

func _draw() -> void:
	if record.is_empty(): return
	var data: BuildingData = GameData.BUILDINGS[record.type]
	if ghost:
		draw_rect(Rect2(-30, -24, 60, 50), Color(0.45, 0.9, 0.6, 0.45) if valid else Color(1, 0.4, 0.3, 0.45))
		return
	var color: Color = TownRules.RARITY_COLORS[TownRules.rarity(record)]
	var specialization: String = record.get("specialization","balanced")
	if specialization != "balanced":
		var banner := Color("78c8eb") if specialization == "bulwark" else Color("edaa68")
		draw_line(Vector2(-24,-54),Vector2(-24,-26),Color("dfd4b8"),2)
		draw_colored_polygon(PackedVector2Array([Vector2(-24,-54),Vector2(-8,-54),Vector2(-12,-43),Vector2(-24,-43)]),banner)
	for tier in TownRules.rarity(record): draw_circle(Vector2(-18 + tier * 9,-8),2,color)
	draw_rect(Rect2(-29, 4, 58, 18), Color("293a3d"))
	draw_rect(Rect2(-29, 4, 58, 18), Color("fff0b4") if selected else color, false, 1.5)
	var font: Font = preload("res://fonts/PeaberryBase.ttf")
	var short_id: String = record.id.trim_prefix("army_").trim_prefix("0").trim_prefix("0")
	draw_string(font, Vector2(-24, 17), "#%s  %d/6" % [short_id, TownRules.crew(record, data)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
