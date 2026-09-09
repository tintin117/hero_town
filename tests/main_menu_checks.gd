extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	menu.companion_save_path = "res://.godot/menu-check-save.json"
	root.add_child(menu)
	await process_frame
	var sizing = load("res://scripts/presentation_scale.gd")
	assert(root.size.x == sizing.window_width(root))
	assert(root.content_scale_size == Vector2i(1920, 1080))
	assert(sizing.width_for_area(Vector2i(1920, 1040)) == 1280)
	assert(sizing.width_for_area(Vector2i(1024, 600)) <= 992)
	assert(sizing.width_for_area(Vector2i(800, 480)) * 9.0 / 16.0 <= 448)
	var rules = load("res://conquest/conquest_state.gd").new()
	rules.s.warriors = 17
	rules.s.owned = 2
	assert(rules.save_game(menu.companion_save_path))
	assert(menu.create_fresh_save())
	var fresh = load("res://conquest/conquest_state.gd").new()
	fresh.load_game(menu.companion_save_path)
	assert(fresh.s.warriors == 3 and fresh.s.owned == 0 and fresh.s.projects.is_empty())
	var previous = JSON.parse_string(FileAccess.get_file_as_string(menu.companion_save_path + ".previous"))
	assert(previous.warriors == 17 and previous.owned == 2)
	var level = menu.companion_scene.instantiate()
	var custom_balance = level.balance.duplicate(true)
	custom_balance.starting_gold = 321
	custom_balance.starting_warriors = 6
	level.balance = custom_balance
	var custom_scene := PackedScene.new()
	assert(custom_scene.pack(level) == OK)
	level.free()
	menu.companion_scene = custom_scene
	assert(menu.create_fresh_save())
	fresh.load_game(menu.companion_save_path)
	assert(fresh.s.gold == 321 and fresh.s.warriors == 6)
	assert(root.transparent and root.transparent_bg and root.borderless)
	assert(not menu.get_node("MainMenuScene/water").visible)
	assert(not menu.get_node("MainMenuScene/foam_water").visible)
	assert(menu.get_node("front_ui/Layout/PlayButton/RichTextLabel").text == "Resume")
	assert(menu.get_node("front_ui/Layout/CompactButton/RichTextLabel").text == "New Game")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		assert(capture.get_pixel(0, 0).a == 0.0)
		capture.save_png("res://.godot/menu-transparent.png")
	DirAccess.remove_absolute(menu.companion_save_path)
	DirAccess.remove_absolute(menu.companion_save_path + ".previous")
	menu.queue_free()
	print("MAIN MENU CHECKS PASSED: fresh state, backup, labels, transparent framebuffer")
	quit()
