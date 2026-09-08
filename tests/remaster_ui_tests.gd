extends Node

var town: Node2D
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI TEST: " + message)

func frames(count: int = 3) -> void:
	for i in count: await get_tree().process_frame

func click_world(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var screen: Vector2 = town.get_viewport().get_canvas_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await frames()
	var event := InputEventMouseButton.new()
	event.position = screen
	event.global_position = screen
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		get_tree().quit(1)
		return
	GameState.persistence_enabled = false
	GameState.gold = 100000
	GameState.cleared_stage = 20
	GameState.farm_stage = 19
	for index in 5:
		GameState.place_building(TownRules.ARMY_TYPES[index % 4], Vector2i(2 + index / 3, index % 3))
	town = preload("res://scenes/town_2d.tscn").instantiate()
	get_tree().root.add_child.call_deferred(town)
	await frames()
	get_tree().current_scene = town
	town.director.set_physics_process(false)
	var hud: Control = town.hud
	for size_now in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 260), Vector2i(800, 260)]:
		get_tree().root.size = size_now
		await frames()
		if hud.top.get_rect().end.x > size_now.x + 1:
			print("HUD overflow ", hud.top.get_rect(), " min ", hud.top.get_combined_minimum_size())
			for child in hud.top.get_child(0).get_children():
				print(child.get_class(), " ", child.get("text"), " ", child.size, " min ", child.get_combined_minimum_size())
		check(hud.top.get_rect().end.x <= size_now.x + 1, "Top bar fits %s" % size_now)
		check(hud.bottom.get_rect().end.y <= size_now.y + 1, "Bottom bar fits %s" % size_now)
		check(hud.top.get_rect().end.y < hud.bottom.position.y, "HUD leaves battlefield visible")
		if size_now.y < 500: continue # Native expansion is checked separately on Windows.
		for kind in ["build", "research", "options", "report"]:
			match kind:
				"build": hud.open_build()
				"research": hud.open_research("army_005")
				"options": hud.open_options()
				"report": hud.open_report()
			await frames()
			check(hud.panel.get_rect().position.x >= 0 and hud.panel.get_rect().position.y >= 0, "%s panel inside viewport" % kind)
			check(hud.panel.get_rect().end.x <= size_now.x + 1 and hud.panel.get_rect().end.y <= size_now.y + 1, "%s panel fits %s" % [kind, size_now])
			for control: Node in hud.content.find_children("*", "Button", true, false):
				check(control.size.x >= control.get_minimum_size().x, "Buttons respect minimum width")
			hud.close_panel()
	get_tree().root.size = Vector2i(1280, 720)
	await frames()
	for scale_factor in [1.0, 1.25, 1.5]:
		get_tree().root.size = Vector2i(1920, 1080)
		get_tree().root.content_scale_factor = scale_factor
		await frames()
		var logical_size: Vector2 = hud.get_viewport_rect().size
		check(hud.top.get_rect().end.x <= logical_size.x + 1, "HUD fits logical scaling %.2f" % scale_factor)
		hud.open_research("army_005")
		await frames()
		check(hud.panel.get_rect().end.x <= logical_size.x + 1 and hud.panel.get_rect().end.y <= logical_size.y + 1, "Research fits logical scaling %.2f" % scale_factor)
		hud.close_panel()
	get_tree().root.content_scale_factor = 1
	get_tree().root.size = Vector2i(1280, 720)
	await frames()
	var count_before: int = GameState.buildings.size()
	var gold_before: int = GameState.gold
	town.begin_placement("barracks")
	await click_world(TownRules.cell_position(Vector2i(2, 0)))
	check(GameState.buildings.size() == count_before and GameState.gold == gold_before, "Occupied placement click changes no state")
	await click_world(TownRules.cell_position(Vector2i(7, 2)))
	check(GameState.buildings.size() == count_before + 1 and GameState.gold == gold_before - 100, "Mouse placement uses transformed viewport coordinates")
	town.begin_placement("barracks")
	await click_world(Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	check(town.placement_type.is_empty() and GameState.buildings.size() == count_before + 1, "Right click cancels placement")
	hud.open_research("army_005")
	check(hud.selected_army == "army_005", "Duplicate barracks selects exact instance")
	GameState.purchase_research("army_005", "damage_1")
	check(not GameState.get_building("army_001").research.has("damage_1"), "Research stays on selected duplicate")
	hud.close_panel()
	town.director.start_now()
	var before: int = town.director.simulation.alive_count(0)
	var first_unit: Dictionary = town.director.simulation.units[0]
	var damage_before: float = first_unit.damage
	GameState.purchase_research("army_001", "damage_1")
	GameState.purchase_research("army_001", "crew_1")
	GameState.move_building("army_001", Vector2i(6, 2))
	GameState.place_building("barracks", Vector2i(6, 0))
	check(town.director.simulation.alive_count(0) == before, "New crews/buildings do not join mid-battle")
	check(first_unit.damage == damage_before, "Research cannot alter the battle snapshot")
	check(not GameState.refund_research("army_001").ok, "Mid-battle refund rejected")
	for i in 2200:
		if town.director.phase != "BATTLE": break
		town.director.advance(0.05)
	check(town.director.phase == "RESULTS", "Round finishes in integration")
	town.director.advance(5.1)
	check(town.director.phase == "PREPARE", "Results return to preparation")
	check(town.idle_units.size() == before + 4, "Next preparation adds new recruits and army")
	check(town.idle_units[0].hp == town.idle_units[0].max_hp, "Army fully recovers")
	check(town.idle_units[0].damage > damage_before, "Pending research applied next round")
	check(town.idle_units[0].home.x > first_unit.home.x, "Moved building updates next formation")
	print("UI TESTS: %d checks, %d failures" % [checks, failures])
	GameState.request_quit(1 if failures else 0)
