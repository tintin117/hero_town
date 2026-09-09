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
	var menu: Node2D = load("res://scenes/main_menu_scene.tscn").instantiate()
	check(terrain.get_node("Ground").tile_set == menu.get_node("ground_1").tile_set,"menu and companion share terrain definitions")
	menu.free()
	for layer in terrain.get_children():
		check(not layer.get_used_cells().is_empty(),str(layer.name)+" has painted terrain")
	check(root.size == Vector2i(960,220),"compact dimensions")
	check(root.transparent and root.transparent_bg and root.borderless,"native transparency and borderless")
	check(not Geometry2D.is_point_in_polygon(Vector2(1,1),root.mouse_passthrough_polygon),"empty outer area excluded")
	check(Geometry2D.is_point_in_polygon(Vector2(80,200),root.mouse_passthrough_polygon),"gold control included")
	var usable := DisplayServer.screen_get_usable_rect(root.current_screen)
	check(Rect2i(usable).encloses(Rect2i(root.position,root.size)),"inside actual work area")
	check(root.position.y+root.size.y == usable.end.y,"docked above taskbar")
	for kind in ["home","barracks","academy","army","frontier","ledger"]:
		c.open_panel(kind)
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO,Vector2(960,500)).encloses(c.popup.get_rect()),kind+" popup inside window")
		var end: float = c.popup_body.position.y+c.popup_body.size.y
		var limit := 250.0
		for b in c.panel_buttons: limit=minf(limit,b.position.y)
		check(end<=limit,kind+" text does not overlap actions")
		c.close_panel()
		check(root.size==Vector2i(960,220),kind+" closes to compact")
	c.perform("warriors")
	check(c.game.s.projects.has("barracks"),"chosen project starts")
	var army_before: int = c.game.s.warriors
	c.perform("deploy")
	var remaining: float = c.game.s.projects.barracks.remaining
	var gold_before: float = c.game.s.gold
	await create_timer(0.3).timeout
	check(is_equal_approx(c.game.s.projects.barracks.remaining,remaining),"project pauses during battle")
	check(c.game.s.gold>gold_before,"battle income continues")
	check(c.activity.barracks.text.begins_with("II "),"generic paused indicator")
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
	c.game.s.projects.barracks.remaining=0.05
	await create_timer(0.15).timeout
	check(c.game.s.warriors==army_before+2 and c.game.s.projects.is_empty(),"completion joins automatically once")
	check(c.summary!="","return/report remains available")
	root.remove_child(c)
	c.free()
	DirAccess.remove_absolute("res://conquest/companion-check-save.json")
	print("COMPANION CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
