class_name Hype
extends RefCounted
## Crowd eagerness, 0..hype_max. Pure functions of Tuning.


## Exact solution of dH/dt = (max - H) / tau, so any step size gives the same curve.
## `tau_mult` is the Promotion Office's shortening of tau (1.0 without one).
static func grow(hype: float, dt: float, t: Tuning, tau_mult := 1.0) -> float:
	return t.hype_max - (t.hype_max - hype) * exp(-dt / (t.hype_tau * tau_mult))


static func attendance(seats: int, hype: float, t: Tuning) -> int:
	return roundi(seats * (t.attendance_floor + (1.0 - t.attendance_floor) * hype / t.hype_max))


static func afterglow(excitement: float, t: Tuning) -> float:
	return t.afterglow_factor * excitement
