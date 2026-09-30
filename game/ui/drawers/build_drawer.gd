class_name BuildDrawer
extends Drawer
## Build screen: one entry per building (level, effects, Build / Upgrade / Move) and the Gym's training panel.
## Build and Move only ask for a placement (`place_requested`, the shell hands it to the town and calls
## Game.build / move_building afterwards); Upgrade and training go straight through Game commands.
## Bottom edge like the roster drawer. `game` / `events` default to the autoloads; tests set them before add_child.
## Reads game.building_*(), refreshes only from Events.

signal place_requested(id: StringName, moving: bool)

const ENTRY := preload("res://game/ui/drawers/build_entry.tscn")
const TRAINING := preload("res://game/ui/drawers/gym_training.tscn")
const MAX_WIDTH := 1240.0
const MAX_HEIGHT := 264.0
const GYM := &"gym"
const ICONS := {
	&"promotion_office": "megaphone", &"recruitment_hall": "scroll", &"gym": "sword", &"restaurant": "meat",
}

var game: Node
var events: Node
var entries := {}  ## building id -> BuildEntry
var training: GymTraining

@onready var scroll: ScrollContainer = $Column/Body/Scroll
@onready var _row: HBoxContainer = $Column/Body/Scroll/Entries


func _ready() -> void:
	super._ready()
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	if game == null:
		return
	for def in game.building_defs():
		var entry: BuildEntry = ENTRY.instantiate()
		_row.add_child(entry)
		entry.action_requested.connect(_on_action)
		entry.move_requested.connect(_place.bind(true))
		entries[def.id] = entry
		if def.id == GYM:
			training = TRAINING.instantiate()
			entry.extra.add_child(training)
			training.assign_requested.connect(func(id: int) -> void: game.assign_training(id))
			training.recall_requested.connect(func(id: int) -> void: game.recall_training(id))
	if events:
		for signal_name in [&"building_changed", &"hero_changed", &"roster_changed", &"gold_changed", &"planted_changed",
				&"series_started", &"series_finished"]:
			events.connect(signal_name, _on_event)
	var p := get_parent() as Control
	if p:
		p.resized.connect(_on_parent_resized)
	refresh()


func open() -> void:
	_fit()
	super.open()


func refresh() -> void:
	for def in game.building_defs():
		var level: int = game.building_level(def.id)
		var cost: int = game.building_next_cost(def.id)
		var now := Buildings.describe(game.catalog, def.id, level) if level > 0 else "Not built"
		var next := Buildings.describe(game.catalog, def.id, level + 1) if cost >= 0 else ""
		entries[def.id].show_building(def.id, def.display_name, def.description,
				load("res://resources/ui/icons/%s.png" % ICONS.get(def.id, "hammer")), level, def.levels.size(),
				now, next, cost, game.can_afford(cost))
	if training:
		_refresh_training()


## Scrolls to a building's entry and rings it (the shell calls this when the player clicks a building in the town).
func focus(id: StringName) -> void:
	if not entries.has(id):
		return
	var entry: BuildEntry = entries[id]
	entry.highlight()
	scroll.ensure_control_visible.call_deferred(entry)  # after the layout pass of a drawer that was just opened


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _on_action(id: StringName) -> void:
	if game.building_level(id) == 0:
		_place(id, false)
	else:
		game.upgrade(id)


func _place(id: StringName, moving: bool) -> void:
	place_requested.emit(id, moving)
	close()


func _refresh_training() -> void:
	var s: GameState = game.state
	var t: Tuning = game.tuning
	var busy: Array[int] = game.training_heroes()
	var away: Array = game.planted.duplicate()  # planted or in a series: not free to train
	away.append_array(game.series.get("lineup", []))
	var trainees := []
	var candidates := []
	for id in s.heroes.size():
		var hero: HeroState = s.heroes[id]
		var needed := Roster.xp_needed(hero.level, t)
		var fighter := {"id": id, "name": game.hero_defs[id].display_name, "portrait": HeroPortraits.portrait(id),
				"detail": "Lv %d  %s" % [hero.level, "MAX" if needed == 0 else "XP %d/%d" % [hero.xp, needed]]}
		if id in busy:
			trainees.append(fighter)
		elif hero.owned and needed > 0 and id not in away:
			candidates.append(fighter)
	training.show_training(game.building_level(GYM) > 0, game.training_slots(), trainees, candidates)


func _fit() -> void:
	var ps := _parent_size()
	panel_size = Vector2(minf(MAX_WIDTH, ps.x - 2.0 * margin), minf(MAX_HEIGHT, ps.y - 2.0 * margin))


func _on_parent_resized() -> void:
	if is_open:
		_fit()
		size = panel_size
		_snap()
