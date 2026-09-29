extends SceneTree
## Regenerates resources/ui/icons/*.png (32x32, Tiny Swords palette + dark outline).
## godot --headless --path . --script res://docs/ui_tools/make_icons.gd  then  --import
## Also writes a 4x contact sheet to .godot/captures/icons_sheet.png for eyeballing.

const Px := preload("res://docs/ui_tools/px.gd")
const OUT := "res://resources/ui/icons/"
const OL := Color("161c2e")
const GOLD_HI := Color("fff2a0")
const GOLD := Color("e5c954")
const GOLD_DK := Color("cea554")
const GOLD_DK2 := Color("bf955a")
const CREAM := Color("eee1c6")
const CREAM_DK := Color("d6c3a4")
const SLATE := Color("525b66")
const SLATE_DK := Color("3b4459")
const RED := Color("fa5f5f")
const RED_DK := Color("ab4553")
const ORANGE := Color("ff8a3c")
const BLUE := Color("4697ac")
const BLUE_HI := Color("98bec3")
const GREEN := Color("6fd24b")
const GREEN_DK := Color("3f9c3e")
const SKIN := Color("f1c6a0")
const BROWN := Color("866353")

var sheet: Array[Image] = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	save("star", star(true))
	save("star_empty", star(false))
	save("star_half", star(false, true))
	save("flame", flame())
	save("crowd", crowd())
	save("trophy", trophy())
	save("lock", lock())
	save("play", play())
	save("pause", pause())
	save("laurel", laurel())
	save("fireworks", fireworks())
	save("megaphone", megaphone())
	save("spotlight", spotlight())
	save("drink", drink())
	save("poster", poster())
	save("scroll", scroll())
	save("calm", calm())
	save("burst", burst())
	var s := Image.create(sheet.size() * 36 * 4, 36 * 4, false, Image.FORMAT_RGBA8)
	s.fill(Color("525b66"))
	for i in sheet.size():
		var big := sheet[i].duplicate() as Image
		big.resize(128, 128, Image.INTERPOLATE_NEAREST)
		s.blend_rect(big, Rect2i(0, 0, 128, 128), Vector2i(i * 144 + 8, 8))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/captures"))
	s.save_png("res://.godot/captures/icons_sheet.png")
	quit()


func save(id: String, img: Image) -> void:
	img.save_png(OUT + id + ".png")
	sheet.append(img)


func canvas() -> Px.Canvas:
	return Px.Canvas.new(32, 32)


func fin(c: Px.Canvas) -> Image:
	return c.finish(OL, 1.25)


func star_pts(cx: float, cy: float, big: float, small: float) -> Array:
	var p := []
	for i in 10:
		var a := deg_to_rad(-90 + i * 36)
		var r := big if i % 2 == 0 else small
		p.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return p


func star(filled: bool, half := false) -> Image:
	var c := canvas()
	var pts := star_pts(16, 17, 14.5, 6.2)
	if filled:
		c.poly(pts, GOLD)
		c.rect(16, 0, 16, 32, GOLD_DK, true)
		c.ellipse(11.5, 11.5, 2.6, 1.4, GOLD_HI, true)
	else:
		c.poly(pts, Color("5b6478"))
		c.rect(16, 0, 16, 32, Color("485064"), true)
		if half:
			c.rect(0, 0, 16, 32, GOLD, true)
			c.ellipse(11.5, 11.5, 2.6, 1.4, GOLD_HI, true)
	return fin(c)


func flame() -> Image:
	var c := canvas()
	c.circle(16, 20, 9.5, Color("f0563a"))
	c.poly([Vector2(16, 1.5), Vector2(7.5, 18), Vector2(24.5, 18)], Color("f0563a"))
	c.poly([Vector2(8, 10), Vector2(12.5, 5.5), Vector2(13, 15)], Color("f0563a"))
	c.poly([Vector2(24, 12), Vector2(21, 7), Vector2(19.5, 14)], Color("f0563a"))
	c.circle(16, 22, 6.5, ORANGE, true)
	c.poly([Vector2(16, 9), Vector2(10.5, 21), Vector2(21.5, 21)], ORANGE, true)
	c.circle(16, 24, 3.8, Color("ffe066"), true)
	c.poly([Vector2(16, 16), Vector2(12.5, 25), Vector2(19.5, 25)], Color("ffe066"), true)
	return fin(c)


func crowd() -> Image:
	var c := canvas()
	c.circle(8.5, 12.5, 3.6, SKIN)
	c.rrect(2.5, 17.5, 12, 12, 5, BLUE)
	c.circle(23.5, 12.5, 3.6, SKIN)
	c.rrect(17.5, 17.5, 12, 12, 5, RED)
	c.circle(16, 10.5, 4.3, SKIN)
	c.rrect(9.5, 16, 13, 14, 5.5, GOLD)
	c.rect(16, 16, 8, 14, GOLD_DK, true)
	return fin(c)


func trophy() -> Image:
	var c := canvas()
	c.arc(8, 9.5, 2.6, 4.8, 90, 270, GOLD_DK)
	c.arc(24, 9.5, 2.6, 4.8, -90, 90, GOLD_DK)
	c.poly([Vector2(8.5, 3), Vector2(23.5, 3), Vector2(21.5, 15), Vector2(18.5, 19.5), Vector2(13.5, 19.5), Vector2(10.5, 15)], GOLD)
	c.rect(16, 0, 10, 24, GOLD_DK, true)
	c.rect(11, 4.5, 2.2, 8, GOLD_HI, true)
	c.rect(14.2, 19, 3.6, 5, GOLD_DK2)
	c.rrect(8.5, 23, 15, 6, 1.8, GOLD_DK)
	c.rect(8.5, 23, 15, 2.2, GOLD, true)
	return fin(c)


func lock() -> Image:
	var c := canvas()
	c.arc(16, 11, 4.2, 7.6, 180, 360, BLUE_HI)
	c.rect(8.4, 11, 3.4, 5, BLUE_HI)
	c.rect(20.2, 11, 3.4, 5, BLUE_HI)
	c.rrect(6, 14, 20, 15, 3, GOLD)
	c.rect(6, 22.5, 20, 7, GOLD_DK, true)
	c.rect(8, 15.5, 16, 2, GOLD_HI, true)
	c.circle(16, 21, 2.4, OL)
	c.rect(15, 21, 2, 5, OL)
	return fin(c)


func play() -> Image:
	var c := canvas()
	c.poly([Vector2(8, 4), Vector2(8, 28), Vector2(28, 16)], GREEN)
	c.poly([Vector2(8, 16), Vector2(8, 28), Vector2(28, 16)], GREEN_DK, true)
	c.rect(9.5, 6, 2, 9, Color("b6f28c"), true)
	return fin(c)


func pause() -> Image:
	var c := canvas()
	for x in [6.5, 18.5]:
		c.rrect(x, 4.5, 7, 23, 2, BLUE)
		c.rect(x + 4.5, 4.5, 3, 23, Color("35768a"), true)
		c.rect(x + 1, 6.5, 1.6, 16, Color("daf3ee"), true)
	return fin(c)


func leaf(cx: float, cy: float, length: float, width: float, ang: float) -> Array:
	var p := []
	for i in 12:
		var t := i / 12.0 * TAU
		var v := Vector2(cos(t) * length / 2, sin(t) * width / 2).rotated(ang)
		p.append(Vector2(cx, cy) + v)
	return p


func laurel() -> Image:
	var c := canvas()
	for side in [-1, 1]:
		c.arc(16 + side * 0.0, 16, 10.2, 11.6, 100 if side < 0 else -50, 260 if side < 0 else 80, BROWN)
		for i in 6:
			var a := deg_to_rad(112 + i * 26) if side < 0 else deg_to_rad(68 - i * 26)
			var base := Vector2(16, 16) + Vector2(cos(a), sin(a)) * 11.0
			# leaves alternate outside / inside of the branch
			for out: int in [1, -1]:
				var dir := Vector2(cos(a), sin(a)) * out * 3.2
				var tang := a + (PI / 2 if side < 0 else -PI / 2)
				var ctr := base + dir
				c.poly(leaf(ctr.x, ctr.y, 8.0, 3.8, tang + out * 0.7 * side), GREEN)
				c.poly(leaf(ctr.x + 0.6, ctr.y + 0.9, 5.0, 1.8, tang + out * 0.7 * side), GREEN_DK, true)
	c.circle(16, 27.5, 2.4, GOLD)
	c.circle(16, 15, 5, GOLD)
	c.poly(star_pts(16, 15.4, 4.2, 1.9), GOLD_HI, true)
	return fin(c)


func fireworks() -> Image:
	var c := canvas()
	var cols := [RED, GOLD, BLUE_HI, ORANGE]
	for i in 8:
		var a := deg_to_rad(i * 45.0 + 22.5)
		var d := Vector2(cos(a), sin(a))
		var col: Color = cols[i % 4]
		c.line(Vector2(16, 14) + d * 4.5, Vector2(16, 14) + d * 10.5, 2.6, col)
		c.circle(16 + d.x * 12.2, 14 + d.y * 12.2, 1.9, col)
	c.circle(16, 14, 3.4, GOLD_HI)
	c.rect(15, 24, 2, 6, BROWN)
	return fin(c)


func megaphone() -> Image:
	var c := canvas()
	c.rrect(7, 19, 5, 9, 1.8, BROWN)
	c.poly([Vector2(3, 12), Vector2(3, 20), Vector2(17, 27), Vector2(17, 5)], RED)
	c.poly([Vector2(3, 17), Vector2(3, 20), Vector2(17, 27), Vector2(17, 16)], RED_DK, true)
	c.rect(3.5, 13, 5, 1.6, Color("ffb0a0"), true)
	c.ellipse(17, 16, 3, 11, CREAM)
	c.ellipse(17.6, 16, 1.6, 8.6, RED_DK)
	c.arc(19, 16, 7.2, 9, -38, 38, GOLD)
	c.arc(19, 16, 11.4, 13.2, -32, 32, GOLD)
	return fin(c)


func spotlight() -> Image:
	var c := canvas()
	c.poly([Vector2(11, 11), Vector2(21, 11), Vector2(30, 30), Vector2(2, 30)], Color("fff3a8"))
	c.poly([Vector2(14, 11), Vector2(18, 11), Vector2(20, 30), Vector2(12, 30)], Color("fffbd2"), true)
	c.rrect(8.5, 1.5, 15, 9, 2.4, SLATE)
	c.rect(8.5, 6, 15, 5, SLATE_DK, true)
	c.ellipse(16, 10.5, 6, 2, GOLD_HI)
	c.rect(14, 0.5, 4, 2, SLATE_DK)
	return fin(c)


func drink() -> Image:
	var c := canvas()
	c.arc(22.5, 19, 3.4, 6, -90, 90, CREAM_DK)
	c.rrect(5, 10, 17, 19, 3, Color("f0a83c"))
	c.rect(15, 10, 8, 19, Color("d08a2a"), true)
	c.rect(8, 13, 2.2, 13, Color("ffd27a"), true)
	c.circle(9, 10, 3.8, CREAM)
	c.circle(13.5, 8, 4.4, CREAM)
	c.circle(18, 10, 3.8, CREAM)
	c.rect(5, 9, 17, 3, CREAM, true)
	c.circle(18, 10, 3.8, CREAM_DK, true)
	c.circle(13.5, 8, 4.4, CREAM)
	return fin(c)


func poster() -> Image:
	var c := canvas()
	c.rrect(5.5, 2.5, 21, 27, 1.8, CREAM)
	c.rect(5.5, 24, 21, 6, CREAM_DK, true)
	c.rect(9, 7, 14, 6, RED)
	c.rect(9, 7, 14, 2, Color("ff9a8a"), true)
	c.rect(9, 16, 14, 1.8, SLATE)
	c.rect(9, 20, 14, 1.8, SLATE)
	c.rect(9, 24, 8, 1.8, SLATE)
	c.circle(16, 4.6, 1.8, RED_DK)
	return fin(c)


func scroll() -> Image:
	var c := canvas()
	c.rect(7, 6, 18, 20, CREAM)
	c.rect(7, 6, 18, 5, CREAM_DK, true)
	c.rrect(3.5, 3, 25, 6, 3, GOLD_DK2)
	c.rrect(3.5, 23, 25, 6, 3, GOLD_DK2)
	c.rect(5, 4, 22, 1.6, GOLD_DK, true)
	c.rect(10, 13, 12, 1.6, SLATE)
	c.rect(10, 17, 12, 1.6, SLATE)
	c.rect(10, 21, 7, 1.6, SLATE)
	return fin(c)


func calm() -> Image:
	var c := canvas()
	c.circle(16, 16, 13, GOLD)
	c.circle(16, 16, 13, GOLD_DK, true)
	c.circle(15, 14.5, 12, GOLD, true)
	c.circle(11.2, 13.5, 1.9, OL)
	c.circle(20.8, 13.5, 1.9, OL)
	c.rrect(11, 20.4, 10, 2, 1, OL)
	return fin(c)


func burst() -> Image:
	var c := canvas()
	var p := []
	for i in 20:
		var a := deg_to_rad(-90 + i * 18)
		var r := 14.6 if i % 2 == 0 else 8.4
		p.append(Vector2(16 + cos(a) * r, 16 + sin(a) * r))
	c.poly(p, RED)
	var q := []
	for i in 20:
		var a := deg_to_rad(-90 + i * 18)
		var r := 9.6 if i % 2 == 0 else 5.6
		q.append(Vector2(16 + cos(a) * r, 16 + sin(a) * r))
	c.poly(q, GOLD)
	c.circle(16, 16, 3.6, GOLD_HI)
	return fin(c)
