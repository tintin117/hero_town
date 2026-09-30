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

@export_group("Series")
@export var series_wins := 1  ## bo5 = first to 3; tests use 1 for single-fight lifecycles
@export var series_pause := 0.0  ## seconds of crowd chatter between bouts
@export var series_max_bouts := 1  ## draw guard: a series ends unresolved after this many bouts
@export var series_fame_bonus := 0

@export_group("Manager")
@export var manager_threshold := 0.0

@export_group("Buildings")
@export var grid_columns := 0  ## town grid width in cells (the town spans grid_columns x grid_rows)
@export var grid_rows := 0
@export var land_first_col := 0  ## owned land, inclusive columns; buildings go on rows 0..path_row-1
@export var land_last_col := 0
@export var arena_first_col := 0  ## the arena reserves these columns on every row
@export var arena_last_col := 0
@export var path_row := 0  ## public path along the bottom, not buildable
@export var hall_base_capacity := 0  ## owned-hero cap before a Recruitment Hall
@export var gym_xp := 0  ## XP a trainee earns every gym_interval
@export var gym_interval := 1.0  ## seconds


@export_group("Stories")
@export var story_slots_base := 0  ## story slots before any Promotion Office level
@export var story_start := 0.0  ## ripeness of a new story
@export var story_ripe_threshold := 0.0
@export var story_overripe_bouts := 0  ## bouts spent at full ripeness before a story cools
@export var story_cooling := 0.0  ## ripeness lost per bout while cooling
@export var story_time_seconds := 1.0  ## unpaused seconds per +1 ripeness for time-ripening stories
@export var story_streak_len := 0  ## a win streak story starts at this streak
@export var story_streak_step := 0.0  ## per further win
@export var story_rivalry_meetings := 0  ## meetings with a split result that make a rivalry
@export var story_rivalry_step := 0.0  ## per meeting
@export var story_grudge_step := 0.0  ## per rematch loss
@export var story_comeback_losses := 0  ## losses in a row that a win turns into a comeback
@export var story_comeback_step := 0.0  ## per repeated comeback
@export var story_legend_level := 0
@export var story_legend_streak := 0
@export var story_legend_step := 0.0  ## per win of a legend

@export_group("Main event")
@export var main_event_bonus := 0.0  ## payout multiplier is 1 + bonus * ripeness / 100
@export var main_event_fame_divisor := 1.0  ## winner's fame bonus is round(ripeness / divisor)

@export_group("Preview")
@export var preview_width := 0.0  ## half-width of the star range without a Promotion Office
@export var preview_width_step := 0.0  ## narrowed per office level
@export var preview_base_excitement := 0.0  ## excitement from the clock alone
@export var preview_skills_per_fighter := 0.0  ## expected casts per strike/sweep/drain fighter
@export var preview_skill_excitement := 0.0  ## per cast, before multipliers
@export var preview_excitement_per_star := 1.0
@export var preview_level_gap_penalty := 0.0  ## excitement lost per level between strongest and weakest
@export var preview_story_bonus := 0.0  ## excitement when a ripe story matches the lineup

@export_group("Props")
@export var prop_cap := 0  ## most of one prop that can be held
@export var prop_price_seats := 1  ## seats at which base_price applies