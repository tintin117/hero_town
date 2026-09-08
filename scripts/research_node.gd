@tool
extends Button

## Small code-drawn pixel glyphs stay sharp at any UI scale; no bitmap mockup dependency.
var glyph: String = "hp"
var rank_label: String = "I"
var tint := Color("60e4e8")
var locked: bool = false

const GLYPHS := {
	"hp": ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000", "00000000"],
	"def": ["11111111", "11000011", "11000011", "11000011", "01100110", "01100110", "00111100", "00011000"],
	"atk": ["00000011", "00000111", "00001110", "01011100", "00111000", "01110000", "11001000", "10000000"],
	"haste": ["00011111", "00111110", "01111100", "00011000", "00111110", "00011100", "00110000", "01100000"],
	"skill": ["00011000", "00011000", "01111110", "11111111", "00111100", "01100110", "01000010", "00000000"],
	"building": ["10100101", "11100111", "11111111", "10111101", "11111111", "11100111", "11100111", "11100111"],
	"lock": ["00111100", "01100110", "01100110", "11111111", "11100111", "11100111", "11111111", "00000000"],
}

func _draw() -> void:
	var edge := tint if not locked else Color("716b63")
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(rect, edge, false, 1.0)
	var pixels: Array = GLYPHS.get(glyph, GLYPHS.hp)
	var ink := Color("f1ead9") if not locked else Color("868179")
	var origin := Vector2(floorf((size.x - 24.0) / 2.0), 9)
	for y in pixels.size():
		for x in pixels[y].length():
			if pixels[y][x] == "1":
				draw_rect(Rect2(origin + Vector2(x, y) * 3.0, Vector2(3, 3)), ink)
	var font := get_theme_font("font")
	draw_string(font, Vector2(size.x - 18, size.y - 5), rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	if locked:
		draw_rect(Rect2(size.x - 9, 5, 4, 4), Color("b1a695"))
