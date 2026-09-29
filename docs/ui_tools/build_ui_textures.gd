extends SceneTree
## Derives the UI kit textures from the untouched Tiny Swords pack (stitched, halved with a box filter,
## recoloured) and draws a few procedural ones. Output: game/ui/theme/tex/, resources/ui/avatars/, resources/ui/icons/.
## godot --headless --path . --script res://docs/ui_tools/build_ui_textures.gd   (then --import)

const Px := preload("res://docs/ui_tools/px.gd")
const TS := "res://asset/Tiny Swords (Free Pack)/UI Elements/UI Elements/"
const OUT := "res://game/ui/theme/tex/"
const OL := Color("161c2e")
const GOLD := Color("e5c954")
const CREAM := Color("eee1c6")


func _init() -> void:
	for d in [OUT, "res://resources/ui/avatars/", "res://resources/ui/icons/"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	# --- papers (stitch the 3x3 tiles that the sheet spreads over a 5x5 grid) ---
	var reg := src("Papers/RegularPaper.png")
	save("paper_cream", half(paper9(Px.stitch(reg, [[12, 64], [128, 192], [256, 308]], [[20, 64], [128, 192], [256, 299]]), 16)))
	var spe := src("Papers/SpecialPaper.png")
	save("paper_slate", half(paper9(Px.stitch(spe, [[10, 64], [128, 192], [256, 310]], [[20, 64], [128, 192], [256, 299]]), 44)))
	# --- buttons: same canvas for every state so text does not jump ---
	for pair in [["btn_normal", "Button_Blue_9Slides"], ["btn_hover", "Button_Hover_9Slides"], ["btn_pressed", "Button_Blue_9Slides_Pressed"],
			["btn_disabled", "Button_Disable_9Slides"], ["btn_red", "Button_Red_9Slides"], ["btn_red_pressed", "Button_Red_9Slides_Pressed"]]:
		var b := src("Buttons/" + pair[1] + ".png")
		save(pair[0], half(b.get_region(Rect2i(5, 0, 182, 184))))
	# --- ribbon (blue, first row of SmallRibbons) ---
	var rib := src("Ribbons/SmallRibbons.png")
	var ru := rib.get_region(Rect2i(0, 0, 320, 64)).get_used_rect()
	save("ribbon_blue", half(Px.stitch(rib, [[0, 64], [128, 192], [256, 320]], [[ru.position.y, ru.end.y]])))
	# --- gauge base + fills ---
	var bar := src("Bars/BigBar_Base.png")
	save("gauge_base", half(Px.stitch(bar, [[40, 64], [128, 192], [256, 280]], [[9, 61]])))
	var fill := src("Bars/BigBar_Fill.png").get_region(Rect2i(0, 20, 64, 24))
	save("fill_hype", half(recolor(fill, {"ffa762": Color("ffd58a"), "ff3e3e": Color("ff8a2e"), "b22249": Color("d2541c"), "bf3158": Color("b8451a")})))
	save("fill_excite", half(recolor(fill, {"ffa762": Color("fff0a0"), "ff3e3e": Color("ffc93c"), "b22249": Color("d18b1f"), "bf3158": Color("b8741a")})))
	save("fill_green", half(recolor(fill, {"ffa762": Color("c8f59a"), "ff3e3e": Color("6fd24b"), "b22249": Color("3f9c3e"), "bf3158": Color("357f36")})))
	save("fill_blue", half(recolor(fill, {"ffa762": Color("bfeaff"), "ff3e3e": Color("4fb0f0"), "b22249": Color("2f6fc0"), "bf3158": Color("2a5ca6")})))
	# --- Tiny Swords icons, halved to 32px ---
	for pair in [["coin", 3], ["sword", 5], ["shield", 6], ["hammer", 1], ["gear", 10], ["info", 11], ["close", 9], ["meat", 4]]:
		Px.down(src("Icons/Icon_%02d.png" % pair[1]), 2).save_png("res://resources/ui/icons/%s.png" % pair[0])
	# --- hero avatars 256 -> 64 ---
	for i in range(1, 26):
		Px.down(src("Human Avatars/Avatars_%02d.png" % i), 4).save_png("res://resources/ui/avatars/avatar_%02d.png" % i)
	# --- procedural panels / widgets ---
	save("hud_bar", panel(24, 24, 6, Color("2a3556"), Color("1c2440"), Color("48598a")))
	save("pill", panel(20, 20, 7, Color("34406a"), Color("232c4c"), Color("5c6fa6")))
	save("slot", panel(24, 24, 7, Color("1b2340"), Color("1b2340"), Color("2f3a63")))
	save("chip", panel(16, 16, 5, Color("e2cfae"), Color("cbb48c"), Color("f5e9d0"), Color("8a6f55")))
	save("focus_ring", ring(24, 24, 7))
	save("badge", badge())
	save("knob", knob(GOLD.lightened(0.0), CREAM))
	save("knob_hover", knob(Color("fff2a0"), Color("fff8d8")))
	save("check_off", check(false))
	save("check_on", check(true))
	save("switch_off", switch(false))
	save("switch_on", switch(true))
	quit()


func src(rel: String) -> Image:
	return Image.load_from_file(TS + rel)


func save(id: String, img: Image) -> void:
	img.save_png(OUT + id + ".png")


## Rebuilds a clean 9-slice from a stitched 3x3 sheet: corners (m px), 8px edge strips taken from the
## middle of each edge (away from the tile junction marks) and a flat centre.
func paper9(s: Image, m: int) -> Image:
	var w := s.get_width()
	var h := s.get_height()
	var cx := w / 2
	var cy := h / 2
	var o := Image.create(2 * m + 8, 2 * m + 8, false, Image.FORMAT_RGBA8)
	o.fill_rect(Rect2i(m, m, 8, 8), s.get_pixel(cx, cy))
	o.blit_rect(s, Rect2i(0, 0, m, m), Vector2i(0, 0))
	o.blit_rect(s, Rect2i(w - m, 0, m, m), Vector2i(m + 8, 0))
	o.blit_rect(s, Rect2i(0, h - m, m, m), Vector2i(0, m + 8))
	o.blit_rect(s, Rect2i(w - m, h - m, m, m), Vector2i(m + 8, m + 8))
	o.blit_rect(s, Rect2i(cx - 4, 0, 8, m), Vector2i(m, 0))
	o.blit_rect(s, Rect2i(cx - 4, h - m, 8, m), Vector2i(m, m + 8))
	o.blit_rect(s, Rect2i(0, cy - 4, m, 8), Vector2i(0, m))
	o.blit_rect(s, Rect2i(w - m, cy - 4, m, 8), Vector2i(m + 8, m))
	return o


func half(img: Image) -> Image:
	var e := img.get_region(Rect2i(0, 0, img.get_width() & ~1, img.get_height() & ~1))
	return Px.down(e, 2)


func recolor(img: Image, map: Dictionary) -> Image:
	var o := img.duplicate() as Image
	for y in o.get_height():
		for x in o.get_width():
			var k := o.get_pixel(x, y).to_html(false)
			if map.has(k):
				o.set_pixel(x, y, map[k])
	return o


## Rounded 9-slice panel: dark outline, vertical two-tone fill, light top edge.
func panel(w: int, h: int, r: float, top: Color, bottom: Color, hi: Color, outline := OL) -> Image:
	var c := Px.Canvas.new(w, h)
	c.rrect(0, 0, w, h, r, outline)
	var i := Px.Canvas.new(w, h)
	i.rrect(1.2, 1.2, w - 2.4, h - 2.4, r - 1.0, top)
	i.rect(0, h * 0.55, w, h, bottom, true)
	i.rect(0, 0, w, 2.6, hi, true)
	c.img.blend_rect(i.img, Rect2i(0, 0, w * 4, h * 4), Vector2i.ZERO)
	return c.finish(outline, 0.0)


func ring(w: int, h: int, r: float) -> Image:
	var c := Px.Canvas.new(w, h)
	c.rrect(0.5, 0.5, w - 1, h - 1, r, OL)
	c.rrect(1.5, 1.5, w - 3, h - 3, r - 1, GOLD)
	c.rrect(3.0, 3.0, w - 6, h - 6, r - 2.5, Color(0, 0, 0, 0))
	return c.finish(OL, 0.0)


func knob(main: Color, hi: Color) -> Image:
	var c := Px.Canvas.new(20, 20)
	c.circle(10, 10, 9.4, OL)
	c.circle(10, 10, 8, main)
	c.circle(10, 10, 8, main.darkened(0.2), true)
	c.circle(9, 8.5, 6.4, main, true)
	c.ellipse(7.5, 6.5, 3, 1.8, hi, true)
	return c.finish(OL, 0.0)


func check(on: bool) -> Image:
	var c := Px.Canvas.new(20, 20)
	c.rrect(0.5, 0.5, 19, 19, 4, OL)
	c.rrect(1.8, 1.8, 16.4, 16.4, 3, CREAM if not on else Color("f4e9c8"))
	c.rect(1.8, 11, 16.4, 7.2, Color("e0d0ac"), true)
	if on:
		c.line(Vector2(5, 10.5), Vector2(8.6, 14.2), 3.0, Color("3f9c3e"))
		c.line(Vector2(8.6, 14.2), Vector2(15.2, 5.6), 3.0, Color("3f9c3e"))
	return c.finish(OL, 0.0)


func switch(on: bool) -> Image:
	var c := Px.Canvas.new(36, 20)
	c.rrect(0.5, 0.5, 35, 19, 9.5, OL)
	c.rrect(1.8, 1.8, 32.4, 16.4, 8.2, Color("6fd24b") if on else Color("5a6482"))
	c.rrect(1.8, 1.8, 32.4, 8, 6, Color("8fe86a") if on else Color("717c9c"), true)
	var kx := 25.5 if on else 10.5
	c.circle(kx, 10, 7.2, OL)
	c.circle(kx, 10, 5.9, CREAM)
	c.circle(kx, 12, 5.9, Color("e0d0ac"), true)
	return c.finish(OL, 0.0)


## Neutral (grey-white) round marker; the Badge component tints it with self_modulate.
func badge() -> Image:
	var c := Px.Canvas.new(24, 24)
	c.circle(12, 12, 11.6, OL)
	var i := Px.Canvas.new(24, 24)
	i.circle(12, 12, 10.4, Color(0.92, 0.92, 0.94))
	i.rect(0, 13, 24, 11, Color(0.74, 0.74, 0.8), true)
	i.ellipse(8.5, 7.6, 3.6, 2.0, Color.WHITE, true)
	c.img.blend_rect(i.img, Rect2i(0, 0, 96, 96), Vector2i.ZERO)
	return c.finish(OL, 0.0)
