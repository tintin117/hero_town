extends RefCounted
## The story board: every kind created and ripened by its rule, slots and replacement, overripe cooling,
## signals, determinism and the save.

const Kit := preload("res://game/tests/core_kit.gd")
const PATH := Kit.SAVE_DIR + "/stories_save.json"


func run() -> Array[String]:
	var p: Array[String] = []
	_win_streak(p)
	_rivalry_and_grudge(p)
	_comeback(p)
	_legend(p)
	_slots(p)
	_overripe(p)
	_determinism(p)
	_save(p)
	return p


func _game() -> Array:
	var fake := Kit.FakeSim.new()
	return [Kit.game(fake), fake]


func _win_streak(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	var changed: Array[int] = []
	var ripe: Array[int] = []
	var toasts: Array[String] = []
	g.events.story_changed.connect(func(id: int) -> void: changed.append(id))
	g.events.story_ripe.connect(func(id: int) -> void: ripe.append(id))
	g.events.toast.connect(func(text: String, icon: StringName) -> void: if icon == &"story": toasts.append(text))
	for i in 2:
		Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories.is_empty(), "two wins are not a streak")
	Kit.bout(g, fake, 0)
	var s := Stories.find(g.state, Stories.WIN_STREAK, [0] as Array[int])
	Kit.check(p, not s.is_empty() and Kit.near(s.ripeness, 20.0) and not s.ripe and not s.cooling, "the third win starts a streak at 20: %s" % [s])
	Kit.check(p, s.title == "Bram's 3-win streak" and s.id == 0, "title and id: %s" % s.title)
	Kit.check(p, changed == [0], "story_changed on creation: %s" % [changed])
	Kit.bout(g, fake, 0)
	Kit.check(p, Kit.near(s.ripeness, 45.0) and s.title == "Bram's 4-win streak" and changed == [0, 0], "+25 per further win (%s)" % s.ripeness)
	Kit.bout(g, fake, 0)
	Kit.check(p, Kit.near(s.ripeness, 70.0) and s.ripe, "ripe at 70")
	Kit.check(p, ripe == [0] and toasts == ["Win streak ripe: Bram"], "story_ripe and a toast once: %s %s" % [ripe, toasts])
	Kit.check(p, g.state.stories.size() == 1, "one story per (kind, heroes)")
	Kit.check(p, g.story(0).ripe and g.story(5).is_empty(), "Game.story")
	# a broken streak keeps the story (it stays until cashed or cold) but stops ripening
	Kit.bout(g, fake, 1)
	Kit.check(p, Kit.near(s.ripeness, 70.0) and g.state.heroes[0].streak == 0, "a lost bout does not ripen the streak")
	Kit.dispose(g)


func _rivalry_and_grudge(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	var duo: Array[int] = [0, 1]
	Kit.bout(g, fake, 0)
	Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories.is_empty(), "no split, no rivalry")
	Kit.check(p, g.state.meetings == {"0-1": {"wins_a": 2, "wins_b": 0}}, "meetings keyed a-b: %s" % [g.state.meetings])
	Kit.bout(g, fake, 1)
	var rivalry := Stories.find(g.state, Stories.RIVALRY, duo)
	Kit.check(p, not rivalry.is_empty() and Kit.near(rivalry.ripeness, 20.0) and rivalry.title == "Bram vs Ivo rivalry",
			"a split over 3 meetings starts a rivalry at 20: %s" % [rivalry])
	Kit.check(p, Stories.find(g.state, Stories.GRUDGE, [0, 1] as Array[int]).is_empty(), "a rivalry made in this bout is no grudge yet")
	Kit.bout(g, fake, 1)
	Kit.check(p, Kit.near(rivalry.ripeness, 40.0), "+20 per meeting (%s)" % rivalry.ripeness)
	var grudge := Stories.find(g.state, Stories.GRUDGE, [0, 1] as Array[int])  # Bram (loser) against Ivo
	Kit.check(p, not grudge.is_empty() and Kit.near(grudge.ripeness, 20.0) and grudge.title == "Bram's grudge against Ivo",
			"losing to a rival starts a grudge [loser, winner]: %s" % [grudge])
	Kit.bout(g, fake, 1)
	Kit.check(p, Kit.near(rivalry.ripeness, 60.0) and rivalry.ripe, "rivalry ripe at 60")
	Kit.check(p, Kit.near(grudge.ripeness, 35.0, 1.0), "+15 per repeated loss, plus a little time (%s)" % grudge.ripeness)
	var before: float = grudge.ripeness
	for i in 60:
		g.advance(1.0)
	Kit.check(p, Kit.near(grudge.ripeness - before, 10.0, 1e-4), "grudge ripens with time: +1 per 6 s (%s)" % (grudge.ripeness - before))
	Kit.check(p, Kit.near(rivalry.ripeness, 60.0), "a rivalry does not ripen with time")
	Kit.check(p, g.state.heroes[1].streak == 3 and Stories.find(g.state, Stories.WIN_STREAK, [1] as Array[int]).size() > 0, "Ivo's streak story came along")
	Kit.dispose(g)


func _comeback(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	for i in 3:
		Kit.bout(g, fake, 1)
	Kit.check(p, g.state.heroes[0].recent_losses == 3 and g.state.heroes[1].recent_losses == 0, "recent losses count")
	Kit.check(p, Stories.find(g.state, Stories.COMEBACK, [0] as Array[int]).is_empty(), "no comeback while losing")
	Kit.bout(g, fake, 0)
	var s := Stories.find(g.state, Stories.COMEBACK, [0] as Array[int])
	Kit.check(p, not s.is_empty() and Kit.near(s.ripeness, 20.0) and s.title == "Bram's comeback", "a win after 3 losses: %s" % [s])
	Kit.check(p, g.state.heroes[0].recent_losses == 0 and g.state.heroes[1].recent_losses == 1, "the win resets the run")
	var before: float = s.ripeness
	for i in 30:
		g.advance(1.0)
	Kit.check(p, Kit.near(s.ripeness - before, 5.0, 1e-4), "ripens with time")
	Kit.dispose(g)


func _legend(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	g.state.heroes[0].level = 8
	Kit.bout(g, fake, 0)
	Kit.check(p, Stories.find(g.state, Stories.LEGEND, [0] as Array[int]).is_empty(), "one win is not enough")
	Kit.bout(g, fake, 0)
	var s := Stories.find(g.state, Stories.LEGEND, [0] as Array[int])
	Kit.check(p, not s.is_empty() and s.ripeness >= 20.0 and s.ripeness < 22.0 and s.title == "Bram the legend", "level 8 and 2 wins in a row: %s" % [s])
	Kit.bout(g, fake, 0)
	Kit.check(p, Kit.near(s.ripeness, 30.0, 1.5), "+10 per win, plus a little time (%s)" % s.ripeness)
	Kit.dispose(g)
	pair = _game()
	g = pair[0]
	fake = pair[1]
	g.state.heroes[1].level = 8
	Kit.bout(g, fake, 1)
	Kit.bout(g, fake, 1)
	Kit.check(p, not Stories.find(g.state, Stories.LEGEND, [1] as Array[int]).is_empty(), "any hero at level 8 can be a legend")
	Kit.dispose(g)


func _slots(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	Kit.check(p, g.story_slots() == 3, "three slots to begin with")
	g.state.buildings["promotion_office"] = {"level": 2, "cell": [10, 0]}
	Kit.check(p, g.story_slots() == 5, "+1 slot per Promotion Office level")
	g.state.buildings.clear()
	Kit.add_story(g, Stories.LEGEND, [5] as Array[int], 50.0)
	Kit.add_story(g, Stories.LEGEND, [6] as Array[int], 60.0)
	Kit.add_story(g, Stories.LEGEND, [7] as Array[int], 70.0)
	for i in 3:
		Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories.size() == 3 and Stories.find(g.state, Stories.WIN_STREAK, [0] as Array[int]).is_empty(),
			"a full board of riper stories drops the newcomer")
	g.state.buildings["promotion_office"] = {"level": 1, "cell": [10, 0]}
	Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories.size() == 4 and not Stories.find(g.state, Stories.WIN_STREAK, [0] as Array[int]).is_empty(),
			"an extra slot takes it")
	g.state.buildings.clear()
	g.state.stories.clear()
	var weakest := Kit.add_story(g, Stories.LEGEND, [5] as Array[int], 10.0)
	Kit.add_story(g, Stories.LEGEND, [6] as Array[int], 60.0)
	Kit.add_story(g, Stories.LEGEND, [7] as Array[int], 70.0)
	var changed: Array[int] = []
	g.events.story_changed.connect(func(id: int) -> void: changed.append(id))
	for i in 3:
		Kit.bout(g, fake, 0)
	Kit.check(p, g.state.stories.size() == 3 and Stories.find(g.state, Stories.LEGEND, [5] as Array[int]).is_empty()
			and not Stories.find(g.state, Stories.WIN_STREAK, [0] as Array[int]).is_empty(), "the least ripe story makes room")
	Kit.check(p, weakest in changed, "the replaced story is announced")
	Kit.dispose(g)


func _overripe(p: Array[String]) -> void:
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	var id := Kit.add_story(g, Stories.WIN_STREAK, [6] as Array[int], 100.0)
	var s: Dictionary = g.state.stories[0]
	var gone: Array[int] = []
	g.events.story_changed.connect(func(changed: int) -> void: if changed == id: gone.append(id))
	for i in 9:
		Kit.bout(g, fake, 0)
	Kit.check(p, s.full_bouts == 9 and not s.cooling, "counting bouts at full ripeness (%d)" % s.full_bouts)
	Kit.bout(g, fake, 0)
	Kit.check(p, s.cooling and Kit.near(s.ripeness, 100.0), "cooling after 10 full bouts")
	Kit.bout(g, fake, 0)
	Kit.check(p, Kit.near(s.ripeness, 95.0) and s.cooling, "then -5 per bout")
	for i in 18:
		Kit.bout(g, fake, 0)
	Kit.check(p, Kit.near(s.ripeness, 5.0) and Stories.get_story(g.state, id).size() > 0, "still on the board just above 0")
	Kit.bout(g, fake, 0)
	Kit.check(p, Stories.get_story(g.state, id).is_empty(), "removed at 0")
	Kit.check(p, not gone.is_empty(), "the removal is announced")
	# a story that drops below full before the limit restarts nothing: only bouts at exactly 100 count
	var other := Kit.add_story(g, Stories.WIN_STREAK, [7] as Array[int], 80.0)
	for i in 12:
		Kit.bout(g, fake, 0)
	Kit.check(p, Stories.get_story(g.state, other).full_bouts == 0, "below full ripeness nothing counts")
	Kit.dispose(g)


func _determinism(p: Array[String]) -> void:
	var runs: Array[Array] = []
	for r in 2:
		var pair := _game()
		var g: Node = pair[0]
		var fake: Kit.FakeSim = pair[1]
		for w in [0, 1, 0, 0, 1, 1, 0, 0, 0]:
			Kit.bout(g, fake, w)
		g.advance(30.0)
		runs.append([g.state.stories.duplicate(true), g.state.meetings.duplicate(true), g.state.next_story_id])
		Kit.dispose(g)
	Kit.check(p, runs[0] == runs[1] and not runs[0][0].is_empty(), "same bouts, same board")


func _save(p: Array[String]) -> void:
	Kit.clear_save_files(PATH)
	var pair := _game()
	var g: Node = pair[0]
	var fake: Kit.FakeSim = pair[1]
	g.save_path = PATH
	for w in [0, 1, 0, 1]:
		Kit.bout(g, fake, w)
	g.state.props["fireworks"] = 3
	Kit.check(p, g.state.stories.size() >= 2 and g.state.heroes[0].recent_losses >= 0, "have something to save")
	Kit.check(p, g.save(), "saved")
	var loaded := SaveStore.load_state(g.tuning, g.hero_defs.size(), PATH, g.catalog)
	Kit.check(p, not loaded.is_empty(), "loads")
	var state: GameState = loaded.state
	Kit.check(p, state.stories.size() == g.state.stories.size() and state.next_story_id == g.state.next_story_id, "stories and id counter round trip")
	for i in state.stories.size():
		var a: Dictionary = state.stories[i]
		var b: Dictionary = g.state.stories[i]
		Kit.check(p, a.id == b.id and a.kind == b.kind and a.title == b.title and a.heroes == b.heroes and a.ripe == b.ripe
				and a.cooling == b.cooling and a.full_bouts == b.full_bouts and Kit.near(a.ripeness, b.ripeness, 1e-9), "story %d round trip" % i)
	Kit.check(p, state.meetings == g.state.meetings and state.props == g.state.props, "meetings and props round trip")
	Kit.check(p, state.heroes[0].recent_losses == g.state.heroes[0].recent_losses and state.heroes[1].recent_losses == g.state.heroes[1].recent_losses, "recent losses round trip")
	# continue_game keeps stories and resets what is not saved
	g.main_event_id = 0
	g.selected_prop = &"fireworks"
	Kit.check(p, g.continue_game() and g.main_event_id == -1 and g.selected_prop == &"" and g.planted_prop == &"", "continue resets the transient choices")
	Kit.check(p, g.state.stories.size() == state.stories.size(), "continue keeps the board")
	Kit.check(p, g.new_game() and g.state.stories.is_empty() and g.state.props.is_empty() and g.state.meetings.is_empty(), "new game starts clean")
	Kit.clear_save_files(PATH)
	# old saves without the new keys load with defaults
	var t: Tuning = g.tuning
	var n: int = g.hero_defs.size()
	var old := GameState.create(t, g.hero_defs).to_dict()
	for key in ["stories", "next_story_id", "meetings", "props"]:
		old.erase(key)
	for hero: Dictionary in old.heroes:
		hero.erase("recent_losses")
	var decoded := SaveStore.decode({"version": 1, "state": old}, t, n, g.catalog)
	Kit.check(p, decoded != null and decoded.stories.is_empty() and decoded.props.is_empty(), "a save from before stories still loads")
	# validation
	var base := state.to_dict()
	_bad(p, g, base, "unknown kind", func(s: Dictionary) -> void: s.stories[0].kind = "feud")
	_bad(p, g, base, "hero out of range", func(s: Dictionary) -> void: s.stories[0].heroes[0] = 99)
	_bad(p, g, base, "wrong hero count", func(s: Dictionary) -> void: s.stories[0].heroes.append(1))
	_bad(p, g, base, "ripeness over 100", func(s: Dictionary) -> void: s.stories[0].ripeness = 101.0)
	_bad(p, g, base, "negative ripeness", func(s: Dictionary) -> void: s.stories[0].ripeness = -1.0)
	_bad(p, g, base, "ripe flag disagrees", func(s: Dictionary) -> void: s.stories[0].ripe = not s.stories[0].ripe)
	_bad(p, g, base, "duplicate story id", func(s: Dictionary) -> void: s.stories[1].id = s.stories[0].id)
	_bad(p, g, base, "more stories than slots", _overfill)
	_bad(p, g, base, "unknown prop", func(s: Dictionary) -> void: s.props["confetti"] = 1)
	_bad(p, g, base, "too many props", func(s: Dictionary) -> void: s.props["fireworks"] = 10)
	_bad(p, g, base, "bad meeting key", func(s: Dictionary) -> void: s.meetings = {"1-0": {"wins_a": 1, "wins_b": 1}})
	_bad(p, g, base, "negative meeting", func(s: Dictionary) -> void: s.meetings = {"0-1": {"wins_a": -1, "wins_b": 1}})
	_bad(p, g, base, "negative recent losses", func(s: Dictionary) -> void: s.heroes[0].recent_losses = -1)
	Kit.dispose(g)


func _overfill(s: Dictionary) -> void:
	s.stories.clear()
	for i in 4:
		s.stories.append({"id": 50 + i, "kind": "legend", "title": "x", "heroes": [i], "ripeness": 10.0, "ripe": false,
			"cooling": false, "full_bouts": 0})


func _bad(p: Array[String], g: Node, base: Dictionary, label: String, mutate: Callable) -> void:
	var s := base.duplicate(true)
	mutate.call(s)
	Kit.check(p, SaveStore.decode({"version": 1, "state": s}, g.tuning, g.hero_defs.size(), g.catalog) == null, "rejected: %s" % label)
