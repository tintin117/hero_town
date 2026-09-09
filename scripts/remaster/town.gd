extends Node2D
@export var arrow_scene:= preload("res://scenes/arrow.tscn")
const HUD_SCRIPT = preload("res://scripts/remaster/town_hud.gd")
const UNIT_VIEW = preload("res://scripts/remaster/unit_view.gd")
const BUILDING_VIEW = preload("res://scripts/remaster/town_building.gd")
const WINDOW_SCRIPT = preload("res://scripts/remaster/desktop_window.gd")
const DIRECTOR_SCRIPT = preload("res://scripts/remaster/battle_director.gd")

var director: BattleDirector
var desktop: DesktopWindow
var hud: Control
var camera: Camera2D
var building_views: Dictionary = {}
var unit_views: Dictionary = {}
var idle_units: Array[Dictionary] = []
var placement_type: String = ""
var move_id: String = ""
var hover_cell := Vector2i(-1, -1)
var selected_id: String = ""
var _visual_clock: float = 0.0
var _effect_time: float = 0.0
var _sound_time: float = 0.0
var _landscape: int = -1

var _tracked_shots: Array = []
var _active_arrows: Array = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("203f49"))
	_build_terrain()
	camera = Camera2D.new()
	add_child(camera)
	desktop = WINDOW_SCRIPT.new()
	add_child(desktop)
	director = DIRECTOR_SCRIPT.new()
	director.name = "BattleDirector"
	add_child(director)
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	hud = HUD_SCRIPT.new()
	hud.town = self
	canvas.add_child(hud)
	director.battle_started.connect(_battle_started)
	director.preparation_started.connect(_prepare_visuals)
	director.combat_events.connect(_combat_events)
	GameState.buildings_changed.connect(_sync_buildings)
	GameState.research_changed.connect(_research_changed)
	GameState.settings_changed.connect(_refresh_landscape)
	get_viewport().size_changed.connect(_fit_camera)
	_sync_buildings()
	_fit_camera()
	var music := AudioStreamPlayer.new()
	music.stream = preload("res://asset/audio/background/Moonlight market.mp3")
	music.volume_db = -15
	music.finished.connect(music.play)
	add_child(music)
	music.add_to_group("remaster_audio")
	if DisplayServer.get_name() != "headless": music.play()
	if not GameState.offline_summary.is_empty() and GameState.offline_summary.get("gold", 0) > 0:
		hud.show_offline.call_deferred(GameState.offline_summary.duplicate())
		GameState.offline_summary.clear()

func _refresh_landscape() -> void:
	if _landscape == int(GameState.settings.landscape): return
	var previous := get_node_or_null("Scenery")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	_build_terrain()

func _build_terrain() -> void:
	_landscape = int(GameState.settings.landscape)
	var scenery := preload("res://scripts/remaster/scenery.gd").new()
	scenery.name = "Scenery"
	add_child(scenery)

func _add_prop(texture: Texture2D, at: Vector2, scale_factor: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.offset.y = -texture.get_height() * 0.5
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = at
	sprite.z_index = int(at.y) + 190
	add_child(sprite)

func _fit_camera() -> void:
	if camera == null: return
	var viewport_size := get_viewport_rect().size
	var zoom_value := minf((viewport_size.x - 40) / 1320.0, (viewport_size.y - 54) / 390.0)
	camera.zoom = Vector2.ONE * maxf(0.35, minf(2.6, zoom_value))
	camera.position = Vector2(0, -6 + 25.0 / camera.zoom.y)
	desktop.update_mouse_region.call_deferred()

func _sync_buildings() -> void:
	for record in GameState.buildings:
		var view: ArmyBuildingView = building_views.get(record.id)
		if not is_instance_valid(view):
			view = BUILDING_VIEW.new()
			view.record = record
			building_views[record.id] = view
			add_child(view)
		view.record = record
		view.refresh()
	if director.phase != "BATTLE":
		_prepare_visuals()
	else:
		_sync_waiting_recruits()

func _research_changed(_id: String) -> void:
	for view: ArmyBuildingView in building_views.values(): view.refresh()
	if director.phase == "PREPARE": _prepare_visuals()
	elif director.phase == "BATTLE": _sync_waiting_recruits()

func _clear_units() -> void:
	for view in unit_views.values():
		if is_instance_valid(view): view.free()
	unit_views.clear()

func _prepare_visuals() -> void:
	_clear_units()
	idle_units = BattleSimulation.army_units(GameState.buildings)
	for unit in idle_units: _spawn_view(unit, "home_%s_%d" % [unit.army, unit.member])

func _spawn_view(unit: Dictionary, key: String) -> void:
	if unit_views.has(key): return
	var view := UNIT_VIEW.new()
	view.model = unit
	if key.begins_with("waiting_"): view.modulate = Color(0.7,0.9,1.0,0.75)
	unit_views[key] = view
	add_child(view)

func _battle_started() -> void:
	_clear_units()
	idle_units.clear()
	for unit in director.simulation.units: _spawn_view(unit, str(unit.id))

func _combat_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event.kind == "hit":
			var target_view: ArmyUnitView = unit_views.get(str(event.unit))
			if target_view != null: target_view.flash_remaining = 0.09
			if _sound_time > 0.22:
				_sound_time = 0
				sfx.play("hit")
		if event.kind == "spawn":
			_spawn_view(director.simulation.find_unit(int(event.unit)), str(event.unit))
		elif event.kind in ["heal", "guard", "blast"] and _effect_time > 0.12:
			_effect_time = 0
			if not GameState.settings.reduced_effects:
				fx.spawn("pickup_sparkle" if event.kind == "heal" else "shockwave", event.position,
					{"size": 0.35, "color_main": Color("9edf9c") if event.kind == "heal" else Color("f3c77d")})
		elif event.kind == "hit" and _effect_time > 0.18 and not GameState.settings.reduced_effects:
			_effect_time = 0
			fx.spawn("impact_spark", event.position + Vector2(0, -50), {"size": 0.2})

func _process(delta: float) -> void:
	_visual_clock += delta
	_effect_time += delta
	_sound_time += delta
	var battle_time: float = director.simulation.elapsed if director.simulation != null else 0.0
	for view: ArmyUnitView in unit_views.values(): view.update_view(delta, battle_time)
	queue_redraw()

func begin_placement(type: String) -> void:
	placement_type = type
	move_id = ""
	hud.close_panel(false)
	desktop.open_overlay()
	hud.toast("Choose a town tile. Right-click or Escape to cancel.")

func begin_move(instance_id: String) -> void:
	move_id = instance_id
	placement_type = ""
	hud.close_panel(false)
	desktop.open_overlay()
	hud.toast("Move this building to a free tile. Formation changes next round.")

func cancel_placement() -> void:
	placement_type = ""
	move_id = ""
	desktop.close_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()
		hud.close_panel()
	if event is InputEventMouseMotion:
		hover_cell = TownRules.world_cell(get_viewport().get_canvas_transform().affine_inverse() * event.position)
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_placement()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	var point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	hover_cell = TownRules.world_cell(point)
	if not placement_type.is_empty() or not move_id.is_empty():
		var response: Dictionary = GameState.place_building(placement_type, hover_cell) if move_id.is_empty() else GameState.move_building(move_id, hover_cell)
		if response.ok:
			selected_id = response.get("id", move_id)
			var recruited := move_id.is_empty()
			sfx.play("place")
			cancel_placement()
			var record := GameState.get_building(selected_id)
			hud.toast(("%d recruits ready · join next battle" % TownRules.crew(record,GameData.BUILDINGS[record.type])) if recruited else "Deployment moved · applies next battle")
		else:
			hud.toast(response.message)
			sfx.play("error")
		return
	var views := building_views.values()
	views.sort_custom(func(a, b): return a.position.y > b.position.y)
	for view: ArmyBuildingView in views:
		if view.hit_test(point):
			selected_id = view.record.id
			hud.open_research(selected_id)
			return

func _draw() -> void:
	for slot in TownRules.capacity(GameState.cleared_stage):
		draw_circle(Vector2(-564 + slot * 8, 28), 3, Color("f3cf7b") if slot < GameState.buildings.size() else Color("617e68"))
	_draw_deployment()
	if not placement_type.is_empty() or not move_id.is_empty():
		for x in TownRules.GRID_SIZE.x:
			for y in TownRules.GRID_SIZE.y:
				var cell := Vector2i(x, y)
				var free := GameState.cell_free(cell, move_id)
				draw_rect(Rect2(TownRules.cell_position(cell) - Vector2(30, 30), Vector2(60, 60)), Color(0.85, 0.95, 0.8, 0.35 if free else 0.1), false)
		if TownRules.cell_valid(hover_cell):
			var valid := GameState.cell_free(hover_cell, move_id)
			draw_rect(Rect2(TownRules.cell_position(hover_cell) - Vector2(30, 30), Vector2(60, 60)), Color(0.4, 1, 0.6, 0.5) if valid else Color(1, 0.4, 0.3, 0.5))
	if director == null or director.simulation == null or director.phase != "BATTLE": return
	for shot in director.simulation.projectiles:
		#var target := director.simulation.find_unit(int(shot.target))
		#if target.is_empty(): continue
		#var direction: Vector2 = (target.position - shot.position).normalized()
		#var pos: Vector2 = shot.position + Vector2(0, -18)
		#draw_line(pos - direction * 13, pos, Color("ffe3a5") if shot.side == 0 else Color("ff9e7f"), 3)
		#draw_circle(pos, 3, Color("fff3cd"))
		var target := director.simulation.find_unit(int(shot.target))
		if target.is_empty():
			continue
		if _tracked_shots.any(func(s): return is_same(s, shot)):
			continue

		var arrow := arrow_scene.instantiate()
		add_child(arrow)
		var color := Color("54b2f9ff") if shot.side == 0 else Color("ff9e7f")
		arrow.setup(shot.position, target.position, color)

		_tracked_shots.append(shot)
		_active_arrows.append(arrow)

	# untrack shots that no longer exist in the simulation
	for i in range(_tracked_shots.size() - 1, -1, -1):
		var still_present := director.simulation.projectiles.any(func(s): return is_same(s, _tracked_shots[i]))
		if not still_present:
			_tracked_shots.remove_at(i)
			_active_arrows.remove_at(i)
	for warning in director.simulation.warnings:
		var alpha: float = 0.3 + 0.2 * sin(_visual_clock * 18)
		if warning.kind == "charge":
			draw_line(warning.start, warning.position, Color(1, 0.35, 0.15, alpha), 32)
		else:
			draw_circle(warning.position, warning.radius, Color(1, 0.35, 0.15, alpha))
			draw_arc(warning.position, warning.radius, 0, TAU, 36, Color("ffe3a5"), 2)

func _sync_waiting_recruits() -> void:
	for key in unit_views.keys():
		if str(key).begins_with("waiting_"):
			unit_views[key].queue_free()
			unit_views.erase(key)
	var deployed := {}
	for unit in director.simulation.units:
		if unit.side == 0: deployed[unit.army] = int(deployed.get(unit.army,0)) + 1
	for record in GameState.buildings:
		for unit in BattleSimulation.army_units([record]):
			if unit.member >= int(deployed.get(record.id,0)):
				_spawn_view(unit,"waiting_%s_%d" % [record.id,unit.member])

func _draw_deployment() -> void:
	var record: Dictionary = {}
	if not move_id.is_empty(): record = GameState.get_building(move_id).duplicate(true)
	elif not placement_type.is_empty(): record = {"id":"preview", "type":placement_type,"cell":[0,0],"research":{}}
	elif GameState.reorganizing and not selected_id.is_empty(): record = GameState.get_building(selected_id).duplicate(true)
	if record.is_empty(): return
	if not move_id.is_empty() or not placement_type.is_empty():
		if not TownRules.cell_valid(hover_cell): return
		record.cell = [hover_cell.x,hover_cell.y]
	var origin := TownRules.cell_position(Vector2i(record.cell[0],record.cell[1]))
	var color := Color("b1e9d4")
	for unit in BattleSimulation.army_units([record]):
		draw_circle(unit.position,7,color,false,2)
		draw_line(unit.position,unit.position + Vector2(16,0),color,1)
	draw_line(origin + Vector2(48,0),origin + Vector2(100,0),color,2)
	draw_line(origin + Vector2(100,0),origin + Vector2(90,-6),color,2)
	draw_line(origin + Vector2(100,0),origin + Vector2(90,6),color,2)
