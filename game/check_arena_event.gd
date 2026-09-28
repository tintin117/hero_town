extends SceneTree
## godot --headless --path . --script res://game/check_arena_event.gd
## Omit --headless and append -- --capture for 960/1280px screenshots in .godot/.

const Rules := preload("res://game/fight.gd")
const Saves := preload("res://game/save_game.gd")
const DT := 1.0 / 60.0
const SAVE_PATH := "res://.godot/arena-event-check.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 420)
	var ui = load("res://game/main.tscn").instantiate()
	ui.fight.coins = 100000
	ui.fight.intro_seen = true
	ui.fight.rng.seed = 7
	assert(ui.fight.purchase_upgrade("hall", Vector2i(13, 4)))
	assert(ui.fight.purchase_upgrade("training", Vector2i(10, 4)))
	assert(ui.fight.purchase_upgrade("tavern", Vector2i(35, 4)))
	assert(ui.fight.purchase_upgrade("fighters"))
	for id in range(2, 5):
		assert(ui.fight.recruit(id))
	ui.selected.assign([0, 1, 2])
	root.add_child(ui)
	ui.set_physics_process(false)
	await process_frame
	assert(not ui.auto_fight and not ui.fight.active and ui.event_rounds == 0)
	await _check_full_event(ui)
	await _check_booking_and_stop(ui)
	await _check_reload(ui)
	print("PASS: finite arena events, exact rewards/XP, idle management, rebooking, partial stops, menu pause, reload/New Game and 960/1280px layout.")
	quit()


func _finish(ui: Control) -> void:
	assert(ui.fight.active)
	for step in range(7200):
		ui._physics_process(DT)
		if not ui.fight.active:
			return
	assert(false, "A started event round must finish within 120 simulated seconds.")


func _total_xp(hero: Dictionary) -> int:
	var total: int = hero.xp
	for level in range(1, hero.level):
		total += 30 + 20 * (level - 1)
	return total


func _check_full_event(ui: Control) -> void:
	var bank: int = ui.fight.coins
	var spent: int = ui.fight.upgrade_cost("seats")
	var earned := 0
	var progression := {}
	ui.get_node("%Start").pressed.emit()
	assert(ui.auto_fight and ui.fight.active)
	ui.get_node("%EventButton").pressed.emit()
	await _check_layout(ui, "running")
	ui._close_drawers()
	# Spending during a live event must not reduce its earnings report.
	ui._purchase_arena("seats")
	assert(ui.fight.coins == bank - spent)
	for round_index in range(ui.EVENT_ROUNDS):
		var before := {}
		for id in ui.fight.participants:
			before[id] = _total_xp(ui.fight.heroes[id])
			if not progression.has(id):
				progression[id] = {"xp": 0, "before": ui.fight.heroes[id].level}
		_finish(ui)
		earned += ui.fight.settled_income + ui.fight.crowd_tips + ui.fight.settled_tavern
		for id in ui.fight.participants:
			progression[id].xp += _total_xp(ui.fight.heroes[id]) - before[id]
		assert(ui.event_rounds == round_index + 1 and ui.event_gold == earned)
		assert(ui.event_progression == progression, "Only XP awarded by event fights belongs in the report.")
		if round_index + 1 == ui.EVENT_ROUNDS:
			break
		if round_index == 0:
			# A past participant can train between rounds; its Gym XP is separate.
			ui.selected.assign([1, 2, 3])
			assert(ui.fight.training_assign(0, ui.selected))
			var xp_before := _total_xp(ui.fight.heroes[0])
			ui._physics_process(Rules.TRAINING_INTERVAL)
			assert(_total_xp(ui.fight.heroes[0]) == xp_before + Rules.TRAINING_XP)
			assert(ui.event_progression == progression)
		ui._intermission_finished()
		if not ui.fight.active:
			ui._physics_process(Rules.INJURY_DURATION)
		assert(ui.fight.active and ui.auto_fight)
	assert(ui.fight.completed == ui.EVENT_ROUNDS and not ui.auto_fight and not ui.fight.active)
	assert(ui.get_node("%Tick").is_stopped())
	ui.get_node("%EventButton").pressed.emit()
	assert(ui.get_node("%EventDrawer").visible)
	assert(ui.fight.coins == bank - spent + earned and earned > 0)
	var completed: int = ui.fight.completed
	var xp_before := _total_xp(ui.fight.heroes[0])
	ui._physics_process(Rules.INJURY_DURATION)
	assert(_total_xp(ui.fight.heroes[0]) > xp_before, "Gym training continues after the event ends.")
	assert(ui.fight.injury_remaining.all(func(value: float): return value == 0.0))
	ui.fight.auto_fill_owned = true
	ui._toggle_auto_fill()
	ui._intermission_finished()
	ui._try_begin_fight()
	ui._physics_process(30.0)
	assert(not ui.auto_fight and not ui.fight.active and ui.fight.completed == completed)
	assert(ui.event_gold == earned and ui.event_progression == progression)
	# Opening/closing results never grants rewards a second time.
	var snapshot := Saves.snapshot(ui.fight, ui.selected)
	for repeat in range(3):
		ui._close_drawers()
		ui.get_node("%EventButton").pressed.emit()
		assert(ui.get_node("%EventDrawer").visible)
	assert(Saves.snapshot(ui.fight, ui.selected) == snapshot)
	await _check_layout(ui, "complete")
	ui.get_node("%ManageEventHeroes").pressed.emit()
	assert(ui.get_node("%HeroesDrawer").visible and not ui.get_node("%EventDrawer").visible)
	ui._close_drawers()
	assert(ui.fight.training_recall(0))
	ui.fight.auto_fill_enabled = false


func _check_booking_and_stop(ui: Control) -> void:
	var selected: Array = ui.selected.duplicate()
	ui.get_node("%Start").pressed.emit()
	assert(ui.auto_fight and ui.fight.active and ui.selected == selected)
	assert(ui.event_rounds == 0 and ui.event_gold == 0 and ui.event_progression.is_empty())
	_finish(ui)
	assert(ui.event_rounds == 1 and not ui.get_node("%Tick").is_stopped())
	ui.get_node("%Start").pressed.emit()
	assert(not ui.auto_fight and ui.get_node("%Tick").is_stopped())
	assert(ui.event_rounds == 1 and not ui.get_node("%EventButton").disabled)
	ui._intermission_finished()
	ui._physics_process(Rules.INJURY_DURATION)
	assert(not ui.fight.active)
	# Stop during combat finishes that round, without beginning another one.
	ui.get_node("%Start").pressed.emit()
	assert(ui.fight.active and ui.event_rounds == 0)
	ui.get_node("%Start").pressed.emit()
	assert(not ui.auto_fight and ui.fight.active and ui.get_node("%Start").disabled)
	_finish(ui)
	assert(ui.event_rounds == 1 and not ui.auto_fight and ui.get_node("%Tick").is_stopped())
	ui.get_node("%EventButton").pressed.emit()
	await _check_layout(ui, "stopped")
	# Cancel an event waiting for its first available lineup.
	ui._physics_process(Rules.INJURY_DURATION)
	ui.fight.heroes[1].stamina = 0
	ui.fight.rest_remaining[1] = 60.0
	ui.get_node("%Start").pressed.emit()
	assert(ui.auto_fight and not ui.fight.active and ui.event_rounds == 0)
	ui.get_node("%Start").pressed.emit()
	ui._physics_process(60.0)
	assert(not ui.auto_fight and not ui.fight.active and ui.event_rounds == 0)
	# The menu pauses the same booking; Continue does not reset its counters.
	ui.get_node("%Start").pressed.emit()
	_finish(ui)
	ui._open_main_menu()
	var snapshot := Saves.snapshot(ui.fight, ui.selected)
	var earnings: int = ui.event_gold
	ui._physics_process(Rules.INJURY_DURATION)
	ui._process(31.0)
	ui._try_begin_fight()
	assert(ui.auto_fight and ui.event_rounds == 1 and ui.event_gold == earnings)
	assert(Saves.snapshot(ui.fight, ui.selected) == snapshot and ui.get_node("%Tick").paused)
	ui._continue_game()
	ui._intermission_finished()
	if not ui.fight.active:
		ui._physics_process(Rules.INJURY_DURATION)
	assert(ui.fight.active and ui.event_rounds == 1 and not ui.get_node("%Tick").paused)


func _check_reload(ui: Control) -> void:
	var snapshot := Saves.snapshot(ui.fight, ui.selected)
	assert(Saves.save_game(ui.fight, ui.selected, SAVE_PATH) == OK)
	ui.queue_free()
	await process_frame
	var loaded = load("res://game/main.tscn").instantiate()
	loaded.save_path = SAVE_PATH
	loaded.tree_entered.connect(func(): current_scene = loaded)
	root.add_child(loaded)
	loaded.set_physics_process(false)
	await process_frame
	assert(loaded.in_main_menu and loaded.has_saved_game)
	assert(Saves.snapshot(loaded.fight, loaded.selected) == snapshot)
	loaded.get_node("%ContinueGame").pressed.emit()
	loaded._physics_process(Rules.INJURY_DURATION)
	loaded._intermission_finished()
	assert(not loaded.auto_fight and not loaded.fight.active and loaded.event_rounds == 0)
	assert(loaded.event_gold == 0 and loaded.event_progression.is_empty())
	loaded.get_node("%Start").pressed.emit()
	_finish(loaded)
	assert(loaded.event_rounds == 1 and loaded.event_gold > 0)
	loaded._start_new_game()
	assert(not loaded.auto_fight and not loaded.fight.active and loaded.event_rounds == 0)
	assert(loaded.event_gold == 0 and loaded.event_progression.is_empty())
	assert(not loaded.get_node("%EventDrawer").visible and loaded.fight.completed == 0)
	loaded.queue_free()
	await process_frame


func _check_layout(ui: Control, label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.9).timeout
	for window_size in [Vector2i(960, 420), Vector2i(1280, 420)]:
		root.size = window_size
		await process_frame
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(window_size))
		for node_name in ["Footer", "Start", "EventButton", "EventDrawer", "EventTitle", "EventSummary", "EventHeroes", "CloseEvent", "ManageEventHeroes"]:
			assert(viewport_rect.encloses(ui.get_node("%" + node_name).get_global_rect()), "Event UI spills outside window: " + node_name)
		if label == "complete":
			var scroll: ScrollContainer = ui.get_node("%EventHeroes").get_parent()
			var bar := scroll.get_v_scroll_bar()
			assert(bar.focus_mode == Control.FOCUS_ALL and bar.max_value > bar.page)
			bar.grab_focus()
			var key := InputEventKey.new()
			key.keycode = KEY_DOWN
			key.pressed = true
			root.push_input(key)
			key = key.duplicate()
			key.pressed = false
			root.push_input(key)
			await process_frame
			assert(scroll.scroll_vertical > 0 and root.gui_get_focus_owner() == bar, "Keyboard users must be able to scroll through every event participant.")
			scroll.scroll_vertical = 0
			ui.get_node("%CloseEvent").grab_focus()
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://.godot/arena-event-%s-%d.png" % [label, window_size.x]) == OK)
	root.size = Vector2i(1280, 420)
