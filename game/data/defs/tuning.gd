class_name Tuning
extends Resource
## Every balance number lives in data/tuning.tres, never in code.

@export_group("Hype")
@export var hype_max := 0.0
@export var hype_start := 0.0
@export var hype_tau := 0.0  ## seconds; dH/dt = (max - H) / tau
@export var attendance_floor := 0.0
@export var afterglow_factor := 0.0  ## hype after a fight = factor * final excitement
@export var hype_emit_interval := 0.0  ## min seconds between Events.hype_changed

@export_group("Arena")
@export var seat_tiers := PackedInt32Array()
@export var seat_costs := PackedInt32Array()  ## cost to reach tier i+1
@export var fighter_tiers := PackedInt32Array()
@export var fighter_costs := PackedInt32Array()
@export var min_lineup := 0
@export var starting_gold := 0

@export_group("Income")
@export var base_income := 0
@export var income_per_level := 0
@export var income_per_win := 0
@export var win_income_cap := 0  ## wins per fighter that still add income
@export var income_reference_attendance := 0  ## attendance at which the locked base is unscaled
@export var excitement_thresholds := PackedFloat64Array()
@export var excitement_multipliers := PackedFloat64Array()
@export var cast_tip := 0

@export_group("Progression")
@export var xp_per_fight := 0
@export var xp_win_bonus := 0
@export var level_cap := 0
@export var xp_base := 0
@export var xp_step := 0
@export var stat_growth := 0.0  ## per level above 1

@export_group("Fame")
@export var fame_tier_points := PackedInt32Array()  ## points needed for tier i (first is 0)
@export var fame_tier_names := PackedStringArray()
@export var fame_per_fight := 0
@export var fame_excitement_divisor := 1.0  ## + int(excitement / divisor) per fight

@export_group("Manager")
@export var manager_threshold := 0.0
