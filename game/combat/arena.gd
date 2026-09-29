extends Node2D
## The fighting pit: ring, seating wings, crowd and fighters. It only replays a fight that
## Game already simulated: fighters follow Game.fight.result.tracks at Game.fight.clock and
## Events.combat_event drives attacks, hits and numbers. It never changes game state.
##
## Town: instance at the ArenaSlot. Size SIZE (512x256), origin = top-left corner, no other setup.
## API: fighter_count(), is_fighting(), signal celebration_finished.
## Tests may assign `game` before adding the node; otherwise the /root/Game autoload is used.

signal celebration_finished

const GameScript := preload("res://game/core/game.gd")
const FighterScript := preload("res://game/combat/fighter.gd")
const FighterScene := preload("res://game/combat/fighter.tscn")
const SIZE := Vector2(512, 256)
const CENTER := Vector2(256, 140)  # ring centre
const RADII := Vector2(150, 84)  # ring half-size in pixels: sim radius 260 maps onto this ellipse
const SIM_RADIUS := 260.0
const START_RADIUS := 0.72  # idle fighters stand where the sim starts them
const CELEBRATE_TIME := 3.0
const NAME_TIME := 2.5  # names show when a fight starts, then only the bars remain
const CROWD_POLL := 0.25  # seat upgrades emit no signal, so the idle crowd is re-read on a timer

var game: GameScript
var _fighters := {}  # hero id -> fighter
var _tracks := {}  # hero id -> PackedVector2Array of the fight on screen (kept during the celebration)
var _fighting := false
var _celebrate_left := 0.0
var _poll := 0.0
@onready var _crowd: Node2D = $Crowd
@onready var _fighters_node: Node2D = $Fighters
@onready var _fx: Node2D = $Fx


func _ready() -> void:
	if game == null:
		game = get_node_or_null("/root/Game") as GameScript
	if game == null:
		push_warning("Arena: no Game found, showing nothing")
		set_process(false)
		return
	game.events.fight_started.connect(_on_fight_started)
	game.events.combat_event.connect(_on_combat_event)
	game.events.fight_finished.connect(_on_fight_finished)
	game.events.roster_changed.connect(_on_roster_changed)
	_fx.bounds = Rect2(Vector2.ZERO, SIZE)
	_show_idle()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("5f7d47"))
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("344b43"), false, 2.0)
	# Pixel-art ring: 2 px scanlines so the ellipse matches the 2x Sunnyside art.
	_ellipse(RADII + Vector2(8, 8), Vector2(0, 8), Color("344b43"))
	_ellipse(RADII + Vector2(8, 8), Vector2.ZERO, Color("8a988a"))
	_ellipse(RADII + Vector2(4, 4), Vector2.ZERO, Color("59685f"))
	_ellipse(RADII, Vector2.ZERO, Color("e2bf80"))
	_ellipse(RADII - Vector2(10, 6), Vector2.ZERO, Color("d4ae73"))
	for i in 40:  # sand specks
		var at := CENTER + Vector2.from_angle(i * 2.399) * sqrt(i / 40.0) * RADII * 0.92
		draw_rect(Rect2(at.snapped(Vector2(2, 2)), Vector2(4 if i % 4 == 0 else 2, 2)), Color("bb955f") if i % 3 == 0 else Color("efcf94"))


func _ellipse(radii: Vector2, offset: Vector2, color: Color) -> void:
	for y in range(-int(radii.y), int(radii.y), 2):
		var half := floorf(radii.x * sqrt(maxf(0.0, 1.0 - pow((y + 1.0) / radii.y, 2.0))) / 2.0) * 2.0
		draw_rect(Rect2(CENTER + offset + Vector2(-half, y), Vector2(half * 2.0, 2)), color)


func fighter_count() -> int:
	return _fighters.size()


func is_fighting() -> bool:
	return _fighting


func _process(delta: float) -> void:
	if _fighting and game.fight.is_empty():  # new_game / continue_game cut the fight short
		_fighting = false
		_show_idle()
	if _celebrate_left > 0.0:
		_celebrate_left -= delta
		if _celebrate_left <= 0.0:
			celebration_finished.emit()
			_show_idle()
	_poll += delta
	if _poll >= CROWD_POLL and not _fighting and _celebrate_left <= 0.0:
		_poll = 0.0
		_refresh_crowd()
	_place_fighters()


# --- scene state ----------------------------------------------------------------------------

func _show_idle() -> void:
	_clear()
	var lineup: Array[int] = game.state.preferred_lineup
	for slot in lineup.size():
		_add_fighter(lineup[slot], 1, false, _start_ground(slot, lineup.size()))
	_refresh_crowd()
	_place_fighters()


func _clear() -> void:
	_tracks = {}
	_celebrate_left = 0.0
	for fighter: FighterScript in _fighters.values():
		_fighters_node.remove_child(fighter)
		fighter.queue_free()
	_fighters.clear()
	_fx.clear()


func _add_fighter(id: int, health: int, bar: bool, ground: Vector2) -> void:
	var def: HeroDef = game.hero_defs[id]
	var fighter := FighterScene.instantiate() as FighterScript
	_fighters_node.add_child(fighter)
	fighter.setup(id, def.unit, def.red, def.display_name, health)
	fighter.show_bar = bar
	fighter.name_left = NAME_TIME if bar else INF
	fighter.position = _project(ground)
	_fighters[id] = fighter


func _refresh_crowd() -> void:
	var seats := Roster.seats(game.state, game.tuning)
	_crowd.set_seats(seats)
	_crowd.set_attendance(game.attendance_if_booked_now(), seats)


func _place_fighters() -> void:
	var step := int(roundf(game.fight.clock * 60.0)) if _fighting else 1 << 30
	for id: int in _fighters:
		var fighter: FighterScript = _fighters[id]
		var speed := 0.0
		var look := 0.0
		var pos := fighter.position
		if _tracks.has(id):
			var track: PackedVector2Array = _tracks[id]
			var at := clampi(step, 0, track.size() - 1)
			var moved := track[at] - track[maxi(at - 1, 0)]
			speed = moved.length() * 60.0
			look = moved.x if speed > FighterScript.WALK_ABOVE else _nearest_dx(fighter)
			pos = _project(track[at])
		else:
			look = CENTER.x - fighter.position.x if fighter.position.x != CENTER.x else 0.0
		fighter.move(pos, speed, look)


func _nearest_dx(fighter: FighterScript) -> float:
	var best := INF
	var dx := 0.0
	for other: FighterScript in _fighters.values():
		var distance := fighter.position.distance_squared_to(other.position)
		if other != fighter and not other.dead and distance < best:
			best = distance
			dx = other.position.x - fighter.position.x
	return dx


func _start_ground(slot: int, count: int) -> Vector2:
	return Vector2.from_angle(-PI / 2.0 + TAU * slot / maxi(1, count)) * SIM_RADIUS * START_RADIUS


func _project(ground: Vector2) -> Vector2:
	return CENTER + ground * (RADII / SIM_RADIUS)


# --- events ---------------------------------------------------------------------------------

func _on_roster_changed() -> void:
	if not _fighting and _celebrate_left <= 0.0:
		_show_idle()


func _on_fight_started(info: Dictionary) -> void:
	_clear()
	_fighting = true
	_tracks = game.fight.get("result", {}).get("tracks", {})
	var health := _max_health(game.fight.get("events", []), game.fight.get("result", {}).get("hp_left", {}))
	var lineup: Array = info.lineup
	for slot in lineup.size():
		_add_fighter(lineup[slot], health.get(lineup[slot], 1), true, _start_ground(slot, lineup.size()))
	_crowd.set_seats(info.seats)
	_crowd.set_attendance(info.attendance, info.seats)
	_place_fighters()


## Full HP of each fighter, recovered from the replay (hp_left + damage taken - healing done).
func _max_health(events: Array, hp_left: Dictionary) -> Dictionary:
	var health := hp_left.duplicate()
	for event: Dictionary in events:
		if health.has(event.get("attacker")):
			health[event.attacker] -= int(event.get("healing", 0))
		for hit: Dictionary in event.get("hits", []):
			if health.has(hit.target):
				health[hit.target] += int(hit.damage)
	return health


func _on_combat_event(event: Dictionary) -> void:
	var caster: FighterScript = _fighters.get(event.attacker)
	if not _fighting or caster == null:
		return
	var kind := String(event.kind)
	if kind == "move":
		_fx.dust(caster.position)
		return
	var skill := kind == "skill"
	var hits: Array = event.hits
	var origin := _project(event.origin)
	var aim := _project(hits[0].position) if not hits.is_empty() else origin
	caster.attack(aim.x - origin.x)
	for hit: Dictionary in hits:
		_apply_hit(hit, skill)
	if int(event.healing) > 0:
		caster.heal(event.healing)
		_fx.text("+%d" % event.healing, caster.position + Vector2(0, -68), _fx.GREEN, 16)
	if not skill:
		return
	var def: HeroDef = game.hero_defs[event.attacker]
	_crowd.cheer(1.0)
	_fx.text(def.skill.name, caster.position + Vector2(0, -84), _fx.GOLD, 16)
	if int(event.tip) > 0:
		_fx.text("+%d" % event.tip, caster.position + Vector2(0, -100), _fx.GOLD, 16)
	_fx.skill(def.skill.kind, caster.position, aim, float(event.radius) * RADII / SIM_RADIUS)


func _apply_hit(hit: Dictionary, skill: bool) -> void:
	var victim: FighterScript = _fighters.get(hit.target)
	if victim == null:
		return
	var at := _project(hit.position)
	victim.take_hit(int(hit.damage))
	_fx.hit(at, skill)
	_fx.text(str(hit.damage), at + Vector2(0, -64), _fx.GOLD if skill else _fx.CREAM, 24 if skill else 16)
	if victim.dead:
		_fx.dust(at)


func _on_fight_finished(result: Dictionary) -> void:
	_fighting = false
	_celebrate_left = CELEBRATE_TIME
	var winner: FighterScript = _fighters.get(int(result.get("winner", -1)))
	if winner != null:
		winner.celebrate()
		_fx.sparkle(winner.position)
	_crowd.cheer(2.0)
