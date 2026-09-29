class_name Fame
extends RefCounted
## Fame tiers are 0-based indices into Tuning.fame_tier_points / fame_tier_names.


static func tier(points: int, t: Tuning) -> int:
	var result := 0
	for i in t.fame_tier_points.size():
		if points >= t.fame_tier_points[i]:
			result = i
	return result


## 0..1 toward the next tier; 1.0 at the top tier.
static func progress(points: int, t: Tuning) -> float:
	var current := tier(points, t)
	if current >= t.fame_tier_points.size() - 1:
		return 1.0
	var low := t.fame_tier_points[current]
	return float(points - low) / float(t.fame_tier_points[current + 1] - low)


static func gained(excitement: float, t: Tuning) -> int:
	return t.fame_per_fight + int(excitement / t.fame_excitement_divisor)
