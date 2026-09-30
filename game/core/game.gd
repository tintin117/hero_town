extends Node
## Autoload "Game": owns GameState, runs the sim clock, and is the whole write API (contract sections 2, 3, 5).
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
	if not fight.is_empty():
		_play(dt)
		return
	if not series.is_empty():
		series.pause -= dt
		if series.pause <= 0.0 and not _start_bout():
			series = {}
		return
	var before := state.hype
	state.hype = Hype.grow(before, dt, tuning)
	_hype_emit_acc += dt
	if _hype_emit_acc >= tuning.hype_emit_interval and state.hype != before:
		_hype_emit_acc = 0.0
		events.hype_changed.emit(state.hype)
	if AutoManager.should_book(state, tuning):
		book_fight(state.preferred_lineup)


# --- commands ------------------------------------------------------------------------------

func new_game() -> bool:
	state = GameState.create(tuning, hero_defs)
	state.manager.enabled = true  # the bell rings by itself; there is no manual Book
	fight = {}
	series = {}
	_announce()
	_autosave()
	return true


func continue_game() -> bool:
	var loaded := SaveStore.load_state(tuning, hero_defs.size(), save_path)
	if loaded.is_empty():
		return false
	state = loaded.state
	state.manager.enabled = true
	fight = {}
	series = {}
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
## `opts`: main_event (StringName), mods (combat mods), seed (int, tests; bout n uses seed + n).
func book_fight(lineup: Array[int], opts := {}) -> bool:
	if not fight.is_empty() or not series.is_empty() or not Roster.valid_lineup(state, tuning, lineup):
		return false
	if not _simulator().is_valid():
		return false
	var seats := Roster.seats(state, tuning)
	var attendance := Hype.attendance(seats, state.hype, tuning)
	var rng_seed := int(opts.get("seed", state.rng_seed_counter))
	state.rng_seed_counter += 1
	series = {"lineup": lineup.duplicate(), "attendance": attendance, "seats": seats, "wins": {},
		"bout": 0, "pause": 0.0, "seed": rng_seed, "opts": opts}
	events.fight_booked.emit(lineup.duplicate(), StringName(opts.get("main_event", &"")))
	events.series_started.emit({"lineup": lineup.duplicate(), "attendance": attendance, "seats": seats,
		"wins_needed": tuning.series_wins})
	if not _start_bout():
		series = {}
		return false
	return true


func set_preferred_lineup(ids: Array[int]) -> bool:
	if not Roster.valid_lineup(state, tuning, ids):
		return false
	state.preferred_lineup = ids.duplicate()
	events.roster_changed.emit()
	_autosave()
	return true


func set_manager(enabled: bool, threshold: float) -> bool:
	if threshold < 0.0 or threshold >= tuning.hype_max:
		return false
	state.manager = {"enabled": enabled, "threshold": threshold}
	events.manager_changed.emit()
	_autosave()
	return true


func recruit(hero_id: int) -> bool:
	if not Roster.can_recruit(state, hero_defs, hero_id):
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


# --- queries -------------------------------------------------------------------------------

func can_afford(cost: int) -> bool:
	return state.gold >= cost


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


# --- internals -----------------------------------------------------------------------------

func _simulator() -> Callable:
	if not sim.is_valid() and ResourceLoader.exists(COMBAT_SIM_PATH):
		sim = Callable(load(COMBAT_SIM_PATH), &"simulate")
	return sim


## Simulates the next bout of the running series and starts its playback.
func _start_bout() -> bool:
	var lineup: Array[int] = series.lineup
	var out: Dictionary = _simulator().call(_fighters(lineup), int(series.seed) + int(series.bout), series.opts.get("mods", {}))
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
	var out := Economy.settle(state, tuning, done.lineup, done.result, done.attendance, done.locked_base)
	events.gold_changed.emit(state.gold, out.payout)
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
	var bonus := tuning.series_fame_bonus if won else 0
	state.fame_points += bonus
	var result := {"winner": winner if won else -1, "wins": series.wins.duplicate(), "bouts": series.bout,
		"fame_bonus": bonus, "lineup": series.lineup.duplicate()}
	series = {}
	if bonus > 0:
		events.fame_changed.emit(state.fame_points, Fame.tier(state.fame_points, tuning))
	return result


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
	for id in state.heroes.size():
		events.hero_changed.emit(id)
