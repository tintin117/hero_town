extends RefCounted
## Hype growth, attendance and afterglow against the closed forms in GAME_DESIGN section 5.

const Kit := preload("res://game/tests/core_kit.gd")


func run() -> Array[String]:
	var p: Array[String] = []
	var t := Kit.tuning()
	Kit.check(p, t.hype_tau == 50.0 and t.attendance_floor == 0.1 and t.afterglow_factor == 0.3, "tuning hype constants")

	# exact integration: matches the closed form for one big step and for many small ones
	var h := t.hype_start
	var prev := h
	for i in 60 * 300:
		h = Hype.grow(h, 1.0 / 60.0, t)
		if h < prev or h > t.hype_max:
			p.append("hype must rise monotonically and stay <= max (step %d)" % i)
			break
		prev = h
	Kit.check(p, Kit.near(h, 100.0 - 85.0 * exp(-300.0 / 50.0), 1e-9), "small steps vs closed form at 300 s")
	Kit.check(p, Kit.near(Hype.grow(15.0, 300.0, t), h, 1e-9), "one 300 s step equals 18000 small steps")
	Kit.check(p, Kit.near(Hype.grow(15.0, 52.0, t), 100.0 - 85.0 * exp(-52.0 / 50.0)), "hype at 52 s")
	Kit.check(p, absf(Hype.grow(15.0, 52.0, t) - 70.0) < 0.1, "GDD: ~70 hype after 52 s from 15")
	Kit.check(p, Hype.grow(15.0, 0.0, t) == 15.0, "dt 0 changes nothing")
	Kit.check(p, Hype.grow(100.0, 10.0, t) == 100.0, "full hype stays full")
	Kit.check(p, Hype.grow(15.0, 2000.0, t) > 99.999, "hype converges to max")

	# attendance = round(seats * (floor + (1 - floor) * h / 100))
	Kit.check(p, Hype.attendance(100, 0.0, t) == 10, "attendance at hype 0")
	Kit.check(p, Hype.attendance(100, 100.0, t) == 100, "attendance at hype 100")
	Kit.check(p, Hype.attendance(100, 50.0, t) == 55, "attendance at hype 50")
	Kit.check(p, Hype.attendance(200, 100.0, t) == 200, "attendance, 200 seats full")
	Kit.check(p, Hype.attendance(150, 13.5, t) == 33, "attendance 150 seats at afterglow hype")
	Kit.check(p, Hype.attendance(100, 70.0, t) == 73, "attendance at hype 70")

	Kit.check(p, Kit.near(Hype.afterglow(45.0, t), 13.5), "afterglow = 0.3 * excitement")
	Kit.check(p, Hype.afterglow(0.0, t) == 0.0, "no excitement, no afterglow")
	return p
