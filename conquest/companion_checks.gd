extends SceneTree
const Companion = preload("res://conquest/companion.tscn")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var c = Companion.instantiate()
	c.save_path = "res://conquest/companion-check-save.json"
	c.seed_from_full_window = false
	c.game.s.owned = 2
	c.game.s.academy = true
	c.game.s.warriors = 7
	c.game.s.mages = 1
	c.game.s.gold = 200.0
	root.add_child(c)
	await process_frame
	var terrain: Node2D = c.settlement.get_node("Terrain")
	check(terrain.get_child_count() == 5,"editable terrain layers present")
	check(c.workers.workers.size() == 3,"wood gold and food workers present")
	check(c.district.position.x == c.DISTRICT_OFFSET and c.formation.get_parent() == c.district,"buildings and army shift together")
	check(c.trainees[0].get_parent() == c.district.get_node("BarracksSite"),"training remains beside moved barracks")
	c.workers.clock = 0
	c.workers._process(0)
	var woodcutter: Dictionary = c.workers.workers[0]
	check(woodcutter.actor.texture == woodcutter.work,"woodcutter uses work animation")
	c.workers.clock = 6
	c.workers._process(0)
	check(woodcutter.actor.texture == woodcutter.carry and woodcutter.actor.position.x > woodcutter.home.x,"worker carries resource toward delivery")
	c.workers.clock = 9
	c.workers._process(0)
	check(woodcutter.actor.texture == woodcutter["return"] and woodcutter.actor.flip_h,"worker returns with tool")
	c.workers.clock = 0
	for layer in terrain.get_children():
		check(not layer.get_used_cells().is_empty(),str(layer.name)+" has painted terrain")
	var expected_width: int = load("res://scripts/presentation_scale.gd").window_width(root)
	var compact_size := Vector2i(roundi(c.view_width * c.scale_factor), roundi(220.0 * expected_width / 960.0))
	check(root.size == compact_size,"shared presentation width and compact height")
	check(root.transparent and root.transparent_bg and root.borderless,"native transparency and borderless")
	check(not Geometry2D.is_point_in_polygon(Vector2(1,1),root.mouse_passthrough_polygon),"empty outer area excluded")
	check(Geometry2D.is_point_in_polygon(Vector2(80,200) * c.scale_factor,root.mouse_passthrough_polygon),"scaled gold control included")
	var usable := DisplayServer.screen_get_usable_rect(root.current_screen)
	check(Rect2i(usable).encloses(Rect2i(root.position,root.size)),"inside actual work area")
	check(root.position.y+root.size.y == usable.end.y,"docked above taskbar")
	check(abs(root.size.x - usable.size.x) <= 2,"town fits monitor width")
	var gold_position: Vector2 = c.gold.get_global_rect().position
	c.scroll_town(99999)
	check(is_equal_approx(c.scroll_offset, c.land_width - c.view_width),"scroll stops at right edge")
	check(c.gold.get_global_rect().position == gold_position,"gold remains fixed while scrolling")
	check(c.settlement.position.x < 0,"land moves horizontally")
	c.open_panel("frontier")
	check(c.popup.position.x >= 0 and c.popup.get_rect().end.x <= c.view_width,"offscreen frontier panel remains accessible")
	c.close_panel()
	c.scroll_town(-999)
	check(c.scroll_offset == 0,"scroll stops at left edge")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	c._input(wheel)
	check(c.scroll_offset > 0,"mouse wheel scrolls the town")
	c.scroll_town(0)
	for kind in ["home","barracks","academy","army","frontier","ledger"]:
		c.open_panel(kind)
		await process_frame
		await process_frame
		check(Rect2i(usable).encloses(Rect2i(root.position, root.size)),kind+" expanded window fits monitor")
		check(Rect2(Vector2.ZERO,Vector2(c.view_width,500)).encloses(c.popup.get_rect()),kind+" popup inside window")
		var end: float = c.popup_body.position.y+c.popup_body.size.y
		var limit := 250.0
		for b in c.panel_buttons: limit=minf(limit,b.position.y)
		check(end<=limit,kind+" text does not overlap actions")
		c.close_panel()
		check(root.size==compact_size,kind+" closes to compact")
	c.perform("warriors")
	check(c.game.s.projects.has("barracks"),"chosen project starts")
	check(c.trainees[0].visible and c.trainees[0].is_playing(),"training starts visible practice")
	var practice_frame: int = c.trainees[0].frame
	await create_timer(0.3).timeout
	check(c.trainees[0].frame != practice_frame,"practice animation advances")
	check(c.activity.barracks.text.begins_with(">> "),"training countdown remains above barracks")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://conquest/companion-training.png")
	var army_before: int = c.game.s.warriors
	c.perform("deploy")
	var seconds_per_step: float = c.game.s.battle.duration / c.game.s.battle.timeline.size()
	c.update_combat_presentation(c.game.s.battle, 0, 0.1 / seconds_per_step)
	check(c.damage_numbers.get_child_count() == 0,"first swing winds up before damage")
	c.update_combat_presentation(c.game.s.battle, 0, 0.21 / seconds_per_step)
	check(c.damage_numbers.get_child_count() > 0,"fast first swing emits small hits")
	for number in c.damage_numbers.get_children():
		check(float(number.get_meta("amount")) >= 1.0 and float(number.get_meta("amount")) <= 2.0,"damage packets are one or two")
	var packets_before: int = c.damage_numbers.get_child_count()
	c.update_combat_presentation(c.game.s.battle, 0, 0.21 / seconds_per_step)
	check(c.damage_numbers.get_child_count() == packets_before,"same swing does not duplicate damage")
	var remaining: float = c.game.s.projects.barracks.remaining
	var gold_before: float = c.game.s.gold
	await create_timer(0.3).timeout
	check(is_equal_approx(c.game.s.projects.barracks.remaining,remaining),"project pauses during battle")
	check(c.game.s.gold>gold_before,"battle income continues")
	check(c.activity.barracks.text.begins_with("II "),"generic paused indicator")
	check(not c.trainees[0].is_playing(),"practice pauses during deployment")
	var number_count: int = c.damage_numbers.get_child_count()
	check(number_count > 0,"combat displays floating damage")
	c.update_combat_presentation(c.game.s.battle, 0, 0.21 / seconds_per_step)
	check(c.damage_numbers.get_child_count() == number_count,"same combat step does not duplicate numbers")
	check(float(c.damage_numbers.get_child(0).get_meta("amount")) <= 2.0,"small damage values stay readable")
	check(c.damage_numbers.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,"damage does not block clicks")
	c.persist()
	var restored = load("res://conquest/conquest_state.gd").new()
	restored.load_game(c.save_path)
	check(is_equal_approx(restored.s.projects.barracks.remaining,remaining),"JSON roundtrip preserves paused progress")
	check(not restored.s.battle.is_empty(),"battle timeline saved")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		check(img.get_pixel(0,0).a==0,"framebuffer alpha corner")
		img.save_png("res://conquest/companion-battle.png")
	c.game.finish_battle()
	await create_timer(0.2).timeout
	check(c.game.s.projects.barracks.remaining<remaining,"project resumes after return")
	check(c.trainees[0].is_playing(),"practice resumes after return")
	c.game.s.projects.barracks.remaining=0.05
	await create_timer(0.15).timeout
	check(c.game.s.warriors==army_before+2 and c.game.s.projects.is_empty(),"completion joins automatically once")
	check(not c.trainees[0].visible,"finished recruits leave practice")
	check(c.summary!="","return/report remains available")
	c.scroll_town(250)
	var saved_scroll: float = c.scroll_offset
	var warriors_before: int = c.game.s.warriors
	var owned_before: int = c.game.s.owned
	c.minimize_to_sparring()
	check(c.taskbar_mode and c.sparring.visible and not c.settlement.visible,"minimize shows sparring and hides town")
	check(root.size == Vector2i(roundi(220*c.scale_factor), roundi(84*c.scale_factor)),"slim taskbar window")
	check(c.sparring.opponent.flip_h and not c.sparring.warrior.flip_h,"sparring warriors face each other")
	check(c.sparring.restore.text == "" and c.sparring.restore.get_theme_stylebox("normal") is StyleBoxEmpty,"characters restore town without a visible button")
	check(root.position.y + root.size.y == usable.end.y,"sparring sits against taskbar edge")
	check(root.position.x + root.size.x == usable.end.x,"sparring sits in right monitor corner")
	var drag_start := root.position + Vector2i(60, 50)
	var original_x := root.position.x
	c.begin_taskbar_drag(drag_start)
	c.move_taskbar_drag(drag_start - Vector2i(120, 0))
	c.end_taskbar_drag()
	check(c.taskbar_mode and root.position.x == original_x - 120,"drag moves sprites without restoring town")
	check(root.position.y + root.size.y == usable.end.y,"drag stays along taskbar edge")
	var chosen_x := root.position.x
	c.restore_town()
	c.minimize_to_sparring()
	check(root.position.x == chosen_x,"minimize remembers chosen position")
	c.begin_taskbar_drag(root.position)
	c.move_taskbar_drag(root.position - Vector2i(99999, 0))
	c.end_taskbar_drag()
	check(root.position.x == usable.position.x,"drag stops at monitor edge")
	check(Rect2i(usable).encloses(Rect2i(root.position,root.size)),"sparring fits work area")
	c.sparring.clock = 1.4
	await create_timer(0.15).timeout
	check(c.sparring.clock > 1.4 and c.sparring.fireball.visible,"sparring animation and fireball advance")
	check(c.game.s.warriors == warriors_before and c.game.s.owned == owned_before,"cosmetic duel does not change army or land")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://conquest/taskbar-sparring.png")
	var original_screen: int = c.taskbar_screen
	c.sparring.restore.pressed.emit()
	check(not c.taskbar_mode and not c.sparring.visible and c.settlement.visible,"restore returns to town")
	check(root.size == compact_size and c.scroll_offset == saved_scroll,"restore preserves width and scroll")
	check(root.current_screen == original_screen,"restore remains on original monitor")
	for attempt in 3:
		c.minimize_to_sparring()
		c.restore_town()
		await process_frame
		check(root.current_screen == original_screen,"repeated restore preserves monitor")
	for screen in DisplayServer.get_screen_count():
		var screen_area := DisplayServer.screen_get_usable_rect(screen)
		root.size = Vector2i(240, 100)
		root.position = screen_area.position + Vector2i(40, 40)
		await process_frame
		c.configure_window()
		c.minimize_to_sparring()
		c.restore_town()
		await process_frame
		check(root.current_screen == screen,"restore preserves tested monitor " + str(screen))
		check(Rect2i(screen_area).encloses(Rect2i(root.position, root.size)),"restored town fits tested monitor " + str(screen))
	root.remove_child(c)
	c.free()
	DirAccess.remove_absolute("res://conquest/companion-check-save.json")
	print("COMPANION CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
