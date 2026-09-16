class_name ArmyBuildingView
extends Node2D

## Empty uses the selected BuildingData texture.
@export var texture_override: Texture2D
## Keep the same feet position when BuildingData uses a different texture height.
@export var ground_anchor := true
@export var hit_rect := Rect2(-32, -70, 64, 86)
@export_range(0.0, 2.0, 0.01) var spawn_seconds := 0.3
@export_range(0.0, 1.0, 0.01) var spawn_scale_ratio := 0.72
@export var rarity_flash_color := Color("ffe3a5")
@export var rarity_flash_seconds := 0.7
@export var label_font: Font = preload("res://fonts/PeaberryBase.ttf")

var record: Dictionary
@onready var sprite: Sprite2D = $Sprite
var selected: bool = false
var ghost: bool = false
var valid: bool = true
var shown_rarity: int = -1
var _authored_tint := Color.WHITE

func _ready() -> void:
	_authored_tint = sprite.modulate
	if record.is_empty(): return
	var texture := texture_override if texture_override != null else GameData.BUILDINGS[record.type].sprite_texture as Texture2D
	var previous_height := sprite.texture.get_height() if sprite.texture != null else texture.get_height()
	sprite.texture = texture
	if ground_anchor: sprite.offset.y -= (texture.get_height() - previous_height) * 0.5
	refresh()
	if spawn_seconds > 0:
		var authored_scale := sprite.scale
		sprite.scale *= spawn_scale_ratio
		create_tween().tween_property(sprite, "scale", authored_scale, spawn_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func refresh() -> void:
	if record.is_empty(): return
	var tier := TownRules.rarity(record)
	if shown_rarity >= 0 and tier > shown_rarity and is_instance_valid(sprite):
		sprite.modulate = _authored_tint * rarity_flash_color
		create_tween().tween_property(sprite,"modulate",_authored_tint,rarity_flash_seconds)
	shown_rarity = tier
	position = TownRules.cell_position(Vector2i(record.cell[0], record.cell[1]))
	z_index = int(position.y) + 190
	queue_redraw()

func hit_test(point: Vector2) -> bool:
	return hit_rect.has_point(to_local(point))

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
	var short_id: String = record.id.trim_prefix("army_").trim_prefix("0").trim_prefix("0")
	draw_string(label_font, Vector2(-24, 17), "#%s  %d/6" % [short_id, TownRules.crew(record, data)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
