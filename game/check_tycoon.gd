extends SceneTree
## --headless --path . --script res://game/check_tycoon.gd [-- --economy]
const Rules := preload("res://game/fight.gd")
const Saves := preload("res://game/save_game.gd")
const DT := 1.0 / 60.0
const CELLS := {"training": Vector2i(10, 4), "hall": Vector2i(13, 4), "infirmary": Vector2i(32, 4), "tavern": Vector2i(35, 4)}


func _initialize() -> void:
	_run.call_deferred()


func _finish(fight: RefCounted) -> void:
	var count := 0
	while fight.active and count < 7200:
		fight.advance(DT)
		count += 1
	assert(not fight.active and fight.survivors().size() == 1, "Match must finish within 120 seconds.")


func _run() -> void:
	if "--economy" in OS.get_cmdline_user_args() or "--opening" in OS.get_cmdline_user_args():
		var on_target := true
		for seed_value in [7, 42, 123]:
			if not _economy(seed_value):
				on_target = false
		quit(0 if on_target else 1)
		return
	_check_progression()
	_check_roster_matchups()
	_check_land()
	_check_saves()
	await _check_ui()
	await _check_main_menu()
	print("PASS: tycoon progression, owned land, save recovery, UI purchases, automation, and five-fighter presentation.")
	quit()


func _check_progression() -> void:
	var fight := Rules.new()
	assert(fight.heroes.size() == 8 and fight.owned_count() == 3 and fight.max_stamina() == 10)
	assert(not fight.start([0, 1, 3]) and not fight.recruit(3))
	for bout in range(10):
		assert(fight.start([0, 1, 2]))
		_finish(fight)
		for id in [0, 1, 2]:
			assert(fight.heroes[id].stamina == 9 - bout)
			assert(fight.rest_remaining[id] == (120.0 if bout == 9 else 0.0))
	assert(not fight.start([0, 1, 2]))
	var bank := fight.coins
	for bad in [-1.0, 0.0, INF, NAN]:
		fight.advance(bad)
		assert(fight.rest_remaining[0] == 120.0)
	fight.coins = 100000000
	assert(fight.purchase_upgrade("training", CELLS.training))
	assert(fight.heroes[0].stamina == 0 and fight.heroes[3].stamina == 15)
	assert(fight.purchase_upgrade("infirmary", CELLS.infirmary))
	assert(fight.rest_remaining[0] == 120.0 and fight.recovery_duration() == 90.0)
	fight.advance(119.5)
	assert(fight.heroes[0].stamina == 0)
	fight.advance(0.5)
	assert(fight.heroes[0].stamina == 15 and fight.ready(0))
	assert(fight.purchase_upgrade("hall", CELLS.hall))
	assert(fight.recruit(3) and fight.recruit(4) and not fight.recruit(3) and not fight.recruit(5))
	assert(fight.purchase_upgrade("hall") and fight.recruit(5))
	assert(fight.purchase_upgrade("hall") and fight.recruit(6) and fight.recruit(7))
	assert(fight.owned_count() == 8 and not fight.purchase_upgrade("hall"))
	assert(fight.next_lineup([0, 1, 2]) == [0, 1, 2])
	assert(fight.purchase_upgrade("auto") and fight.auto_fill_enabled)
	fight.heroes[0].stamina = 0
	fight.rest_remaining[0] = 2.0
	fight.heroes[3].stamina = 8
	assert(fight.next_lineup([0, 1, 2]) == [1, 2, 4])
	assert(fight.purchase_upgrade("fighters"))
	assert(fight.next_lineup([0, 1, 2]) == [1, 2, 4, 5])
	assert(fight.purchase_upgrade("fighters") and not fight.purchase_upgrade("fighters"))
	assert(fight.next_lineup([0, 1, 2]) == [1, 2, 4, 5, 6])
	fight.advance(2.0)
	for count in [3, 4, 5]:
		var lineup: Array[int] = []
		for id in range(count):
			lineup.append(id)
		fight.rng.seed = count
		assert(fight.start(lineup))
		var unique: Dictionary = {}
		for pos in fight.positions.values():
			unique[pos] = true
		assert(unique.size() == count)
		_finish(fight)
	assert(fight.purchase_upgrade("tavern", CELLS.tavern))
	assert(fight.start([0, 1, 2, 3, 4]))
	var quote := fight.payout
	bank = fight.coins
	assert(fight.purchase_upgrade("tavern") and fight.purchase_upgrade("seats"))
	assert(fight.payout == quote and fight.tavern_payout == 100)
	bank = fight.coins
	_finish(fight)
	assert(fight.settled_tavern == 100 and fight.coins == bank + fight.crowd_tips + fight.settled_income + 100)
	bank = fight.coins
	fight.advance(3.0)
	assert(fight.coins == bank)
	fight.heroes[0].wins = 50
	quote = fight.income_for([0, 1, 2])
	fight.heroes[0].wins = 5000
	assert(fight.income_for([0, 1, 2]) == quote and fight.heroes[0].wins == 5000)
	# Every ready bench hero may rotate; fewer than three means wait, never a partial invalid match.
	for id in range(6):
		fight.heroes[id].stamina = 0
		fight.rest_remaining[id] = 90.0
	assert(fight.next_lineup([0, 1, 2]) == [6, 7] and not fight.start([6, 7]))
	fight.auto_fill_enabled = false
	assert(fight.next_lineup([0, 1, 2]) == [0, 1, 2])
	print("PASS: tenth-fight injury, recovery, upgrades, eight recruits, Auto-fill, 3–5 fighters, Tavern snapshots, and win cap.")
	# Recruited mirror healers must not stall the entire unattended economy.
	fight = Rules.new()
	fight.heroes[3].owned = true
	fight.heroes[7].owned = true
	assert(fight.start([0, 3, 7]))
	fight.health[0] = 0
	fight.positions[3] = Vector2.ZERO
	fight.positions[7] = Vector2(40, 0)
	assert(fight.overtime_multiplier() == 1.0)
	_finish(fight)
	assert(fight.elapsed > 60.0 and fight.elapsed < 120.0)


func _check_land() -> void:
	var fight := Rules.new()
	fight.coins = 1000000000
	assert(fight.grid.buildings.is_empty())
	for id in CELLS:
		var bank := fight.coins
		for cell in [Vector2i(0, 0), Vector2i(9, 3), Vector2i(37, 3), Vector2i(38, 3), Vector2i(16, 0), Vector2i(10, 6)]:
			assert(not fight.purchase_upgrade(id, cell) and fight.coins == bank)
		assert(fight.purchase_upgrade(id, CELLS[id]))
	assert(fight.grid.buildings.size() == 4)
	assert(not fight.grid.try_move("tavern", Vector2i(38, 3)))
	assert(not fight.grid.try_move("tavern", CELLS.hall))
	assert(fight.grid.try_move("tavern", Vector2i(35, 0)))
	assert(not fight.purchase_upgrade("land"))
	for step in Rules.MILESTONES:
		while step[0] != "recruit" and fight.upgrade_level(step[0]) < step[1]:
			assert(fight.purchase_upgrade(step[0]))
		if step[0] == "recruit":
			assert(fight.recruit(step[1]))
	assert(fight.next_milestone().is_empty())
	# Buying recruits out of the suggested order must not strand the objective at a full Hall.
	fight = Rules.new()
	fight.coins = 10000000
	assert(fight.purchase_upgrade("tavern", CELLS.tavern) and fight.purchase_upgrade("training", CELLS.training))
	assert(fight.purchase_upgrade("hall", CELLS.hall))
	assert(fight.recruit(6) and fight.recruit(7))
	assert(fight.next_milestone().id == "hall" and fight.next_milestone().target == 2)
	print("PASS: all four buildings fit; ownership, overlap, duplicate/capped purchases, and outer-land exclusion.")


func _check_roster_matchups() -> void:
	var matches := 0
	var longest := 0.0
	for mask in range(256):
		var lineup: Array[int] = []
		for id in range(8):
			if mask & (1 << id):
				lineup.append(id)
		if lineup.size() < 3 or lineup.size() > 5:
			continue
		for seed_value in [7, 42]:
			var fight := Rules.new()
			fight.rng.seed = seed_value
			fight.fighter_tier = lineup.size() - 3
			for id in range(8):
				fight.heroes[id].owned = true
				fight.heroes[id].level = 10 if seed_value == 7 else 1 + (id % 3) * 4
			assert(fight.start(lineup))
			_finish(fight)
			longest = maxf(longest, fight.elapsed)
			matches += 1
	print("PASS: %d matches across every 3–5 hero combination, max/mixed levels, longest %.2fs." % [matches, longest])


func _check_saves() -> void:
	var fight := Rules.new()
	fight.coins = 1000000
	assert(fight.purchase_upgrade("hall", CELLS.hall) and fight.recruit(3))
	assert(fight.purchase_upgrade("auto"))
	fight.heroes[3].stamina = 0
	fight.rest_remaining[3] = 65.5
	var selected: Array[int] = [0, 1, 2]
	var data := Saves.snapshot(fight, selected)
	var decoded := Saves.decode(JSON.parse_string(JSON.stringify(data)))
	assert(not decoded.is_empty() and Saves.snapshot(decoded.fight, decoded.selected) == data)
	assert(not decoded.fight.intro_seen)
	var legacy := data.duplicate(true)
	legacy.erase("intro_seen")
	assert(Saves.decode(legacy).fight.intro_seen, "Existing estates skip the welcome without losing progress.")
	legacy = Saves.snapshot(Rules.new(), selected)
	legacy.erase("intro_seen")
	assert(not Saves.decode(legacy).fight.intro_seen)
	legacy.intro_seen = "yes"
	assert(Saves.decode(legacy).is_empty())
	fight.intro_seen = true
	assert(Saves.decode(Saves.snapshot(fight, selected)).fight.intro_seen)
	for key in ["gold", "fighters", "seats"]:
		var invalid := data.duplicate(true)
		invalid[key] = -1
		assert(Saves.decode(invalid).is_empty())
	var invalid := data.duplicate(true)
	invalid.cells.hall = [38, 3]
	assert(Saves.decode(invalid).is_empty())
	invalid = data.duplicate(true)
	invalid.heroes[0].stamina = 0
	assert(Saves.decode(invalid).is_empty())
	invalid = data.duplicate(true)
	invalid.heroes[0].level = 11
	assert(Saves.decode(invalid).is_empty())
	invalid = data.duplicate(true)
	invalid.selected = [0, 0, 1]
	assert(Saves.decode(invalid).is_empty())
	assert(fight.start(selected))
	fight.coins += 10 # Already-paid tips survive; transient combat never does.
	decoded = Saves.decode(Saves.snapshot(fight, selected))
	assert(not decoded.fight.active and decoded.fight.coins == fight.coins and decoded.fight.completed == 0)
	assert(decoded.fight.rest_remaining[3] == 65.5 and decoded.fight.settled_income == 0)
	var path := "res://.godot/tycoon-save-check.json"
	assert(Saves.save_game(fight, selected, path) == OK)
	fight.coins += 7
	assert(Saves.save_game(fight, selected, path) == OK)
	assert(Saves.load_game(path).fight.coins == fight.coins)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("interrupted/corrupt save")
	file.close()
	decoded = Saves.load_game(path)
	assert(decoded.recovered and decoded.fight.coins == fight.coins - 7)
	assert(Saves.save_game(fight, selected, path) == OK)
	assert(Saves.load_game(path).fight.coins == fight.coins)
	assert(FileAccess.get_file_as_string(path + ".corrupt") == "interrupted/corrupt save")
	print("PASS: validated save round-trip, frozen recovery, interrupted fight, invalid data, and backup recovery.")


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/tycoon-%s.png" % label) == OK)


func _check_ui() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 420)
	var ui = load("res://game/main.tscn").instantiate()
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(not ui.saving_enabled and ui.cards.size() == 8 and ui.fight.owned_count() == 3)
	assert(ui.get_node("%World").building_nodes.is_empty())
	assert(ui.welcome.visible and "FIRST:" in ui.objective.text)
	assert(not ui._world_input_allowed(Vector2(900, 280)))
	await _capture("welcome")
	root.size = Vector2i(960, 420)
	await process_frame
	await process_frame
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(ui.welcome_start.get_global_rect()))
	await _capture("welcome-960")
	root.size = Vector2i(1280, 420)
	ui._dismiss_welcome()
	assert(ui.fight.intro_seen and not ui.welcome.visible and ui.fight.coins == 0)
	await _capture("start")
	ui._open_objective()
	assert(ui.fight.active and "Watch your first fight" in ui.objective.text)
	ui._toggle_running()
	while ui.fight.active:
		ui._physics_process(DT)
	assert(ui.fight.coins >= Rules.BUILDING_COSTS.tavern[0] and "build a Tavern" in ui.objective.text)
	ui._open_objective()
	assert(ui.build_drawer.visible and "+100 gold per fight" in ui.build_rows.tavern.info.text)
	await _capture("first-purchase")
	var first_bank: int = ui.fight.coins
	ui._building_purchase("tavern")
	var preview_cell: Vector2i = ui.get_node("%World").preview_cell
	assert(ui.fight.grid.can_place("tavern", preview_cell))
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(ui.get_node("%World").global_position + ui.get_node("%World").point_for_cell(preview_cell)))
	await _capture("first-placement")
	ui._set_arranging(false)
	assert(ui.fight.coins == first_bank and ui.fight.grid.buildings.is_empty())
	ui._close_drawers()
	ui.fight.coins = 100000000
	ui._refresh()
	ui.build_button.pressed.emit()
	assert(ui.build_drawer.visible)
	await _capture("build")
	ui._building_purchase("hall")
	var bank: int = ui.fight.coins
	assert(ui.get_node("%World").constructing)
	ui._construct("hall", Vector2i(38, 3))
	assert(ui.fight.coins == bank)
	ui.get_node("%World").cancel_placement()
	assert(ui.fight.coins == bank)
	ui._building_purchase("hall")
	ui._construct("hall", CELLS.hall)
	assert(ui.fight.coins == bank - Rules.BUILDING_COSTS.hall[0])
	ui.cards[3].pressed.emit()
	ui.cards[4].pressed.emit()
	assert(ui.fight.owned_count() == 5 and ui.selected == [0, 1, 2])
	ui._building_purchase("hall")
	ui.cards[5].pressed.emit()
	assert(ui.fight.owned_count() == 6)
	for id in ui.selected:
		ui.fight.heroes[id].stamina = 0
		ui.fight.rest_remaining[id] = 90.0
	ui.auto_fight = true
	ui._refresh()
	assert(ui._needs_rotation() and "book rested heroes" in ui.objective.text)
	ui._open_objective()
	assert(ui.get_node("%HeroesDrawer").visible and not ui.rotate_button.disabled)
	await _capture("rotation")
	ui.rotate_button.pressed.emit()
	assert(ui.selected == [3, 4, 5] and not ui.auto_fight and not ui.fight.active)
	assert(ui.fight.rest_remaining[0] == 90.0 and "Rested heroes booked" in ui.get_node("%Status").text)
	ui.fight.advance(90.0)
	ui.selected.assign([0, 1, 2])
	ui._close_drawers()
	for id in ["training", "infirmary", "tavern"]:
		ui._building_purchase(id)
		ui._construct(id, CELLS[id])
	ui._purchase_arena("fighters")
	ui._purchase_arena("fighters")
	ui._purchase_arena("auto")
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and ui.fight.participants == [0, 1, 2, 3, 4] and ui.fighters.size() == 5)
	ui._book_rested()
	assert(ui.selected == [0, 1, 2] and ui.auto_fight and ui.fight.participants == [0, 1, 2, 3, 4])
	ui._open_building("tavern")
	ui._building_purchase("tavern")
	assert(ui.fight.tavern_payout == 100 and ui.build_drawer.visible)
	for i in range(240):
		ui._physics_process(DT)
	await _capture("five-fighters-build")
	ui._close_drawers()
	ui.get_node("%HeroesButton").pressed.emit()
	await _capture("heroes")
	ui._close_drawers()
	for size in [Vector2i(960, 420), Vector2i(1280, 420), Vector2i(1600, 560)]:
		root.size = size
		await process_frame
		await process_frame
		for node in [ui.get_node("%Start"), ui.build_button, ui.objective]:
			assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(node.get_global_rect()))
		await _capture("estate-%d" % size.x)
		ui.get_node("%ArenaButton").pressed.emit()
		await process_frame
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(ui.get_node("%ArenaDrawer").get_global_rect()))
		await _capture("arena-%d" % size.x)
		ui._close_drawers()
		ui.build_button.pressed.emit()
		await process_frame
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(ui.build_drawer.get_global_rect()))
		await _capture("build-%d" % size.x)
		ui._close_drawers()
	# Save through the real controller without touching the player's profile.
	ui.saving_enabled = true
	ui.save_path = "res://.godot/tycoon-ui-save.json"
	ui._save()
	assert(ui.save_message.is_empty())
	var saved := Saves.load_game(ui.save_path)
	assert(saved.fight.coins == ui.fight.coins and saved.fight.grid.buildings == ui.fight.grid.buildings)
	assert(saved.fight.auto_fill_enabled and not saved.fight.active)
	bank = ui.fight.coins
	ui.fight.coins = -1 # Invalid state cannot overwrite a valid save or close away unsaved progress.
	ui._notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
	assert("Save failed" in ui.save_message and Saves.load_game(ui.save_path).fight.coins == bank)
	ui.fight.coins = bank
	assert(ui._save())
	ui.saving_enabled = false
	if "--capture" in OS.get_cmdline_user_args():
		var before: float = ui.fight.elapsed
		ui.set_physics_process(true)
		root.mode = Window.MODE_MINIMIZED
		await create_timer(1.5).timeout
		ui.set_physics_process(false)
		root.mode = Window.MODE_WINDOWED
		assert(ui.fight.elapsed > before + 0.5, "Combat must keep running while minimized/unfocused.")
		print("PASS: real window minimized/unfocused; combat and timers kept advancing.")
	ui.get_node("%TownScroll").value = 0.0
	await _capture("outer-land")
	ui.queue_free()
	await process_frame
	# Exercise the startup load path as a main scene, using the isolated test save.
	var restored_ui = load("res://game/main.tscn").instantiate()
	restored_ui.save_path = "res://.godot/tycoon-ui-save.json"
	restored_ui.tree_entered.connect(func(): current_scene = restored_ui)
	root.add_child(restored_ui)
	restored_ui.set_physics_process(false)
	await process_frame
	assert(restored_ui.saving_enabled and not restored_ui.auto_fight and not restored_ui.fight.active)
	assert(restored_ui.fight.coins == bank and restored_ui.fight.auto_fill_enabled)
	assert(restored_ui.fight.owned_count() == 6 and restored_ui.fight.fighter_capacity() == 5)
	assert(restored_ui.fight.intro_seen and not restored_ui.welcome.visible)
	assert(restored_ui.get_node("%World").building_nodes.size() == 4)
	assert(restored_ui.in_main_menu and not restored_ui.session_started and not restored_ui.get_node("%ContinueGame").disabled)
	restored_ui.get_node("%ContinueGame").pressed.emit()
	assert(not restored_ui.in_main_menu and restored_ui.session_started and not restored_ui.fight.active)
	restored_ui.queue_free()
	await process_frame
	print("PASS: main-scene startup restores the estate and preferences with combat stopped.")


func _menu_fixture(path: String) -> Control:
	var ui = load("res://game/main.tscn").instantiate()
	ui.save_path = path
	ui.tree_entered.connect(func(): current_scene = ui)
	root.add_child(ui)
	ui.set_physics_process(false)
	return ui


func _check_main_menu() -> void:
	var path := "res://.godot/menu-check.json"
	var fight := Rules.new()
	fight.coins = 4321
	fight.intro_seen = true
	assert(fight.purchase_upgrade("hall", CELLS.hall) and fight.recruit(3))
	fight.heroes[0].stamina = 0
	fight.rest_remaining[0] = 45.5
	var selected: Array[int] = [0, 1, 2]
	assert(Saves.save_game(fight, selected, path) == OK)
	assert(Saves.save_game(fight, selected, path) == OK)
	# Continue also supports the existing backup recovery path.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt primary")
	file.close()
	var ui = _menu_fixture(path)
	await process_frame
	assert(ui.in_main_menu and not ui.session_started and ui.has_saved_game)
	assert(not ui.get_node("%ContinueGame").disabled and not ui.get_node("HUD").visible)
	assert("Recovered backup" in ui.get_node("%MenuStatus").text)
	var saved_bytes := FileAccess.get_file_as_string(path)
	ui._process(31.0)
	ui._physics_process(30.0)
	assert(ui.fight.rest_remaining[0] == 45.5 and not ui.fight.active)
	assert(FileAccess.get_file_as_string(path) == saved_bytes, "A launch menu must never autosave over an existing estate.")
	for size in [Vector2i(960, 420), Vector2i(1280, 420), Vector2i(1600, 560)]:
		root.size = size
		await process_frame
		await process_frame
		for name in ["MenuPanel", "NewGame", "ContinueGame", "QuitGame"]:
			assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(ui.get_node("%" + name).get_global_rect()))
		await _capture("menu-%d" % size.x)
	ui.get_node("%NewGame").pressed.emit()
	assert(ui.get_node("%NewGameConfirmation").visible)
	await _capture("menu-new-confirm")
	ui.get_node("%NewGameConfirmation").get_cancel_button().pressed.emit()
	await process_frame
	assert(not ui.get_node("%NewGameConfirmation").visible)
	assert(ui.in_main_menu and ui.fight.coins == fight.coins and FileAccess.get_file_as_string(path) == saved_bytes)
	ui.get_node("%ContinueGame").pressed.emit()
	assert(not ui.in_main_menu and ui.session_started and not ui.fight.active and not ui.welcome.visible)
	assert(ui.fight.rest_remaining[0] == 45.5 and ui.fight.owned_count() == 4)
	ui.fight.advance(45.5)
	ui.get_node("%Start").pressed.emit()
	ui._physics_process(DT)
	ui.fight.heroes[3].stamina = 0
	ui.fight.rest_remaining[3] = 65.0
	ui.get_node("%MenuButton").pressed.emit()
	var elapsed: float = ui.fight.elapsed
	var snapshot := Saves.snapshot(ui.fight, ui.selected)
	ui._physics_process(30.0)
	ui._process(31.0)
	ui._try_begin_fight()
	assert(ui.fight.elapsed == elapsed and Saves.snapshot(ui.fight, ui.selected) == snapshot)
	assert(ui.in_main_menu and ui.get_node("%Tick").paused and ui.auto_fight)
	ui.get_node("%ContinueGame").pressed.emit()
	ui._physics_process(DT)
	assert(ui.fight.active and ui.fight.elapsed > elapsed and not ui.get_node("%Tick").paused)
	# A failed save cannot close the game or replace the current session.
	ui.get_node("%MenuButton").pressed.emit()
	var old_fight: RefCounted = ui.fight
	ui.save_path = "res://.godot/missing-menu-folder-%d/save.json" % Time.get_ticks_usec()
	ui._start_new_game()
	assert(ui.fight == old_fight and ui.in_main_menu and "retained" in ui.get_node("%MenuStatus").text)
	ui._quit_game()
	assert("Save failed" in ui.get_node("%MenuStatus").text)
	ui.save_path = path
	ui.get_node("%NewGame").pressed.emit()
	ui.get_node("%NewGameConfirmation").get_ok_button().pressed.emit()
	await process_frame
	assert(not ui.in_main_menu and ui.welcome.visible and not ui.fight.intro_seen)
	assert(ui.fight.coins == 0 and ui.fight.completed == 0 and ui.fight.owned_count() == 3)
	assert(ui.fight.grid.buildings.is_empty() and ui.get_node("%World").building_nodes.is_empty())
	assert(ui.fight.max_stamina() == 10 and ui.selected == [0, 1, 2] and not ui.auto_fight)
	assert(Saves.load_game(path).fight.coins == 0 and not Saves.load_game(path).fight.intro_seen)
	assert(Saves.load_game(path + ".bak").fight.coins == fight.coins)
	ui.queue_free()
	await process_frame
	# No save: Continue is disabled, and New Game goes straight to the welcome.
	var empty_path := "res://.godot/menu-fresh-%d.json" % Time.get_ticks_usec()
	ui = _menu_fixture(empty_path)
	await process_frame
	assert(ui.get_node("%ContinueGame").disabled)
	ui._continue_game()
	assert(ui.in_main_menu and not ui.session_started)
	await _capture("menu-no-save")
	ui.get_node("%NewGame").pressed.emit()
	assert(not ui.in_main_menu and ui.welcome.visible and not ui.get_node("%NewGameConfirmation").visible)
	assert(not Saves.load_game(empty_path).is_empty())
	ui.queue_free()
	await process_frame
	# Quit from an unreadable-save launch menu must leave the file untouched.
	var corrupt_path := "res://.godot/menu-corrupt-%d.json" % Time.get_ticks_usec()
	file = FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("unreadable estate")
	file.close()
	ui = _menu_fixture(corrupt_path)
	assert(ui.get_node("%ContinueGame").disabled and "could not be read" in ui.get_node("%MenuStatus").text)
	ui.get_node("%QuitGame").pressed.emit()
	assert(FileAccess.get_file_as_string(corrupt_path) == "unreadable estate")
	ui.queue_free()
	print("PASS: New Game, canceled replacement, Continue/backup recovery, paused combat/recovery, failed writes, and Quit without overwriting saves.")


func _economy(seed_value: int) -> bool:
	var fight := Rules.new()
	fight.rng.seed = seed_value
	var preferred: Array[int] = [0, 1, 2]
	var seconds := 0.0
	var intermission := 0.0
	var times := {}
	var first_rest := -1.0
	var reserve_count := 0
	var rotations := 0
	var opening_only := "--opening" in OS.get_cmdline_user_args()
	while seconds < 24.0 * 3600.0:
		if opening_only and fight.auto_fill_owned:
			break
		var next := fight.next_milestone()
		if next.is_empty():
			break
		if fight.coins >= next.cost:
			var purchased := fight.recruit(next.target) if next.id == "recruit" else fight.purchase_upgrade(next.id, CELLS.get(next.id, Vector2i(-1, -1)))
			assert(purchased)
			times["%s%d" % [next.id, next.target]] = seconds
			print("ECONOMY seed=%d %s%d at %.2fh / %.1fmin" % [seed_value, next.id, next.target, seconds / 3600.0, seconds / 60.0])
			continue
		if not fight.active:
			if first_rest < 0.0 and fight.lineup_rest(preferred) > 0.0:
				first_rest = seconds
				reserve_count = fight.ready_lineup().size()
			# Follow the same manual rotation prompt as a player until Auto-fill is purchased.
			if not fight.auto_fill_owned and fight.lineup_rest(preferred) > 0.0 and fight.ready_lineup().size() >= 3:
				preferred = fight.ready_lineup()
				rotations += 1
			if intermission > 0.0:
				fight.advance(intermission)
				seconds += intermission
				intermission = 0.0
			if not fight.start(fight.next_lineup(preferred)):
				fight.advance(0.5)
				seconds += 0.5
				continue
		fight.advance(DT)
		if fight.elapsed > 120.0:
			push_error("Stalled economy match: %s" % [fight.participants])
			return false
		seconds += DT
		if not fight.active:
			intermission = 3.0
	print("ECONOMY RESULT seed=%d hours=%.3f fights=%d complete=%s" % [seed_value, seconds / 3600.0, fight.completed, fight.next_milestone().is_empty()])
	var actions := times.values().filter(func(time: float) -> bool: return time <= 600.0).size()
	print("OPENING seed=%d purchases=%d rotations=%d first_rest=%.1fs ready_reserves=%d" % [seed_value, actions, rotations, first_rest, reserve_count])
	var report := FileAccess.open("res://.godot/tycoon-%s-%d.json" % ["opening" if opening_only else "economy", seed_value], FileAccess.WRITE)
	report.store_string(JSON.stringify({"seed": seed_value, "hours": seconds / 3600.0, "fights": fight.completed, "milestones_seconds": times, "purchases_first_ten_minutes": actions, "manual_rotations": rotations, "first_rest_seconds": first_rest, "ready_reserves_at_first_rest": reserve_count}, "\t"))
	var on_target: bool = times.get("tavern1", 0) > 0 and times.get("tavern1", 0) <= 60
	on_target = on_target and times.get("recruit5", INF) < first_rest and reserve_count >= 3 and rotations > 0
	on_target = on_target and times.get("seats1", 0) >= 5 * 60 and times.get("seats1", 0) <= 8 * 60
	on_target = on_target and times.get("auto1", 0) >= 8 * 60 and times.get("auto1", 0) <= 10 * 60 and actions >= 10
	if not opening_only:
		on_target = on_target and fight.next_milestone().is_empty() and seconds >= 12 * 3600 and seconds <= 18 * 3600
		on_target = on_target and times.get("fighters1", 0) >= 2 * 3600 and times.get("fighters1", 0) <= 3 * 3600
		on_target = on_target and times.get("fighters2", 0) >= 6 * 3600 and times.get("fighters2", 0) <= 8 * 3600
	if not on_target:
		push_error("Economy missed an agreed milestone window.")
	return on_target
