extends SceneTree
## godot --headless --path . --script res://game/tests/report_hype_sweep.gd
## Sweeps the manager's "book at hype >= X" threshold and reports gold per second including build time.
## One representative cycle per threshold, through the real Game.advance with a fake simulator:
## starts at afterglow hype (0.3 * 45), waits for the manager to book, plays a 60 s fight (final
## excitement 45 -> x1.25, 2 skills), and counts the payout plus tips. Writes .godot/hype_sweep.json.

const Kit := preload("res://game/tests/core_kit.gd")
const OUT := "res://.godot/hype_sweep.json"
const STEP := 0.01
const FIGHT_SECONDS := 60.0
const FINAL_EXCITEMENT := 45.0


func _init() -> void:
	var coarse := _sweep(50, 95, 5)
	var fine := _sweep(50, 95, 1)
	print("threshold  hype@bell  attendance  build_s  fight_s  gold  gold/s  relative")
	var best := _best(coarse)
	for row: Dictionary in coarse:
		print("%9d  %9.1f  %10d  %7.1f  %7.1f  %4d  %6.3f  %8.3f%s" % [row.threshold, row.hype_at_bell, row.attendance,
				row.build_seconds, row.fight_seconds, row.gold, row.gold_per_second, row.gold_per_second / best.gold_per_second,
				"  <- peak (step 5)" if row == best else ""])
	var fine_best := _best(fine)
	print("peak at step 5: %d (%.4f gold/s); peak at step 1: %d (%.4f gold/s)" % [best.threshold, best.gold_per_second, fine_best.threshold, fine_best.gold_per_second])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fight_seconds": FIGHT_SECONDS, "final_excitement": FINAL_EXCITEMENT,
		"start_hype": Hype.afterglow(FINAL_EXCITEMENT, Kit.tuning()), "coarse": coarse, "fine": fine,
		"peak_step5": best.threshold, "peak_step1": fine_best.threshold}, "\t"))
	file.close()
	quit()


func _sweep(from: int, to: int, step: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for threshold in range(from, to + 1, step):
		rows.append(_cycle(float(threshold)))
	return rows


func _best(rows: Array[Dictionary]) -> Dictionary:
	var best := rows[0]
	for row in rows:
		if row.gold_per_second > best.gold_per_second:
			best = row
	return best


func _cycle(threshold: float) -> Dictionary:
	var fake := Kit.FakeSim.new()
	fake.duration = FIGHT_SECONDS
	fake.excitement = FINAL_EXCITEMENT
	var g := Kit.game(fake)
	g.state.hype = Hype.afterglow(FINAL_EXCITEMENT, g.tuning)
	g.set_manager(true, threshold)
	var elapsed := 0.0
	var build := -1.0
	var hype_at_bell := 0.0
	var attendance := 0
	while g.state.fight_count == 0 and elapsed < 3600.0:
		g.advance(STEP)
		elapsed += STEP
		if build < 0.0 and not g.fight.is_empty():
			build = elapsed
			hype_at_bell = g.state.hype
			attendance = g.fight.attendance
	var row := {"threshold": int(threshold), "hype_at_bell": hype_at_bell, "attendance": attendance,
		"build_seconds": build, "fight_seconds": elapsed - build, "gold": g.state.gold,
		"gold_per_second": g.state.gold / elapsed}
	Kit.dispose(g)
	return row
