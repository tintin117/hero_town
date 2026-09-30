extends SceneTree
## Pacing report: a deterministic bot (sim_bot.gd, policy documented there) plays the real Game + CombatSim.
##   godot --headless --path . --script res://game/tests/report_progression.gd -- --seeds=7,42,123
## Options (after `--`):
##   --seeds=7,42,123   --hours=18 (horizon; a run also stops once every purchase is bought)
##   --sweep=0|1        bell-threshold sweep 50..95 over the first 2 h (default 1, mean over --sweep-seeds, default --seeds)
##   --fight-step=0.5   replay fights in fixed steps instead of one jump per bout (step-size check)
##   --set=hype_tau=40,series_pause=2      tuning overrides (in-process, nothing is written)
##   --price=gym:2=90000   --hero=6=250000  building-level / hero price overrides
##   --effect=restaurant:3=4.0   building-level effect override
##   --skip=gym,props    ablation: categories the bot never buys (recruit hall gym restaurant office seats fighters upgrades props)
## Writes .godot/progression_<seed>.json (+ progression_sweep.json) and prints the summary.

const Bot := preload("res://game/tests/sim_bot.gd")
const HOUR := 3600.0


func _init() -> void:
	var args := _args()
	var seeds: Array[int] = []
	for s: String in String(args.get("seeds", args.get("seed", "7,42,123"))).split(","):
		seeds.append(int(s))
	var hours := float(args.get("hours", "18"))
	var overrides := _overrides(args)
	var skip := {}
	for c: String in String(args.get("skip", "")).split(",", false):
		skip[c] = true
	var fight_step := float(args.get("fight-step", "0"))
	var started := Time.get_ticks_msec()
	var runs: Array[Dictionary] = []
	for seed_value in seeds:
		var t0 := Time.get_ticks_msec()
		var bot := Bot.new(seed_value, 70.0, overrides)
		bot.skip = skip
		bot.fight_step = fight_step
		bot.run(hours * HOUR, skip.is_empty())
		var row := _summarize(bot, seed_value)
		row["wall_seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
		runs.append(row)
		_print_run(row)
		_write("progression_%d.json" % seed_value, row)
		bot.free_all()
	if runs.size() > 1:
		_print_median(runs)
	if int(args.get("sweep", "1")) == 1:
		var sweep_seeds: Array[int] = []
		for s: String in String(args.get("sweep-seeds", "")).split(",", false):
			sweep_seeds.append(int(s))
		var sweep := _sweep(seeds if sweep_seeds.is_empty() else sweep_seeds, overrides)
		_write("progression_sweep.json", sweep)
	print("total wall time: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var i := a.find("=")
			out[a.substr(2, i - 2)] = a.substr(i + 1)
	return out


func _overrides(args: Dictionary) -> Dictionary:
	var o := {"tuning": {}, "building_costs": {}, "building_effects": {}, "hero_prices": {}}
	for kv: String in String(args.get("effect", "")).split(",", false):
		var p := kv.split("=")
		o.building_effects[p[0]] = float(p[1])
	for kv: String in String(args.get("set", "")).split(",", false):
		var p := kv.split("=")
		o.tuning[p[0]] = float(p[1]) if "." in p[1] else int(p[1])
	for kv: String in String(args.get("price", "")).split(",", false):
		var p := kv.split("=")
		o.building_costs[p[0]] = int(p[1])
	for kv: String in String(args.get("hero", "")).split(",", false):
		var p := kv.split("=")
		o.hero_prices[int(p[0])] = int(p[1])
	return o


func _summarize(bot: Object, seed_value: int) -> Dictionary:
	var series: Array[Dictionary] = bot.series_log
	var build := 0.0
	var fight := 0.0
	var bouts := 0
	var per_hour := {}
	var me_hour := {}
	for s in series:
		build += s.bell - s.plant
		fight += s.end - s.bell
		bouts += s.bouts
		var h := str(int(s.end / HOUR))
		per_hour[h] = int(per_hour.get(h, 0)) + 1
		if s.main_event:
			me_hour[h] = int(me_hour.get(h, 0)) + 1
	var n := maxi(series.size(), 1)
	var total: int = bot.total_income()
	var share := {}
	for k: String in bot.income:
		share[k] = float(bot.income[k]) / maxf(total, 1)
	var early := series.filter(func(s: Dictionary) -> bool: return s.end < HOUR)
	var early_gap := 0.0
	if early.size() > 1:
		early_gap = (early[-1].end - early[0].end) / (early.size() - 1)
	var cashed_gaps: Array[float] = []
	var last_me := 0.0
	for s in series:
		if s.main_event:
			cashed_gaps.append(s.end - last_me)
			last_me = s.end
	return {"seed": seed_value, "horizon_reached": bot.t, "all_bought_at": bot.milestones.get("all_purchases", -1.0),
		"milestones": bot.milestones, "purchases": bot.purchases, "series": series.size(), "bouts": bouts,
		"bouts_per_series": float(bouts) / n, "hype_build_s": build / n, "fight_s": fight / n,
		"series_per_hour": per_hour, "main_events_per_hour": me_hour, "early_series_gap_s": early_gap, "main_event_gaps_s": cashed_gaps,
		"income_total": total, "income": bot.income, "income_share": share, "multiplier_bouts": bot.multiplier_bouts,
		"gold_per_hour": {"h1": _window(bot.samples, 0.0, HOUR), "h4": _window(bot.samples, 3.0 * HOUR, 4.0 * HOUR),
			"h10": _window(bot.samples, 9.0 * HOUR, 10.0 * HOUR)},
		"stories_created": bot.g.state.next_story_id, "stories_ripe_events": bot.story_ripe_events,
		"main_events_cashed": bot.main_events_cashed, "cashed_kinds": bot.cashed_kinds, "excitement_hist": bot.excitement_hist, "fame_points": bot.g.state.fame_points,
		"income_by_hour": {"1": _income_at(bot.samples, HOUR), "2": _income_at(bot.samples, 2.0 * HOUR), "4": _income_at(bot.samples, 4.0 * HOUR),
			"6": _income_at(bot.samples, 6.0 * HOUR), "10": _income_at(bot.samples, 10.0 * HOUR), "14": _income_at(bot.samples, 14.0 * HOUR)},
		"gold_check": total - bot.spent - bot.g.state.gold, "samples": bot.samples}


## Income earned between two sample times (per hour), from the 10-minute snapshots.
func _window(samples: Array, from: float, to: float) -> float:
	var a := _income_at(samples, from)
	var b := _income_at(samples, to)
	return (b - a) / maxf(to - from, 1.0) * HOUR if b >= 0.0 else -1.0


func _income_at(samples: Array, at: float) -> float:
	if at <= 0.0:
		return 0.0
	for s: Dictionary in samples:
		if absf(s.t - at) < 1.0:
			return float(s.income)
	return -1.0


func _print_run(r: Dictionary) -> void:
	print("\n=== seed %d: %.0f s wall, simulated %.2f h%s ===" % [r.seed, r.wall_seconds, r.horizon_reached / HOUR,
			" (all purchases at %.2f h)" % (r.all_bought_at / HOUR) if r.all_bought_at >= 0.0 else ""])
	var keys: Array = r.milestones.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return r.milestones[a] < r.milestones[b])
	for k: String in keys:
		print("  %-34s %s" % [k, _fmt(r.milestones[k])])
	print("  series %d (%.1f bouts each), hype build %.0f s + fight %.0f s; early series gap %.0f s" % [r.series,
			r.bouts_per_series, r.hype_build_s, r.fight_s, r.early_series_gap_s])
	print("  series per hour: %s
  main events per hour: %s" % [str(r.series_per_hour), str(r.main_events_per_hour)])
	print("  income by hour: %s
  excitement per bout: %s" % [str(r.income_by_hour), str(r.excitement_hist)])
	print("  gold/hour  h1 %.0f  h4 %.0f  h10 %.0f  (total income %d)" % [r.gold_per_hour.h1, r.gold_per_hour.h4, r.gold_per_hour.h10, r.income_total])
	print("  income share: tickets %.1f%% tips %.1f%% concessions %.1f%% main-event uplift %.1f%%" % [
			r.income_share.tickets * 100.0, r.income_share.tips * 100.0, r.income_share.concessions * 100.0, r.income_share.main_event * 100.0])
	print("  stories created %d, ripe events %d, main events cashed %d %s; multipliers %s; fame %d; gold check %d" % [
			r.stories_created, r.stories_ripe_events, r.main_events_cashed, str(r.cashed_kinds), str(r.multiplier_bouts), r.fame_points, r.gold_check])


func _print_median(runs: Array[Dictionary]) -> void:
	print("\n=== median of %d seeds (n = seeds that reached it) ===" % runs.size())
	var keys := {}
	for r in runs:
		for k: String in r.milestones:
			keys[k] = true
	var rows: Array = []
	for k: String in keys:
		var vals: Array[float] = []
		for r in runs:
			if r.milestones.has(k):
				vals.append(float(r.milestones[k]))
		vals.sort()
		rows.append([k, vals[vals.size() / 2], vals.size()])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for row: Array in rows:
		print("  %-34s %-10s n=%d" % [row[0], _fmt(row[1]), row[2]])
	for field: String in ["series", "bouts_per_series", "hype_build_s", "fight_s", "early_series_gap_s", "income_total"]:
		print("  %-20s %s" % [field, _median_of(runs, field)])
	for h: String in ["h1", "h4", "h10"]:
		print("  gold/hour %-3s       %s" % [h, _median_of(runs, "gold_per_hour", h)])


func _median_of(runs: Array[Dictionary], field: String, sub := "") -> String:
	var vals: Array[float] = []
	for r in runs:
		vals.append(float(r[field][sub] if sub != "" else r[field]))
	vals.sort()
	return "%.1f" % vals[vals.size() / 2]


func _fmt(seconds: float) -> String:
	if seconds < 120.0:
		return "%.0f s" % seconds
	if seconds < 2.0 * HOUR:
		return "%.1f min" % (seconds / 60.0)
	return "%.2f h" % (seconds / HOUR)


## Same bot, bell threshold 50..95, averaged over the seeds: total income per hour over the first 2 h (compounding
## purchases included), plus a frozen variant (no purchases, 2 fighters, 100 seats, 2 h) that isolates the hype curve.
func _sweep(seeds: Array[int], overrides: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	print("\n=== bell threshold sweep (mean of seeds %s, 2 h each) ===" % str(seeds))
	print("  thr   income/h  series/h  build s  fight s | frozen income/h  series/h")
	var best := {"thr": 0, "v": -1.0}
	var best_frozen := {"thr": 0, "v": -1.0}
	for thr in range(50, 96, 5):
		var row := {"threshold": thr, "income_per_hour": 0.0, "series_per_hour": 0.0, "hype_build_s": 0.0, "fight_s": 0.0,
			"frozen_income_per_hour": 0.0, "frozen_series_per_hour": 0.0}
		for seed_value in seeds:
			var live := Bot.new(seed_value, float(thr), overrides)
			live.run(2.0 * HOUR)
			var frozen := Bot.new(seed_value, float(thr), overrides)
			frozen.buy = false
			frozen.run(2.0 * HOUR)
			var s: Dictionary = _summarize(live, seed_value)
			row.income_per_hour += live.total_income() / 2.0 / seeds.size()
			row.series_per_hour += live.series_log.size() / 2.0 / seeds.size()
			row.hype_build_s += s.hype_build_s / seeds.size()
			row.fight_s += s.fight_s / seeds.size()
			row.frozen_income_per_hour += frozen.total_income() / 2.0 / seeds.size()
			row.frozen_series_per_hour += frozen.series_log.size() / 2.0 / seeds.size()
			live.free_all()
			frozen.free_all()
		rows.append(row)
		if row.income_per_hour > best.v:
			best = {"thr": thr, "v": row.income_per_hour}
		if row.frozen_income_per_hour > best_frozen.v:
			best_frozen = {"thr": thr, "v": row.frozen_income_per_hour}
		print("  %3d  %9.0f  %8.1f  %7.0f  %7.0f | %14.0f  %8.1f" % [thr, row.income_per_hour, row.series_per_hour, row.hype_build_s,
				row.fight_s, row.frozen_income_per_hour, row.frozen_series_per_hour])
	print("  peak: live (compounding) %d, frozen curve %d" % [best.thr, best_frozen.thr])
	return {"rows": rows, "peak_live": best.thr, "peak_frozen": best_frozen.thr}


func _write(file_name: String, data: Dictionary) -> void:
	var f := FileAccess.open("res://.godot/" + file_name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
