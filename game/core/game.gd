extends Node
## Autoload "Game": owns GameState, runs the sim clock, and is the whole write API (contract sections 2, 3, 5).
## Gym rules: a trainee is owned, below the level cap and not in the planted lineup or the running series;
## while the game runs (not paused, in any phase) it earns `gym_xp` every `gym_interval` seconds. Trainees
## are never auto-recalled: `plant` and `book_fight` refuse them instead, and the level cap releases them.
## Testability: scripts run through --script have no autoloads, so tests do `Game.new()` and assign
## `events` (an Events instance), `save_path` and `sim` (a fake simulator) before calling commands.

const CATALOG_PATH := "res://game/data/catalog.tres"
const COMBAT_SIM_PATH := "res://game/combat/combat_sim.gd"  # loaded lazily: written by another gate

var catalog: Catalog
var tuning: Tuning
var hero_defs: Array[HeroDef]
var state: GameState
var events: Node  ## the Events autoload (set in _ready), or a test instance
## (lineup: Array[Dictionary], seed: int, mods) -> {events: Array[Dictionary], result: Dictionary}
var sim := Callable()
var save_path := SaveStore.DEFAULT_PATH
var autosave := true
var paused := false
## Running bout, empty while idle or between bouts: lineup, attendance, seats, seed, locked_base,
## duration, events, result, clock, next. Not saved.
var fight := {}
## Running series (first to `tuning.series_wins`), empty while idle: lineup, attendance (locked at the
## bell), seats, wins {hero id: n}, bout (bouts settled), pause (seconds until the next bout), seed. Not saved.
var series := {}
## The lineup planted for the next series: hype only grows while one is planted (like a seed), and the
## series consumes it. Empty when nothing is planted. Not saved.
var planted: Array[int] = []
## The story chosen for the next plant (-1 = none). Ripe stories only; lineup edits that drop its heroes clear it.
var main_event_id := -1
## The prop picked for the next plant (&"" = none), one of `state.props`.
var selected_prop: StringName = &""
## What `plant` locked in for the planted lineup: the main event ({} or {id, kind, title, ripeness, multiplier})
## and the consumed prop (&"" = none). Not saved; uprooting gives the prop back.
var planted_main_event := {}
var planted_prop: StringName = &""
var _hype_emit_acc := 0.0


func _init() -> void:
	catalog = load(CATALOG_PATH)
	tuning = catalog.tuning
	hero_defs = catalog.heroes
	state = GameState.create(tuning, hero_defs)


func _ready() -> void:
	if events == null:
		events = get_node_or_null("/root/Events")


func _physics_process(dt: float) -> void:
	if not paused:
		advance(dt)


## One sim step. Idle: hype grows and the manager may book. Fighting: the playback clock runs and
## hype stays frozen. A step that crosses the end of a fight drops its leftover time.
func advance(dt: float) -> void:
	_train(dt)
	if not state.stories.is_empty():
		_story_signals(Stories.tick(state, catalog, dt))
	if not fight.is_empty():
		_play(dt)
		return
	if not series.is_empty():
		series.pause -= dt
		if series.pause <= 0.0 and not _start_bout():
			series = {}
		return
	if planted.is_empty():
		return  # nothing planted, nothing grows
	var before := state.hype
	state.hype = Hype.grow(before, dt, tuning, Buildings.hype_tau_multiplier(state, catalog))
	_hype_emit_acc += dt
	if _hype_emit_acc >= tuning.hype_emit_interval and state.hype != before:
		_hype_emit_acc = 0.0
		events.hype_changed.emit(state.hype)
	if AutoManager.should_book(state, tuning, planted):
		book_fight(planted, {"main_event": planted_main_event, "prop": planted_prop})


# --- commands ------------------------------------------------------------------------------

func new_game() -> bool:
	state = GameState.create(tuning, hero_defs)
	state.manager.enabled = true  # the bell rings by itself; there is no manual Book
	_reset_transient()
	_announce()
	_autosave()
	return true


func continue_game() -> bool:
	var loaded := SaveStore.load_state(tuning, hero_defs.size(), save_path, catalog)
	if loaded.is_empty():
		return false
	state = loaded.state
	state.manager.enabled = true
	_reset_transient()
	_announce()
	if loaded.recovered:
		events.toast.emit("Save restored from backup", &"save")
	return true


func save() -> bool:
	return SaveStore.save(state, save_path) == OK


func set_paused(value: bool) -> bool:
	if paused != value:
		paused = value
		events.paused_changed.emit(paused)
	return true


## Rings the bell: starts a series with the crowd hype has built (locked for every bout).
## `opts`: main_event (the locked Dictionary `plant` makes), prop (StringName), mods (combat mods),
## seed (int, tests; bout n uses seed + n).
func book_fight(lineup: Array[int], opts := {}) -> bool:
	if not fight.is_empty() or not series.is_empty() or not Roster.valid_lineup(state, tuning, lineup) 			or _any_training(lineup):
		return false
	if not _simulator().is_valid():
		return false
	var seats := Roster.seats(state, tuning)
	var attendance := Hype.attendance(seats, state.hype, tuning)
	var rng_seed := int(opts.get("seed", state.rng_seed_counter))
	state.rng_seed_counter += 1
	var main_event: Variant = opts.get("main_event", {})
	main_event = main_event.duplicate() if main_event is Dictionary else {}
	var prop := StringName(opts.get("prop", &""))
	series = {"lineup": lineup.duplicate(), "attendance": attendance, "seats": seats, "wins": {},
		"bout": 0, "pause": 0.0, "seed": rng_seed, "opts": opts, "main_event": main_event, "prop": prop}
	events.fight_booked.emit(lineup.duplicate(), StringName(main_event.get("kind", &"")))
	events.series_started.emit({"lineup": lineup.duplicate(), "attendance": attendance, "seats": seats,
		"wins_needed": tuning.series_wins, "main_event": main_event.duplicate(), "prop": prop})
	if not _start_bout():
		series = {}
		return false
	return true


## Plants the selected lineup: from now on hype grows, and the bell rings the series with these fighters.
func plant() -> bool:
	if not planted.is_empty() or not series.is_empty() or not fight.is_empty() 			or not Roster.valid_lineup(state, tuning, state.preferred_lineup) or _any_training(state.preferred_lineup):
		return false
	planted = state.preferred_lineup.duplicate()
	planted_main_event = _lock_main_event()
	planted_prop = selected_prop if props_owned(selected_prop) > 0 else &""
	if planted_prop != &"":
		state.props[String(planted_prop)] -= 1
		selected_prop = &""
		events.prop_changed.emit()
	events.planted_changed.emit()
	return true


## Takes the planted lineup back out before its series starts. The prop comes back; the story was never spent.
func uproot() -> bool:
	if planted.is_empty() or not series.is_empty():
		return false
	if planted_prop != &"":
		state.props[String(planted_prop)] = props_owned(planted_prop) + 1
		events.prop_changed.emit()
	planted = []
	planted_main_event = {}
	planted_prop = &""
	events.planted_changed.emit()
	return true


## Picks or drops one fighter in the selection. Picking into a full lineup swaps out the oldest pick,
## so changing fighters never has to dip below the minimum first.
func toggle_lineup(id: int) -> bool:
	var lineup: Array[int] = state.preferred_lineup.duplicate()
	if id in lineup:
		lineup.erase(id)
	else:
		if lineup.size() >= Roster.fighter_capacity(state, tuning):
			lineup.pop_front()
		lineup.append(id)
	return set_preferred_lineup(lineup)


func set_preferred_lineup(ids: Array[int]) -> bool:
	if not Roster.valid_lineup(state, tuning, ids):
		return false
	state.preferred_lineup = ids.duplicate()
	var story_heroes: Array = Stories.get_story(state, main_event_id).get("heroes", [])
	if not story_heroes.all(func(hero: int) -> bool: return hero in ids):
		clear_main_event()
	events.roster_changed.emit()
	_autosave()
	return true


## Picks a ripe story for the next plant and sets the lineup to its heroes (a one-hero story brings a partner:
## the first other owned hero in the current lineup, else the first owned one). False, and nothing changes,
## when the story is missing or unripe, a hero is not owned or is training, or the lineup does not fit.
func set_main_event(story_id: int) -> bool:
	var story := Stories.get_story(state, story_id)
	if story.is_empty() or not story.ripe:
		return false
	var ids: Array[int] = story.heroes.duplicate()
	var partners: Array[int] = state.preferred_lineup.duplicate()
	for id in state.heroes.size():
		partners.append(id)  # after the lineup, in id order
	for id in partners:
		if ids.size() >= tuning.min_lineup:
			break
		if state.heroes[id].owned and not state.training.has(id) and id not in ids:
			ids.append(id)
	if not Roster.valid_lineup(state, tuning, ids) or _any_training(ids) or not set_preferred_lineup(ids):
		return false
	main_event_id = story_id  # after the lineup edit, which clears the previous choice
	events.story_changed.emit(story_id)
	return true


func clear_main_event() -> bool:
	if main_event_id < 0:
		return false
	var id := main_event_id
	main_event_id = -1
	events.story_changed.emit(id)
	return true


func set_manager(enabled: bool, threshold: float) -> bool:
	if threshold < 0.0 or threshold >= tuning.hype_max:
		return false
	state.manager = {"enabled": enabled, "threshold": threshold}
	events.manager_changed.emit()
	_autosave()
	return true


func recruit(hero_id: int) -> bool:
	if not Roster.can_recruit(state, hero_defs, hero_id, hero_capacity()):
		return false
	_spend(hero_defs[hero_id].price)
	state.heroes[hero_id].owned = true
	events.hero_changed.emit(hero_id)
	events.roster_changed.emit()
	events.toast.emit("%s joined the club" % hero_defs[hero_id].display_name, &"recruit")
	_autosave()
	return true


func expand_seats() -> bool:
	var cost := Economy.seats_cost(state, tuning)
	if cost < 0 or not can_afford(cost):
		return false
	_spend(cost)
	state.seats_tier += 1
	events.roster_changed.emit()  # seat count shows in the HUD and roster; no separate signal
	events.toast.emit("Arena expanded to %d seats" % Roster.seats(state, tuning), &"seats")
	_autosave()
	return true


func expand_fighters() -> bool:
	var cost := Economy.fighters_cost(state, tuning)
	if cost < 0 or not can_afford(cost):
		return false
	_spend(cost)
	state.fighter_tier += 1
	events.roster_changed.emit()
	events.toast.emit("Up to %d fighters per bout" % Roster.fighter_capacity(state, tuning), &"fighters")
	_autosave()
	return true


## Places an unbuilt building at `cell` (its top-left) and pays its level-1 price.
func build(id: StringName, cell: Vector2i) -> bool:
	var cost := building_next_cost(id)
	if building_level(id) != 0 or cost < 0 or not can_place(id, cell) or not can_afford(cost):
		return false
	_spend(cost)
	state.buildings[String(id)] = {"level": 1, "cell": [cell.x, cell.y]}
	_building_done(id, "%s built" % Buildings.def(catalog, id).display_name)
	return true


func upgrade(id: StringName) -> bool:
	var cost := building_next_cost(id)
	if building_level(id) == 0 or cost < 0 or not can_afford(cost):
		return false
	_spend(cost)
	state.buildings[String(id)].level += 1
	_building_done(id, "%s upgraded" % Buildings.def(catalog, id).display_name)
	return true


## Free. Moving onto its own spot is a successful no-op.
func move_building(id: StringName, cell: Vector2i) -> bool:
	if building_level(id) == 0 or not can_place(id, cell):
		return false
	if cell != building_cell(id):
		state.buildings[String(id)].cell = [cell.x, cell.y]
		events.building_changed.emit(id)
		_autosave()
	return true


func assign_training(hero_id: int) -> bool:
	if hero_id < 0 or hero_id >= state.heroes.size() or state.training.has(hero_id) 			or state.training.size() >= training_slots() or not state.heroes[hero_id].owned 			or state.heroes[hero_id].level >= tuning.level_cap or hero_id in planted 			or (not series.is_empty() and hero_id in series.lineup):
		return false
	state.training[hero_id] = 0.0
	events.hero_changed.emit(hero_id)
	_autosave()
	return true


func recall_training(hero_id: int) -> bool:
	if not state.training.erase(hero_id):
		return false
	events.hero_changed.emit(hero_id)
	_autosave()
	return true


## Buys one prop at its seat-scaled price; at most `prop_cap` are held (a planted one still counts).
func buy_prop(id: StringName) -> bool:
	var price := prop_price(id)
	var held := props_owned(id) + (1 if planted_prop == id else 0)
	if price < 0 or held >= tuning.prop_cap or not can_afford(price):
		return false
	_spend(price)
	state.props[String(id)] = props_owned(id) + 1
	events.prop_changed.emit()
	_autosave()
	return true


## Picks the prop the next plant uses; &"" clears the choice. Needs one in stock.
func select_prop(id: StringName) -> bool:
	if id != &"" and props_owned(id) < 1:
		return false
	if selected_prop != id:
		selected_prop = id
		events.prop_changed.emit()
	return true


# --- queries -------------------------------------------------------------------------------

func can_afford(cost: int) -> bool:
	return state.gold >= cost


func building_level(id: StringName) -> int:
	return Buildings.level(state, id)


## (-1, -1) while unbuilt.
func building_cell(id: StringName) -> Vector2i:
	return Buildings.cell(state, id)


func can_place(id: StringName, cell: Vector2i) -> bool:
	return Buildings.can_place(state, catalog, id, cell)


func building_at(cell: Vector2i) -> StringName:
	return Buildings.building_at(state, catalog, cell)


## Price of the next level, or -1 when maxed.
func building_next_cost(id: StringName) -> int:
	return Buildings.next_cost(state, catalog, id)


func building_defs() -> Array[BuildingDef]:
	return catalog.buildings


func training_heroes() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(state.training.keys())
	return ids


func training_slots() -> int:
	return Buildings.training_slots(state, catalog)


func hero_capacity() -> int:
	return Buildings.hero_capacity(state, catalog)


## The crowd in the arena: the locked one during a series, otherwise what the bell would draw now.
func crowd_now() -> int:
	return int(series.attendance) if not series.is_empty() else attendance_if_booked_now()


func attendance_if_booked_now() -> int:
	return Hype.attendance(Roster.seats(state, tuning), state.hype, tuning)


## Locked ticket base for a lineup at the current crowd (before the excitement multiplier); 0 if invalid.
func income_preview(lineup: Array[int]) -> int:
	if not Roster.valid_lineup(state, tuning, lineup):
		return 0
	return Economy.base_income(state, tuning, lineup, attendance_if_booked_now())


## Expected result of ringing the bell for `lineup`: {stars_min, stars_max (1..5 in halves), income_min,
## income_max (ticket payout per bout at the manager's bell threshold)}; zeros for an invalid lineup.
## `opts`: prop (StringName, default `selected_prop`), main_event (story id, default `main_event_id`). Pure.
func preview(lineup: Array[int], opts := {}) -> Dictionary:
	var prop := Props.def(catalog, StringName(opts.get("prop", selected_prop)))
	var fits := func(story: Dictionary) -> bool:
		return story.ripe and story.heroes.all(func(hero: int) -> bool: return hero in lineup)
	var chosen := Stories.get_story(state, int(opts.get("main_event", main_event_id)))
	var multiplier := Stories.multiplier(chosen.ripeness, tuning) if not chosen.is_empty() and fits.call(chosen) else 1.0
	return Preview.estimate(state, catalog, lineup, prop, state.stories.any(fits), multiplier)


func hero_traits(hero_id: int) -> Array[TraitDef]:
	var none: Array[TraitDef] = []
	return Traits.of_hero(catalog, hero_id) if hero_id >= 0 and hero_id < hero_defs.size() else none


## The story board as copies (UI reads it; only the rules change it).
func stories() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for story in state.stories:
		out.append(story.duplicate())
	return out


func story(id: int) -> Dictionary:
	return Stories.get_story(state, id).duplicate()


## Story board size: the base slots plus one per Promotion Office level.
func story_slots() -> int:
	return tuning.story_slots_base + building_level(Buildings.OFFICE)


func prop_defs() -> Array[PropDef]:
	return catalog.props


## Seat-scaled price of a prop, or -1 for an unknown id.
func prop_price(id: StringName) -> int:
	var d := Props.def(catalog, id)
	return Props.price(d, Roster.seats(state, tuning), tuning) if d != null else -1


func props_owned(id: StringName) -> int:
	return Props.owned(state, id)


# --- internals -----------------------------------------------------------------------------

func _simulator() -> Callable:
	if not sim.is_valid() and ResourceLoader.exists(COMBAT_SIM_PATH):
		sim = Callable(load(COMBAT_SIM_PATH), &"simulate")
	return sim


## Simulates the next bout of the running series and starts its playback.
func _start_bout() -> bool:
	var lineup: Array[int] = series.lineup
	var mods: Dictionary = series.opts.get("mods", {}).duplicate(true)
	Traits.combat_mods(state, catalog, lineup, mods)  # levels may have changed since the last bout
	Props.apply(Props.def(catalog, series.prop), mods)
	var out: Dictionary = _simulator().call(_fighters(lineup), int(series.seed) + int(series.bout), mods)
	if not out.get("events") is Array or not out.get("result") is Dictionary:
		return false
	var duration := float(out.result.get("duration", 0.0))
	var locked_base := Economy.base_income(state, tuning, lineup, series.attendance)
	fight = {"lineup": lineup.duplicate(), "attendance": series.attendance, "seats": series.seats,
		"seed": int(series.seed) + int(series.bout), "locked_base": locked_base, "duration": duration,
		"events": out.events, "result": out.result, "clock": 0.0, "next": 0}
	events.fight_started.emit({"lineup": lineup.duplicate(), "attendance": series.attendance,
		"seats": series.seats, "seed": fight.seed, "duration": duration, "locked_base": locked_base})
	return true


func _fighters(lineup: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in lineup:
		var def := hero_defs[id]
		var stats := Roster.stats_for(def, state.heroes[id].level, tuning)
		result.append({"id": id, "name": def.display_name, "red": def.red, "ranged": def.ranged,
			"health": stats.health, "attack": stats.attack,
			"skill": {"kind": def.skill.kind, "power": def.skill.power}})
	return result


func _play(dt: float) -> void:
	fight.clock += dt
	var list: Array = fight.events
	while fight.next < list.size() and float(list[fight.next].t) <= fight.clock:
		_release(list[fight.next])
		fight.next += 1
	if fight.next >= list.size() and fight.clock >= fight.duration:
		_settle()


func _release(event: Dictionary) -> void:
	events.combat_event.emit(event)
	if event.get("kind") == &"skill" or event.get("kind") == "skill":
		var tip := int(event.get("tip", tuning.cast_tip))
		state.gold += tip
		events.gold_changed.emit(state.gold, tip)


func _settle() -> void:
	var done := fight
	fight = {}
	var tier_before := Fame.tier(state.fame_points, tuning)
	var main_event: Dictionary = series.get("main_event", {})
	var concessions := Buildings.concession_rate(state, catalog) + Props.concession_bonus(Props.def(catalog, series.get("prop", &"")))
	var out := Economy.settle(state, tuning, done.lineup, done.result, done.attendance, done.locked_base,
			concessions, float(main_event.get("multiplier", 1.0)))
	events.gold_changed.emit(state.gold, out.payout + out.concessions)
	_hype_emit_acc = 0.0
	events.hype_changed.emit(state.hype)
	events.fame_changed.emit(state.fame_points, out.fame_tier)
	if out.fame_tier > tier_before:
		events.toast.emit("Fame: %s" % tuning.fame_tier_names[out.fame_tier], &"fame")
	var leveled := false
	for hero: Dictionary in out.heroes:
		events.hero_changed.emit(hero.id)
		leveled = leveled or hero.level > hero.level_before
	if leveled:
		events.roster_changed.emit()
	_story_signals(Stories.on_bout(state, catalog, out, story_slots()))
	var ended := _count_bout(int(done.result.get("winner", -1)))  # before the signal so listeners see the score
	events.fight_finished.emit(out)
	if not ended.is_empty():
		events.series_finished.emit(ended)
	_autosave()


## Counts the bout for the series. Returns the series result once it ends (`series_wins` reached or the
## draw guard hit), otherwise schedules the next bout and returns {}.
func _count_bout(winner: int) -> Dictionary:
	if series.is_empty():
		return {}
	series.bout += 1
	if winner >= 0:
		series.wins[winner] = int(series.wins.get(winner, 0)) + 1
	var won: bool = winner >= 0 and series.wins[winner] >= tuning.series_wins
	if not won and series.bout < tuning.series_max_bouts:
		series.pause = tuning.series_pause
		return {}
	var main_event: Dictionary = series.main_event
	var bonus := tuning.series_fame_bonus if won else 0
	if won and not main_event.is_empty():
		bonus += roundi(main_event.ripeness / tuning.main_event_fame_divisor)
	state.fame_points += bonus
	var result := {"winner": winner if won else -1, "wins": series.wins.duplicate(), "bouts": series.bout,
		"fame_bonus": bonus, "lineup": series.lineup.duplicate(), "main_event": main_event.duplicate(), "prop": series.prop}
	var glow := Traits.afterglow_mult(catalog, series.lineup) * Props.afterglow_mult(Props.def(catalog, series.prop))
	series = {}
	planted = []
	planted_main_event = {}
	planted_prop = &""
	events.planted_changed.emit()
	if bonus > 0:
		events.fame_changed.emit(state.fame_points, Fame.tier(state.fame_points, tuning))
	if glow != 1.0:  # the crowd lingers when the series is over
		state.hype = minf(state.hype * glow, tuning.hype_max)
		_hype_emit_acc = 0.0
		events.hype_changed.emit(state.hype)
	if not main_event.is_empty():  # cashed in
		Stories.remove(state, main_event.id)
		events.story_changed.emit(main_event.id)
		_check_main_event()
	return result


## The chosen main event as the plant freezes it, or {} when none is chosen or it is no longer ripe.
func _lock_main_event() -> Dictionary:
	var story := Stories.get_story(state, main_event_id)
	if story.is_empty() or not story.ripe:
		return {}
	return {"id": story.id, "kind": story.kind, "title": story.title, "ripeness": story.ripeness,
		"multiplier": Stories.multiplier(story.ripeness, tuning)}


## Emits what a story update changed (`Stories.tick` / `on_bout` report) and drops a main event that died.
func _story_signals(report: Dictionary) -> void:
	for id: int in report.changed:
		events.story_changed.emit(id)
	for id: int in report.ripe:
		var story := Stories.get_story(state, id)
		events.story_ripe.emit(id)
		events.toast.emit("%s ripe: %s" % [Stories.KIND_NAMES[story.kind], Stories.names(catalog, story.heroes)], &"story")
	_check_main_event()


## The chosen main event must stay a ripe story on the board.
func _check_main_event() -> void:
	if main_event_id >= 0 and not Stories.get_story(state, main_event_id).get("ripe", false):
		clear_main_event()


func _reset_transient() -> void:
	fight = {}
	series = {}
	planted = []
	planted_main_event = {}
	planted_prop = &""
	main_event_id = -1
	selected_prop = &""


func _any_training(ids: Array[int]) -> bool:
	return ids.any(func(id: int) -> bool: return state.training.has(id))


## Gym: every trainee earns `gym_xp` per `gym_interval`; planted/series fighters and the capped are skipped.
func _train(dt: float) -> void:
	if state.training.is_empty():
		return
	var changed := false
	var leveled := false
	for id: int in state.training.keys():
		var hero := state.heroes[id]
		if id in planted or (not series.is_empty() and id in series.lineup):
			continue
		state.training[id] += dt
		while state.training[id] >= tuning.gym_interval and hero.level < tuning.level_cap:
			state.training[id] -= tuning.gym_interval
			var before := hero.level
			Roster.award_xp(hero, tuning.gym_xp, tuning)
			leveled = leveled or hero.level > before
			changed = true
			events.hero_changed.emit(id)
		if hero.level >= tuning.level_cap:
			state.training.erase(id)
			changed = true
			events.hero_changed.emit(id)
	if leveled:
		events.roster_changed.emit()
	if changed:
		_autosave()


func _building_done(id: StringName, text: String) -> void:
	events.building_changed.emit(id)
	events.toast.emit(text, &"building")
	_autosave()


func _spend(cost: int) -> void:
	state.gold -= cost
	events.gold_changed.emit(state.gold, -cost)


func _autosave() -> void:
	if autosave:
		save()


## Tells listeners to redraw everything after new_game / continue_game.
func _announce() -> void:
	events.gold_changed.emit(state.gold, 0)
	events.hype_changed.emit(state.hype)
	events.fame_changed.emit(state.fame_points, Fame.tier(state.fame_points, tuning))
	events.roster_changed.emit()
	events.manager_changed.emit()
	events.planted_changed.emit()
	for id in state.heroes.size():
		events.hero_changed.emit(id)
	for def in catalog.buildings:
		events.building_changed.emit(def.id)
