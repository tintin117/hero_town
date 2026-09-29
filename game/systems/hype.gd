class_name Hype
extends RefCounted
## Crowd eagerness, 0..hype_max. Pure functions of Tuning.


## Exact solution of dH/dt = (max - H) / tau, so any step size gives the same curve.
static func grow(hype: float, dt: float, t: Tuning) -> float:
	return t.hype_max - (t.hype_max - hype) * exp(-dt / t.hype_tau)


static func attendance(seats: int, hype: float, t: Tuning) -> int:
	return roundi(seats * (t.attendance_floor + (1.0 - t.attendance_floor) * hype / t.hype_max))


static func afterglow(excitement: float, t: Tuning) -> float:
	return t.afterglow_factor * excitement
