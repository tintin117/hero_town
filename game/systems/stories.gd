class_name Stories
extends RefCounted
## Story board rules, deterministic and pure. A story is {id, kind, title, heroes, ripeness (0..100), ripe,
## cooling, full_bouts}, one per (kind, heroes). Bouts create and ripen them (`on_bout`), the clock ripens
## the timed kinds (`tick`), and a full story left alone cools off and disappears. Both return
## {changed: Array[int], ripe: Array[int]}: ids whose whole ripeness, flags or existence changed, and ids
## that just crossed the ripe threshold, so callers can throttle their signals.

const WIN_STREAK := &"win_streak"  ## [hero]: streak reaches story_streak_len, ripens per further win
const RIVALRY := &"rivalry"  ## [a, b] (a < b): a split result over enough meetings, ripens per meeting
const GRUDGE := &"grudge"  ## [loser, winner]: a loss to a rival; ripens per repeat loss and with time
const COMEBACK := &"comeback"  ## [hero]: a win after a losing run; ripens with time
const LEGEND := &"legend"  ## [hero]: high level and a streak; ripens per win and with time
const KINDS: Array[StringName] = [WIN_STREAK, RIVALRY, GRUDGE, COMEBACK, LEGEND]
const TIMED: Array[StringName] = [GRUDGE, COMEBACK, LEGEND]
const KIND_NAMES := {WIN_STREAK: "Win streak", RIVALRY: "Rivalry", GRUDGE: "Grudge", COMEBACK: "Comeback", LEGEND: "Legend"}
const MAX_RIPENESS := 100.0


static func hero_count(kind: StringName) -> int:
	return 2 if kind == RIVALRY or kind == GRUDGE else 1


static func from_dict(d: Dictionary) -> Dictionary:
	var heroes: Array[int] = []
	for id: Variant in d.heroes:
		heroes.append(int(id))
	return {"id": int(d.id), "kind": StringName(d.kind), "title": String(d.title), "heroes": heroes,
		"ripeness": float(d.ripeness), "ripe": bool(d.ripe), "cooling": bool(d.cooling), "full_bouts": int(d.full_bouts)}


## Payout multiplier of a main event at `ripeness`: x1 (0) to x3 (100).
static func multiplier(ripeness: float, t: Tuning) -> float:
	return 1.0 + t.main_event_bonus * ripeness / MAX_RIPENESS


## The live story (mutable) or {}.
static func get_story(state: GameState, id: int) -> Dictionary:
	for s in state.stories:
		if s.id == id:
			return s
	return {}


static func find(state: GameState, kind: StringName, heroes: Array[int]) -> Dictionary:
	for s in state.stories:
		if s.kind == kind and s.heroes == heroes:
			return s
	return {}


static func remove(state: GameState, id: int) -> bool:
	for i in state.stories.size():
		if state.stories[i].id == id:
			state.stories.remove_at(i)
			return true
	return false


## "Bram vs Ivo": the heroes of a story by name.
static func names(catalog: Catalog, heroes: Array) -> String:
	return " vs ".join(heroes.map(func(id: int) -> String: return catalog.heroes[id].display_name))


## The clock ripens the timed kinds by 1 per Tuning.story_time_seconds.
static func tick(state: GameState, catalog: Catalog, dt: float) -> Dictionary:
	var before := _snapshot(state)
	for s in state.stories:
		if s.kind in TIMED:
			_ripen(catalog, s, dt / catalog.tuning.story_time_seconds)
	return _report(state, before)


## Applies one settled bout (`out` = Economy.settle's result) and ages the whole board.
static func on_bout(state: GameState, catalog: Catalog, out: Dictionary, slots: int) -> Dictionary:
	var before := _snapshot(state)
	var t := catalog.tuning
	var winner := int(out.winner)
	var lineup: Array = out.lineup
	if winner in lineup:
		var w: Dictionary = out.heroes.filter(func(h: Dictionary) -> bool: return h.id == winner)[0]
		for loser: int in lineup:
			if loser == winner:
				continue
			var pair := _ids(mini(winner, loser), maxi(winner, loser))
			var feud := not find(state, RIVALRY, pair).is_empty()  # a rivalry that already existed
			var m := _meeting(state, pair)
			m["wins_a" if winner == pair[0] else "wins_b"] += 1
			if m.wins_a > 0 and m.wins_b > 0 and m.wins_a + m.wins_b >= t.story_rivalry_meetings:
				_touch(state, catalog, slots, RIVALRY, pair, t.story_rivalry_step)
			if feud:
				_touch(state, catalog, slots, GRUDGE, _ids(loser, winner), t.story_grudge_step)
		var solo := _ids(winner)
		if w.streak >= t.story_streak_len:
			_touch(state, catalog, slots, WIN_STREAK, solo, t.story_streak_step, w.streak)
		if w.recent_losses_before >= t.story_comeback_losses:
			_touch(state, catalog, slots, COMEBACK, solo, t.story_comeback_step)
		if w.level >= t.story_legend_level and w.streak >= t.story_legend_streak:
			_touch(state, catalog, slots, LEGEND, solo, t.story_legend_step)
	_age(state, t)
	return _report(state, before)


static func _ids(a: int, b := -1) -> Array[int]:
	var result: Array[int] = [a]
	if b >= 0:
		result.append(b)
	return result


static func _meeting(state: GameState, pair: Array[int]) -> Dictionary:
	var key := "%d-%d" % [pair[0], pair[1]]
	if not state.meetings.has(key):
		state.meetings[key] = {"wins_a": 0, "wins_b": 0}
	return state.meetings[key]


## Ripens the story of (kind, heroes) by `step`, or creates it. A full board makes room by dropping the
## least ripe story, unless that one is riper than a new story.
static func _touch(state: GameState, catalog: Catalog, slots: int, kind: StringName, heroes: Array[int],
		step: float, count := 0) -> void:
	var s := find(state, kind, heroes)
	var title := _title(catalog, kind, heroes, count)
	if not s.is_empty():
		_ripen(catalog, s, step)
		if not s.cooling:
			s.title = title
		return
	var start := catalog.tuning.story_start
	if state.stories.size() >= slots:
		var lowest := 0
		for i in state.stories.size():
			if state.stories[i].ripeness < state.stories[lowest].ripeness:
				lowest = i
		if state.stories.is_empty() or start < state.stories[lowest].ripeness:
			return
		state.stories.remove_at(lowest)
	state.stories.append({"id": state.next_story_id, "kind": kind, "title": title, "heroes": heroes,
		"ripeness": start, "ripe": start >= catalog.tuning.story_ripe_threshold, "cooling": false, "full_bouts": 0})
	state.next_story_id += 1


## Cooling stories no longer ripen.
static func _ripen(catalog: Catalog, s: Dictionary, amount: float) -> void:
	if s.cooling:
		return
	s.ripeness = minf(MAX_RIPENESS, s.ripeness + amount * Traits.ripen_mult(catalog, s.heroes))
	s.ripe = s.ripeness >= catalog.tuning.story_ripe_threshold


## Once per bout: a full story counts its bouts at the top and cools off, a cooling one fades and goes at 0.
static func _age(state: GameState, t: Tuning) -> void:
	for i in range(state.stories.size() - 1, -1, -1):
		var s := state.stories[i]
		if s.cooling:
			s.ripeness -= t.story_cooling
		elif s.ripeness >= MAX_RIPENESS:
			s.full_bouts += 1
			s.cooling = s.full_bouts >= t.story_overripe_bouts
		s.ripe = s.ripeness >= t.story_ripe_threshold
		if s.ripeness <= 0.0:
			state.stories.remove_at(i)


static func _title(catalog: Catalog, kind: StringName, heroes: Array[int], count: int) -> String:
	var first: String = catalog.heroes[heroes[0]].display_name
	match kind:
		WIN_STREAK:
			return "%s's %d-win streak" % [first, count]
		RIVALRY:
			return "%s rivalry" % names(catalog, heroes)
		GRUDGE:
			return "%s's grudge against %s" % [first, catalog.heroes[heroes[1]].display_name]
		COMEBACK:
			return "%s's comeback" % first
	return "%s the legend" % first


static func _snapshot(state: GameState) -> Dictionary:
	var result := {}
	for s in state.stories:
		result[s.id] = [floori(s.ripeness), s.ripe, s.cooling]
	return result


static func _report(state: GameState, before: Dictionary) -> Dictionary:
	var changed: Array[int] = []
	var ripe: Array[int] = []
	var live := {}
	for s in state.stories:
		live[s.id] = true
		var was: Array = before.get(s.id, [])
		if was != [floori(s.ripeness), s.ripe, s.cooling]:
			changed.append(s.id)
		if s.ripe and not (was.size() == 3 and was[1]):
			ripe.append(s.id)
	for id: int in before:
		if not live.has(id):
			changed.append(id)
	return {"changed": changed, "ripe": ripe}
