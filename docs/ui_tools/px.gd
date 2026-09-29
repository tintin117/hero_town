extends RefCounted
## Tiny software rasteriser shared by the UI build tools (icons, procedural panels).
## Shapes are drawn 4x supersampled in "unit" (final pixel) coordinates, then box-downscaled.


class Canvas:
	var img: Image
	var k: int

	func _init(w: int, h: int, ss: int = 4) -> void:
		k = ss
		img = Image.create(w * ss, h * ss, false, Image.FORMAT_RGBA8)

	## Fill every supersampled pixel of `box` (unit coords) where `hit(x, y)` (unit coords) is true.
	func _fill(box: Rect2, hit: Callable, c: Color, clip: bool) -> void:
		var x0 := maxi(int(floor(box.position.x * k)), 0)
		var y0 := maxi(int(floor(box.position.y * k)), 0)
		var x1 := mini(int(ceil(box.end.x * k)), img.get_width())
		var y1 := mini(int(ceil(box.end.y * k)), img.get_height())
		for y in range(y0, y1):
			for x in range(x0, x1):
				if not hit.call((x + 0.5) / k, (y + 0.5) / k):
					continue
				var d := img.get_pixel(x, y)
				if clip and d.a < 0.5:
					continue
				img.set_pixel(x, y, c if c.a >= 1.0 or d.a <= 0.0 or c.a == 0.0 else d.blend(c))

	func poly(pts: Array, c: Color, clip := false) -> void:
		var p := PackedVector2Array(pts)
		var r := Rect2(p[0], Vector2.ZERO)
		for v in p:
			r = r.expand(v)
		_fill(r, func(x: float, y: float) -> bool: return Geometry2D.is_point_in_polygon(Vector2(x, y), p), c, clip)

	func rect(x: float, y: float, w: float, h: float, c: Color, clip := false) -> void:
		_fill(Rect2(x, y, w, h), func(_x: float, _y: float) -> bool: return true, c, clip)

	func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, clip := false) -> void:
		_fill(Rect2(cx - rx, cy - ry, rx * 2, ry * 2), func(x: float, y: float) -> bool:
			return pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1.0, c, clip)

	func circle(cx: float, cy: float, r: float, c: Color, clip := false) -> void:
		ellipse(cx, cy, r, r, c, clip)

	func rrect(x: float, y: float, w: float, h: float, r: float, c: Color, clip := false) -> void:
		_fill(Rect2(x, y, w, h), func(px: float, py: float) -> bool:
			var qx := absf(px - x - w / 2) - (w / 2 - r)
			var qy := absf(py - y - h / 2) - (h / 2 - r)
			return Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) <= r, c, clip)

	func line(a: Vector2, b: Vector2, w: float, c: Color, clip := false) -> void:
		var box := Rect2(a, Vector2.ZERO).expand(b).grow(w / 2)
		_fill(box, func(x: float, y: float) -> bool:
			return Geometry2D.get_closest_point_to_segment(Vector2(x, y), a, b).distance_to(Vector2(x, y)) <= w / 2, c, clip)

	## Ring / arc: points between radii r0..r1 whose angle (deg, 0 = right, clockwise) lies in [a0, a1].
	func arc(cx: float, cy: float, r0: float, r1: float, a0: float, a1: float, c: Color, clip := false) -> void:
		_fill(Rect2(cx - r1, cy - r1, r1 * 2, r1 * 2), func(x: float, y: float) -> bool:
			var d := Vector2(x - cx, y - cy)
			var l := d.length()
			if l < r0 or l > r1:
				return false
			var a := fposmod(rad_to_deg(d.angle()) - a0, 360.0)
			return a <= fposmod(a1 - a0, 360.0), c, clip)

	## Adds a dark outline `t` units thick around everything drawn, then downscales to unit size.
	func finish(outline: Color, t: float) -> Image:
		if t > 0.0:
			_outline(outline, int(round(t * k)))
		return Canvas.down(img, k)

	func _outline(oc: Color, r: int) -> void:
		var w := img.get_width()
		var h := img.get_height()
		var solid := PackedByteArray()
		solid.resize(w * h)
		for y in h:
			for x in w:
				solid[y * w + x] = 1 if img.get_pixel(x, y).a > 0.0 else 0
		var cur := solid.duplicate()
		for i in r:  # alternate diamond / square growth -> roughly round outline
			var nxt := cur.duplicate()
			for y in h:
				for x in w:
					if cur[y * w + x] == 1:
						continue
					var hit := (x > 0 and cur[y * w + x - 1] == 1) or (x < w - 1 and cur[y * w + x + 1] == 1) \
						or (y > 0 and cur[(y - 1) * w + x] == 1) or (y < h - 1 and cur[(y + 1) * w + x] == 1)
					if not hit and i % 2 == 0:
						hit = (x > 0 and y > 0 and cur[(y - 1) * w + x - 1] == 1) or (x < w - 1 and y > 0 and cur[(y - 1) * w + x + 1] == 1) \
							or (x > 0 and y < h - 1 and cur[(y + 1) * w + x - 1] == 1) or (x < w - 1 and y < h - 1 and cur[(y + 1) * w + x + 1] == 1)
					if hit:
						nxt[y * w + x] = 1
			cur = nxt
		for y in h:
			for x in w:
				if solid[y * w + x] == 0 and cur[y * w + x] == 1:
					img.set_pixel(x, y, oc)


	## Integer box-filter downscale with premultiplied alpha (crisp, no ringing).
	static func down(src: Image, f: int) -> Image:
		var w := src.get_width() / f
		var h := src.get_height() / f
		var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var n := float(f * f)
		for y in h:
			for x in w:
				var r := 0.0
				var g := 0.0
				var b := 0.0
				var a := 0.0
				for dy in f:
					for dx in f:
						var c := src.get_pixel(x * f + dx, y * f + dy)
						r += c.r * c.a
						g += c.g * c.a
						b += c.b * c.a
						a += c.a
				out.set_pixel(x, y, Color(r / a, g / a, b / a, a / n) if a > 0.0 else Color(0, 0, 0, 0))
		return out


## Stitch the rectangles xs[i] x ys[j] (each [start, end) in source pixels) of `src` into one contiguous image.
static func stitch(src: Image, xs: Array, ys: Array) -> Image:
	var w := 0
	for x in xs:
		w += x[1] - x[0]
	var h := 0
	for y in ys:
		h += y[1] - y[0]
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var oy := 0
	for y in ys:
		var ox := 0
		for x in xs:
			out.blit_rect(src, Rect2i(x[0], y[0], x[1] - x[0], y[1] - y[0]), Vector2i(ox, oy))
			ox += x[1] - x[0]
		oy += y[1] - y[0]
	return out


static func down(src: Image, f: int) -> Image:
	return Canvas.down(src, f)
