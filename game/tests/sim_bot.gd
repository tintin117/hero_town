extends RefCounted
## Deterministic bot player for pacing reports (used by report_progression.gd, not a test).
## It drives the real Game + real CombatSim through PUBLIC commands only. Policy:
##  1. Whenever nothing is planted, pick the strongest lineup up to fighter capacity (level-scaled health*attack),
##     recall trainees who made it, put benched heroes in free gym slots, and plant at once. The bell threshold
##     stays at the manager default unless the sweep overrides it.
##  2. A ripe story is cashed as the Main Event (highest ripeness first; the lineup is topped up to capacity).
##     A story that ripens while hype builds uproots and replants (hype is kept) unless one is already locked.
##  3. Purchases: whenever gold allows, buy the affordable item with the lowest (group, cost). Groups in order:
##     recruits, Recruitment Hall, Gym, Restaurant, Promotion Office, seats, fighter capacity, building upgrades.
##     Props (consumables) are bought only when one costs <= PROP_SHARE of current gold and fewer than PROP_STOCK
##     of that kind are held, least-stocked first; the most-stocked prop is selected for each plant.
##  4. Time: idle waits jump to the exact bell time (hype is closed-form), fights advance to their end
##     (`fight_step` > 0 replays them in fixed steps instead, used to verify the coarse stepping), pauses jump.

const GameScript := preload("res://game/core/game.gd")
const EventsScript := preload("res://game/core/events.gd")
const PROP_SHARE := 0.15
const PROP_STOCK := 2
const IDLE_CHUNK := 5.0  ## idle waits are cut so a story that ripens mid-wait is noticed within this many seconds
const SAMPLE_EVERY := 600.0
const EPS := 1e-6
const CATEGORIES := ["recruit", "hall", "gym", "restaurant", "office", "seats", "fighters", "upgrades", "props"]
const GROUP_OF_BUILDING := {&"recruitment_hall": 1, &"gym": 2, &"restaurant": 3, &"promotion_office": 4}
const PROP_ORDER: Array[StringName] = [&"spotlights", &"fireworks", &"announcer", &"ringside_bar"]

var g: Node
var ev: Node
var t := 0.0
var clock := 0.0  ## time inside the current advance step (signal timestamps)
var buy := true
var skip := {}  ## ablation: purchase categories the bot never buys
var fight_step := 0.0
var milestones := {}
var purchases: Array[Dictionary] = []
var spent := 0
var income := {"tickets": 0, "tips": 0, "concessions": 0, "main_event": 0}
var bouts := 0
var multiplier_bouts := {}  ## excitement multiplier -> bouts
var series_log: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var story_ripe_events := 0
var main_events_cashed := 0
var cashed_kinds := {}
var excitement_hist := {}
var fame_tier := 0
var _cur := {}
var _tried := {}  ## story id -> true: set_main_event failed, do not retry


## `overrides`: {tuning: {name: value}, building_costs: {"gym:2": cost}, hero_prices: {id: price}}.
func _init(rng_seed: int, threshold := 70.0, overrides := {}) -> void:
	g = GameScript.new()
	ev = EventsScript.new()
	g.events = ev
	g.tuning = g.tuning.duplicate()
	g.catalog = g.catalog.duplicate()
	g.catalog.tuning = g.tuning
	g.hero_defs = g.catalog.heroes
	for key: String in overrides.get("tuning", {}):
		g.tuning.set(key, overrides.tuning[key])
	for key: String in overrides.get("building_costs", {}):
		var parts := key.split(":")
		for d in g.catalog.buildings:
			if String(d.id) == parts[0]:
				d.levels[int(parts[1]) - 1].cost = int(overrides.building_costs[key])
	for key: String in overrides.get("building_effects", {}):
		var parts := key.split(":")
		for d in g.catalog.buildings:
			if String(d.id) == parts[0]:
				d.levels[int(parts[1]) - 1].effect = float(overrides.building_effects[key])
	for id in overrides.get("hero_prices", {}):
		g.hero_defs[int(id)].price = int(overrides.hero_prices[id])
	g.autosave = false
	g.save_path = "res://.godot/sim_save.json"
	g.new_game()
	g.state.rng_seed_counter = rng_seed
	g.set_manager(true, threshold)
	ev.series_started.connect(func(_info: Dictionary) -> void:
		_cur["bell"] = clock
		if not milestones.has("first_series_bell"):
			milestones["first_series_bell"] = clock)
	ev.fight_finished.connect(_on_bout)
	ev.series_finished.connect(_on_series)
	ev.story_ripe.connect(func(_id: int) -> void:
		story_ripe_events += 1
		_mark("first_ripe_story", clock))
	ev.fame_changed.connect(func(_points: int, tier: int) -> void:
		if tier > fame_tier:
			fame_tier = tier
			_mark("fame_tier_%d" % (tier + 1), clock))


func free_all() -> void:
	ev.free()
	g.free()


func total_income() -> int:
	return int(income.tickets + income.tips + income.concessions + income.main_event)


## Runs until `horizon` seconds or (when `until_done`) every purchase is bought.
func run(horizon: float, until_done := false) -> void:
	var next_sample := SAMPLE_EVERY
	while t < horizon:
		decide()
		if until_done and _all_bought():
			_mark("all_purchases", t)
			break
		var dt := minf(_next_dt(), minf(horizon - t, next_sample - t))
		dt = maxf(dt, EPS)
		clock = t + dt
		g.advance(dt)
		t += dt
		if t >= next_sample - 1e-9:
			samples.append(snapshot())
			next_sample += SAMPLE_EVERY
	samples.append(snapshot())


func snapshot() -> Dictionary:
	return {"t": t, "income": total_income(), "spent": spent, "gold": g.state.gold, "series": series_log.size(),
		"bouts": bouts, "fame": g.state.fame_points}


# --- time ----------------------------------------------------------------------------------

func _next_dt() -> float:
	if not g.fight.is_empty():
		var left: float = maxf(float(g.fight.duration) - float(g.fight.clock), 0.0) + EPS
		return minf(left, fight_step) if fight_step > 0.0 else left
	if not g.series.is_empty():
		return maxf(float(g.series.pause), 0.0) + EPS
	if g.planted.is_empty():
		return 1.0
	var h: float = g.state.hype
	var thr: float = g.state.manager.threshold
	if h >= thr:
		return EPS
	var tau: float = g.tuning.hype_tau * Buildings.hype_tau_multiplier(g.state, g.catalog)
	var to_bell: float = tau * log((g.tuning.hype_max - h) / (g.tuning.hype_max - thr)) * 1.000001 + 1e-5
	return minf(to_bell, IDLE_CHUNK)


# --- decisions -----------------------------------------------------------------------------

func decide() -> void:
	if buy:
		_buy_loop()
		_train_bench()
	if g.fight.is_empty() and g.series.is_empty():
		if g.planted.is_empty():
			_plant()
		elif g.planted_main_event.is_empty() and _ripe_untried():
			g.uproot()
			_plant()


func _rating(id: int) -> float:
	var s: Dictionary = Roster.stats_for(g.hero_defs[id], g.state.heroes[id].level, g.tuning)
	return float(s.health) * float(s.attack)


func _owned_by_rating() -> Array[int]:
	var ids: Array[int] = []
	for id in g.state.heroes.size():
		if g.state.heroes[id].owned:
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool: return _rating(a) > _rating(b) or (_rating(a) == _rating(b) and a < b))
	return ids


func _lineup_of(head: Array[int]) -> Array[int]:
	var lineup: Array[int] = head.duplicate()
	for id in _owned_by_rating():
		if lineup.size() >= Roster.fighter_capacity(g.state, g.tuning):
			break
		if id not in lineup:
			lineup.append(id)
	return lineup


func _plant() -> void:
	var ripe := _cash_story()
	if not ripe:
		var lineup := _lineup_of([])
		for id in lineup:
			g.recall_training(id)
		g.set_preferred_lineup(lineup)
	var stock := PROP_ORDER.filter(func(p: StringName) -> bool: return g.props_owned(p) > 0)
	if not stock.is_empty():
		stock.sort_custom(func(a: StringName, b: StringName) -> bool: return g.props_owned(a) > g.props_owned(b))
		g.select_prop(stock[0])
	if not g.plant():  # a trainee slipped into the lineup (story heroes): recall and retry once
		for id: int in g.state.preferred_lineup:
			g.recall_training(id)
		g.plant()
	if g.planted.is_empty():
		return
	if not _cur.has("plant"):
		_cur["plant"] = t
	if not g.planted_main_event.is_empty():
		_mark("first_main_event", t)
	_train_bench()


## Sets the highest-ripeness ripe story that fits as the main event and tops up the lineup. True if one was set.
func _cash_story() -> bool:
	var ripe: Array[Dictionary] = []
	for s: Dictionary in g.state.stories:
		if s.ripe and not _tried.has(s.id):
			ripe.append(s)
	ripe.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ripeness > b.ripeness)
	for s in ripe:
		for id: int in s.heroes:
			g.recall_training(id)
		if g.set_main_event(s.id):
			g.set_preferred_lineup(_lineup_of(g.state.preferred_lineup))  # keeps the story heroes, fills the seats
			return true
		_tried[s.id] = true
	return false


func _ripe_untried() -> bool:
	for s: Dictionary in g.state.stories:
		if s.ripe and not _tried.has(s.id):
			return true
	return false


func _train_bench() -> void:
	if g.training_slots() <= 0:
		return
	var lineup: Array[int] = g.planted if not g.planted.is_empty() else _lineup_of([])
	for id in _owned_by_rating():
		if id not in lineup and g.state.training.size() < g.training_slots():
			g.assign_training(id)


# --- purchases -----------------------------------------------------------------------------

## [{group, cost, name, run: Callable}] for everything buyable right now (affordable or not).
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not skip.has("recruit"):
		for id in g.hero_defs.size():
			var d: HeroDef = g.hero_defs[id]
			if not g.state.heroes[id].owned and Roster.owned_count(g.state) < g.hero_capacity():
				out.append({"group": 0, "cost": d.price, "name": "recruit_" + d.display_name.to_lower(),
					"run": g.recruit.bind(id)})
	for d in g.building_defs():
		var lvl: int = g.building_level(d.id)
		var cost: int = g.building_next_cost(d.id)
		if cost < 0:
			continue
		var category: String = {&"recruitment_hall": "hall", &"gym": "gym", &"restaurant": "restaurant", &"promotion_office": "office"}[d.id]
		if skip.has(category) or (lvl > 0 and skip.has("upgrades")):
			continue
		if lvl == 0:
			var cell := _find_cell(d.id)
			if cell.x >= 0:
				out.append({"group": GROUP_OF_BUILDING[d.id], "cost": cost, "name": "build_%s" % d.id,
					"run": g.build.bind(d.id, cell)})
		else:
			out.append({"group": 7, "cost": cost, "name": "%s_L%d" % [d.id, lvl + 1], "run": g.upgrade.bind(d.id)})
	if not skip.has("seats") and Economy.seats_cost(g.state, g.tuning) >= 0:
		out.append({"group": 5, "cost": Economy.seats_cost(g.state, g.tuning), "name": "seats_tier_%d" % (g.state.seats_tier + 2),
			"run": g.expand_seats})
	if not skip.has("fighters") and Economy.fighters_cost(g.state, g.tuning) >= 0:
		out.append({"group": 6, "cost": Economy.fighters_cost(g.state, g.tuning), "name": "fighters_tier_%d" % (g.state.fighter_tier + 2),
			"run": g.expand_fighters})
	return out


func _find_cell(id: StringName) -> Vector2i:
	var land: Rect2i = Buildings.land_rect(g.tuning)
	for x in range(land.position.x, land.end.x):
		for y in range(land.position.y, land.end.y):
			if g.can_place(id, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _buy_loop() -> void:
	while true:
		var best := {}
		for c in _candidates():
			if c.cost <= g.state.gold and (best.is_empty() or c.group < best.group or (c.group == best.group and c.cost < best.cost)):
				best = c
		if best.is_empty():
			break
		if not best.run.call():
			break
		spent += best.cost
		_record_purchase(best.name, best.cost)
	if not skip.has("props"):
		_buy_props()


func _buy_props() -> void:
	for _i in 8:
		var bought := false
		var order := PROP_ORDER.duplicate()  # least stocked first
		order.sort_custom(func(a: StringName, b: StringName) -> bool: return g.props_owned(a) < g.props_owned(b))
		for id: StringName in order:
			var price: int = g.prop_price(id)
			if g.props_owned(id) < PROP_STOCK and price <= PROP_SHARE * g.state.gold and g.buy_prop(id):
				spent += price
				_record_purchase("prop_" + String(id), price)
				bought = true
				break
		if not bought:
			return


func _record_purchase(purchase_name: String, cost: int) -> void:
	var at := clock if clock > t else t
	purchases.append({"t": at, "name": purchase_name, "cost": cost})
	if purchase_name.begins_with("recruit_"):
		_mark("first_recruit", at)
	if purchase_name.begins_with("build_"):
		_mark("first_building", at)
	if purchase_name.begins_with("prop_"):
		_mark("first_prop", at)
	_mark(purchase_name, at)


func _all_bought() -> bool:
	return g.state.heroes.all(func(h: HeroState) -> bool: return h.owned) and g.state.seats_tier >= g.tuning.seat_tiers.size() - 1 \
			and g.state.fighter_tier >= g.tuning.fighter_tiers.size() - 1 \
			and g.building_defs().all(func(d: BuildingDef) -> bool: return g.building_next_cost(d.id) < 0)


func _mark(key: String, at: float) -> void:
	if not milestones.has(key):
		milestones[key] = at


# --- signals -------------------------------------------------------------------------------

func _on_bout(out: Dictionary) -> void:
	bouts += 1
	var base := roundi(float(out.locked_base) * float(out.multiplier))
	income.tickets += base
	income.main_event += int(out.payout) - base
	income.concessions += int(out.concessions)
	income.tips += int(out.get("tips", 0))
	var bucket := "e%03d" % (int(float(out.excitement) / 10.0) * 10)
	excitement_hist[bucket] = int(excitement_hist.get(bucket, 0)) + 1
	var key := "x%s" % out.multiplier
	multiplier_bouts[key] = int(multiplier_bouts.get(key, 0)) + 1
	_mark("first_bout_end", clock)


func _on_series(result: Dictionary) -> void:
	var bell: float = _cur.get("bell", clock)
	var plant_at: float = _cur.get("plant", bell)
	series_log.append({"plant": plant_at, "bell": bell, "end": clock, "bouts": int(result.bouts),
		"main_event": not result.main_event.is_empty(), "fame_bonus": int(result.fame_bonus)})
	_mark("first_series_end", clock)
	if not result.main_event.is_empty():
		main_events_cashed += 1
		var kind := String(result.main_event.kind)
		cashed_kinds[kind] = int(cashed_kinds.get(kind, 0)) + 1
	_cur = {}
