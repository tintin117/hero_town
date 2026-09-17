extends Node

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"): get_tree().quit(1); return
	call_deferred("run_checks")

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	point = get_viewport().get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func run_checks() -> void:
	var c = load("res://game/previews/companion_preview.tscn").instantiate()
	get_tree().root.add_child(c)
	await get_tree().process_frame
	c.set_process(false)
	check(not GameState.persistence_enabled and not c.persistence_enabled, "both save systems disabled in preview")
	check(c.land_views.size() <= 4, "only nearby land scenes loaded")
	check(c.land_views[0].get_node("GoldSpot").visible, "home farmland visible")
	check(c.follow_frontier and c.game.simulation.living_class("warrior") == 1, "opening shows the starter fight")
	check(c.guide_step() == 0, "guide begins with farming")
	c.jump_frontier()
	c.get_node("HUD/Bar/Farm").pressed.emit()
	check(c.scroll_offset == 0 and c.popup_kind == "farm", "Farm shortcut returns to selected farmland")
	for tower in c.get_node("Settlement/TownDistrict/Towers").get_children():
		check(tower.get_node("HitTarget").get_theme_stylebox("normal") is StyleBoxEmpty, "tower interaction target preserves visible art")
	c.open_panel("farm")
	await get_tree().process_frame
	var farm: Control = c.get_node("ManagementPanel/Farm")
	check(farm.visible, "farm panel opens")
	await click(farm.get_node("Gold/Assign"))
	farm.get_node("Gold/Assign").pressed.emit()
	farm.get_node("Wood/Assign").pressed.emit()
	farm.get_node("Wood/Assign").pressed.emit()
	check(c.game.idle_farmers() == 0 and c.game.rates.gold > 0 and c.game.rates.wood > 0, "UI assignments drive both real incomes")
	check(farm.get_node("Gold/Assign").disabled, "assignment controls reflect idle capacity")
	check(c.land_views[0].get_node("GoldSpot").workers.size() == 2, "worker visuals match assignment")
	check(c.guide_step() == 1, "guide moves to a Warrior upgrade after both resources produce")
	for resource in ["GoldSpot", "WoodSpot"]:
		var spot = c.land_views[0].get_node(resource)
		check(spot.get_node("WorkPlaces").get_child_count() == 5 and spot.has_node("Deposit7"), "natural deposits with separate worker positions " + resource)
		spot.clock = 6.0
		spot._process(0.0)
		check(spot.workers[0].position.distance_to(spot.get_node("Dropoff").position) < spot.work_position(0).distance_to(spot.get_node("Dropoff").position), "worker carries resources toward camp " + resource)
	var gold: float = c.game.s.gold
	c._process(0.2)
	check(c.game.s.gold > gold and c.popup.visible, "panels do not pause farming")
	c.close_panel()
	c.jump_frontier()
	check(c.follow_frontier and c.scroll_offset > 0, "frontline navigation")
	var warrior_target: Control = c.get_node("Settlement/TownDistrict/Towers/Warrior/HitTarget")
	check(Rect2(Vector2.ZERO, Vector2(c.view_width, c.COMPACT_HEIGHT)).encloses(warrior_target.get_global_rect()), "first tower remains visible in narrow frontline view")
	await click(warrior_target)
	await get_tree().process_frame
	check(c.popup_kind == "tower" and c.selected_class == "warrior", "click tower opens its management")
	c.get_node("ManagementPanel/Tower/Build").pressed.emit()
	check(c.game.s.towers.has("warrior"), "tower button constructs")
	c.game.s.gold = 100000.0
	c.get_node("ManagementPanel/Tower/Recruit").pressed.emit()
	check(c.game.simulation.living_class("warrior") == 2, "buy button adds reinforcement to starter")
	check(c.get_node("ManagementPanel/Tower/Recruit").disabled, "recruit UI shows cooldown")
	c.game.s.gold = 100000.0
	c.game.s.wood = 100000.0
	c.open_panel("research")
	await get_tree().process_frame
	var research = c.get_node("ManagementPanel/Research")
	for id in ["monk", "archer", "lancer"]:
		c.open_panel("research")
		await click(research.get_node("Graph/" + id.capitalize() + "/Unlock"))
		check(research.selected_class == id and research.selected_skill == "unlock", "graph selects branch " + id)
		await click(research.get_node("Detail/Buy"))
		check(c.game.s.research[id].unlocked, "research unlock " + id)
		c.get_node("Settlement/TownDistrict/Towers/" + id.capitalize() + "/HitTarget").pressed.emit()
		c.get_node("ManagementPanel/Tower/Build").pressed.emit()
		c.get_node("ManagementPanel/Tower/Recruit").pressed.emit()
		check(c.game.simulation.living_class(id) == 1, "selected tower button uses " + id)
	c.open_panel("research")
	await click(research.get_node("Graph/Archer/Power"))
	await click(research.get_node("Detail/Buy"))
	check(c.game.s.research.archer.power == 1, "research button applies upgrade")
	check(research.get_node("Detail/Level").text.contains("1 → 2"), "selected detail shows next rank")
	for button in research.buttons:
		check(research.get_node("Graph").get_global_rect().encloses(button.get_global_rect()), "skill icon remains inside graph " + str(button.get_path()))
		for other in research.buttons:
			if button != other: check(not button.get_global_rect().intersects(other.get_global_rect()), "skill icons do not overlap")
	check(c.popup.get_theme_stylebox("panel").texture.resource_path.contains("farm_paper"), "panel uses pack parchment")
	check(research.get_node("Detail/Buy").get_theme_stylebox("normal").texture.resource_path.contains("Tiny Swords"), "action uses original pack button")
	check(research.get_node("Detail/Buy").get_theme_stylebox("disabled").texture != research.get_node("Detail/Buy").get_theme_stylebox("normal").texture, "unavailable action has a distinct pack state")
	c.game.s.gold = 0
	research.select_skill("warrior", "health")
	check(research.get_node("Detail/Buy").disabled and research.get_node("Detail/Hint").text.contains("Not enough"), "detail explains unaffordable upgrade")
	c.game.s.gold = 100000.0
	c.game.purchase("upgrade", "warrior", "power")
	c.game.hire_farmer()
	check(c.guide_step() == 2, "guide keeps the new farmer assignment visible")
	c.game.assign_farmer(0, "gold", 1)
	check(c.guide_step() == 3, "guide advances after the hired farmer is assigned")
	for kind in ["farm", "tower", "research"]:
		c.open_panel(kind)
		await get_tree().process_frame
		check(Rect2(Vector2.ZERO, Vector2(c.view_width, c.EXPANDED_HEIGHT)).encloses(c.popup.get_rect()), kind + " panel fits window")
		for button in c.panel_buttons:
			if button.is_visible_in_tree(): check(c.popup.get_global_rect().encloses(button.get_global_rect()), kind + " action fits panel " + str(button.name))
	c.close_panel()
	c.sync_units(0.1)
	check(c.unit_views.size() == 6, "all heroes and opening enemy rendered")
	var saved_scroll: float = c.scroll_offset
	c.minimize_to_sparring()
	check(c.taskbar_mode and c.sparring.visible and not c.settlement.visible, "folded view")
	gold = c.game.s.gold
	var elapsed: float = c.game.simulation.elapsed
	for i in 10: c._process(0.2)
	check(c.game.s.gold > gold and c.game.simulation.elapsed > elapsed, "folding continues both economy and combat")
	c.restore_town()
	check(not c.taskbar_mode and c.settlement.visible and c.scroll_offset == saved_scroll, "restore preserves navigation")
	c.jump_frontier()
	c.game.simulation.tower().hp = 0
	c._process(0.1)
	check(c.game.s.owned == 1 and c.follow_frontier, "frontline follows conquest")
	check(c.game.s.towers.size() == 4 and c.game.simulation.alive_count(0) == 5, "all towers and survivors relocate")
	c.select_land(0)
	var farm_scroll: float = c.scroll_offset
	c.game.simulation.tower().hp = 0
	c._process(0.1)
	check(c.scroll_offset == farm_scroll, "conquest does not interrupt farm view")
	c.game.s.owned = 1000
	c.land_width = 1002 * c.land_span
	c.jump_frontier()
	await get_tree().process_frame
	check(c.land_views.size() <= 4 and absf(c.district.position.x) <= c.land_span * 3, "far frontier uses bounded scenes and local coordinates")
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		check(window.transparent and window.transparent_bg and window.borderless, "native transparent borderless window")
		check(Rect2i(usable).encloses(Rect2i(window.position, window.size)), "compact fits actual monitor")
		check(window.position.y + window.size.y == usable.end.y, "docked above taskbar")
		check(not Geometry2D.is_point_in_polygon(Vector2(1, 1), window.mouse_passthrough_polygon), "empty corner passes through")
		check(Geometry2D.is_point_in_polygon(Vector2(80, 200) * c.scale_factor, window.mouse_passthrough_polygon), "HUD receives clicks")
		c.open_panel("research")
		await get_tree().process_frame
		check(Rect2i(usable).encloses(Rect2i(window.position, window.size)), "expanded fits actual monitor")
		await RenderingServer.frame_post_draw
		# Inspect framebuffer alpha in memory; do not create screenshots.
		var pixels := window.get_texture().get_image()
		var graph: Control = research.get_node("Graph")
		var transparent := 0
		for y in range(20, 290, 20):
			for x in range(20, 570, 20):
				var point: Vector2 = (graph.global_position + Vector2(x, y)) * c.scale_factor
				if pixels.get_pixelv(Vector2i(point)).a < 0.99: transparent += 1
		check(transparent == 0, "wood graph nine-slice has no transparent holes")
		c.close_panel()
		c.minimize_to_sparring()
		var start: Vector2i = window.position
		c.begin_taskbar_drag(start)
		c.move_taskbar_drag(start - Vector2i(90, 0))
		c.end_taskbar_drag()
		check(c.taskbar_mode and window.position.x < start.x, "folded drag stays folded")
		c.restore_town()
		await get_tree().process_frame
		check(Rect2i(usable).encloses(Rect2i(window.position, window.size)), "restored window stays on monitor")
	get_tree().root.remove_child(c)
	c.free()
	print("FARM FIGHT UI: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	get_tree().quit(1 if failures else 0)
