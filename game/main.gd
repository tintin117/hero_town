extends Control

const FightRules := preload("res://game/fight.gd")
const CombatFeedback := preload("res://game/combat_feedback.gd")
const SaveGame := preload("res://game/save_game.gd")
const ART := preload("res://resources/art/unit_library.tres")
const GOLD := Color("f2c771")
const MUTED := Color("a5b2c3")
const INTERMISSION := 3.0
const GROUND_DEPTH := 0.32
const SPECTATOR := preload("res://asset/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Idle.png")

var fight := FightRules.new()
var selected: Array[int] = [0, 1, 2]
var auto_fight := false
var cards: Array[Button] = []
var card_records: Array[Label] = []
var card_details: Array[Dictionary] = []
var fighters: Dictionary = {}
var feedback := CombatFeedback.new()
var excitement_pulse: Tween
var displayed_tier := 0
var cheer := 0.0
var crowd_clock := 0.0
var crowd_tick := 0.0
var panning := false
var town_pointer := Vector2.ZERO
var town_view_width := 0.0
var save_path := SaveGame.DEFAULT_PATH
var saving_enabled := false
var save_elapsed := 0.0
var save_message := ""
var build_button: Button
var build_drawer: PanelContainer
var close_build: Button
var build_rows: Dictionary = {}
var fighter_upgrade: Button
var auto_upgrade: Button
var objective: Button
var tavern_income: Label
var welcome: Control
var welcome_start: Button
var rotate_button: Button
var in_main_menu := false
var session_started := true
var has_saved_game := false


func _ready() -> void:
	# Runtime-only window layout; leave the user's project/editor settings intact.
	if get_tree().current_scene == self:
		saving_enabled = true
		in_main_menu = true
		session_started = false
		var saved := SaveGame.load_game(save_path)
		if not saved.is_empty():
			has_saved_game = true
			fight = saved.fight
			selected = saved.selected
			save_message = "Recovered backup save." if saved.get("recovered", false) else ""
		elif FileAccess.file_exists(save_path):
			save_message = "Save could not be read. Continue is unavailable; previous files are retained."
		get_tree().auto_accept_quit = false
		get_window().content_scale_size = Vector2i.ZERO
		get_window().min_size = Vector2i(960, 420)
		get_window().size = Vector2i(1280, 420)
	%World.grid = fight.grid
	%World.sync_buildings()
	%World.building_clicked.connect(_open_building)
	%World.construction_requested.connect(_construct)
	%World.building_moved.connect(_save)
	%World.move_child(%Stage, -1)
	%TownScroll.value_changed.connect(_scroll_world)
	%CenterArena.pressed.connect(_center_arena)
	%Arrange.toggled.connect(_set_arranging)
	resized.connect(_layout_town)
	_layout_town()
	_center_arena()
	_apply_theme()
	_build_management()
	add_child(feedback)
	feedback.setup(self)
	_build_roster()
	%HeroesButton.pressed.connect(_toggle_drawer.bind(%HeroesDrawer))
	%ArenaButton.pressed.connect(_toggle_drawer.bind(%ArenaDrawer))
	for button in [%CloseHeroes, %CloseArena, %Dismiss]:
		button.pressed.connect(_close_drawers)
	%Start.pressed.connect(_toggle_running)
	%MenuButton.pressed.connect(_open_main_menu)
	%NewGame.pressed.connect(_request_new_game)
	%ContinueGame.pressed.connect(_continue_game)
	%QuitGame.pressed.connect(_quit_game)
	%NewGameConfirmation.confirmed.connect(_start_new_game)
	%Expand.pressed.connect(_expand_arena)
	%Tick.timeout.connect(_intermission_finished)
	%Stage.draw.connect(_draw_ring)
	%Stage.resized.connect(_layout_fighters)
	%Excitement.draw.connect(_draw_excitement_markers)
	_show_fighters(selected)
	_refresh()
	welcome.visible = not fight.intro_seen
	if welcome.visible:
		welcome_start.grab_focus()
	if not save_message.is_empty():
		%Status.text = save_message
		%Status.tooltip_text = save_message
	if in_main_menu:
		_show_main_menu()


func _show_main_menu() -> void:
	in_main_menu = true
	panning = false
	%Tick.paused = true
	$HUD.hide()
	%MainMenu.show()
	%ContinueGame.disabled = not session_started and not has_saved_game
	%MenuStatus.text = "%d gold / %d heroes / %d fights" % [fight.coins, fight.owned_count(), fight.completed] if not %ContinueGame.disabled else "No saved estate to continue."
	if not save_message.is_empty():
		%MenuStatus.text = save_message
	%MenuNote.text = "Game paused / Continue resumes this session" if session_started else "Continue loads your estate with the arena stopped"
	(%NewGame if %ContinueGame.disabled else %ContinueGame).grab_focus()


func _open_main_menu() -> void:
	if in_main_menu or not _save():
		return
	_close_drawers()
	_show_main_menu()


func _continue_game() -> void:
	if not session_started and not has_saved_game:
		return
	session_started = true
	in_main_menu = false
	%MainMenu.hide()
	$HUD.show()
	%Tick.paused = false
	welcome.visible = not fight.intro_seen
	_refresh()
	(welcome_start if welcome.visible else %Start).grab_focus()


func _request_new_game() -> void:
	if session_started or has_saved_game or FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		%NewGameConfirmation.popup_centered(Vector2i(440, 140))
		%NewGameConfirmation.get_cancel_button().grab_focus()
	else:
		_start_new_game()


func _start_new_game() -> void:
	var fresh := FightRules.new()
	var starters: Array[int] = [0, 1, 2]
	if saving_enabled:
		var error := SaveGame.save_game(fresh, starters, save_path)
		if error != OK:
			%MenuStatus.text = "Could not start a new game (%s). Your current estate is retained." % error_string(error)
			return
		has_saved_game = true
	%NewGameConfirmation.hide()
	%Tick.stop()
	auto_fight = false
	_set_arranging(false)
	_close_drawers()
	fight = fresh
	selected = starters
	%World.grid = fight.grid
	%World.sync_buildings()
	_center_arena()
	if excitement_pulse and excitement_pulse.is_valid():
		excitement_pulse.kill()
	%ExcitementMeter.modulate = Color.WHITE
	displayed_tier = 0
	cheer = 0.0
	save_elapsed = 0.0
	save_message = ""
	%Status.text = "Your arena is ready"
	%Status.tooltip_text = ""
	%Commentary.text = "Bram / Ivo / Nia"
	%Commentary.tooltip_text = %Commentary.text
	welcome_start.text = "Start first fight"
	_show_fighters(selected)
	session_started = true
	_continue_game()


func _quit_game() -> void:
	if _save():
		get_tree().quit()
	elif in_main_menu:
		%MenuStatus.text = save_message


func _save() -> bool:
	if not saving_enabled or not session_started:
		return true
	var error := SaveGame.save_game(fight, selected, save_path)
	save_message = "" if error == OK else "Save failed (%s). Progress remains in this session." % error_string(error)
	objective.tooltip_text = save_message if error != OK else "Progress saves automatically. Earning and recovery require the game to be running."
	if error != OK:
		%Status.text = save_message
		%Status.tooltip_text = save_message
	return error == OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and saving_enabled:
		_quit_game()


func _build_management() -> void:
	build_button = Button.new()
	build_button.text = "Build"
	build_button.toggle_mode = true
	%Footer.get_node("Contents").add_child(build_button)
	%Footer.get_node("Contents").move_child(build_button, 2)
	build_drawer = PanelContainer.new()
	build_drawer.name = "BuildDrawer"
	$HUD.add_child(build_drawer)
	build_drawer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	build_drawer.position = Vector2(16, size.y - 410)
	build_drawer.size = Vector2(560, 334)
	build_drawer.add_theme_stylebox_override("panel", _panel(Color("172937"), Color("6e7c7c")))
	build_drawer.hide()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	build_drawer.add_child(list)
	var heading := HBoxContainer.new()
	list.add_child(heading)
	var title := _label("BUILD YOUR ESTATE", 16, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_child(title)
	close_build = Button.new()
	close_build.text = "Close"
	close_build.pressed.connect(_close_drawers)
	heading.add_child(close_build)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	list.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for id in FightRules.TownGrid.BUILDINGS:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var info := _label("", 13)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var button := Button.new()
		button.custom_minimum_size = Vector2(166, 48)
		button.pressed.connect(_building_purchase.bind(id))
		row.add_child(button)
		build_rows[id] = {"info": info, "button": button}
	list.add_child(_label("One of each / move freely with Arrange / outer land is a preview", 11))
	build_button.pressed.connect(_toggle_drawer.bind(build_drawer))
	var upgrades := HBoxContainer.new()
	%ArenaDrawer.get_node("Details").add_child(upgrades)
	fighter_upgrade = Button.new()
	fighter_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fighter_upgrade.pressed.connect(_purchase_arena.bind("fighters"))
	upgrades.add_child(fighter_upgrade)
	auto_upgrade = Button.new()
	auto_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_upgrade.pressed.connect(_toggle_auto_fill)
	upgrades.add_child(auto_upgrade)
	%ArenaDrawer.get_node("Details/Note").hide()
	%Expand.custom_minimum_size.y = 34
	objective = Button.new()
	objective.name = "Objective"
	objective.alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective.add_theme_font_size_override("font_size", 12)
	$HUD.add_child(objective)
	$HUD.move_child(objective, $HUD.get_children().find(%Dismiss))
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective.offset_left = 16
	objective.offset_right = -16
	objective.offset_top = 91
	objective.offset_bottom = 121
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.pressed.connect(_open_objective)
	tavern_income = _label("", 10, Color("acd5bd"))
	%Tips.get_parent().add_child(tavern_income)
	%Tips.get_parent().add_theme_constant_override("separation", 1)
	%Tips.add_theme_font_size_override("font_size", 12)
	%FightIncome.add_theme_font_size_override("font_size", 18)
	%CenterArena.text = "Center"
	%CenterArena.custom_minimum_size.x = 66
	%Arrange.tooltip_text = "Move built structures within your estate. Combat keeps running."
	rotate_button = Button.new()
	rotate_button.text = "Book rested heroes"
	rotate_button.tooltip_text = "Choose the ready heroes with the most stamina. This changes your booking once; Auto-fill handles future fights automatically."
	rotate_button.pressed.connect(_book_rested)
	var roster_heading := %HeroesDrawer.get_node("Details/Heading")
	roster_heading.add_child(rotate_button)
	roster_heading.move_child(rotate_button, 1)
	_build_welcome()


func _build_welcome() -> void:
	var guide := Button.new()
	guide.text = "Guide"
	guide.pressed.connect(func():
		_close_drawers()
		welcome.show()
		welcome_start.text = "Return to arena" if fight.active or auto_fight else ("Start first fight" if fight.completed == 0 else "Open arena")
		welcome_start.grab_focus())
	%Footer.get_node("Contents").add_child(guide)
	%Footer.get_node("Contents").move_child(guide, 5)
	welcome = Control.new()
	welcome.name = "Welcome"
	$HUD.add_child(welcome)
	welcome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.07, 0.09, 0.65)
	welcome.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	welcome.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -126
	panel.offset_bottom = 126
	panel.add_theme_stylebox_override("panel", _panel(Color("172937"), GOLD))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	content.add_child(_label("WELCOME TO YOUR ARENA", 22, GOLD))
	var body := _label("Book heroes to fight and earn gold. Spend that gold on recruits, buildings, and a bigger crowd.\n\nHeroes need rest after fighting. Train them for longer runs and recruit reserves to keep the matches going.", 15, Color("edf1f7"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	content.add_child(_label("Follow the objective above the arena. Progress saves automatically.\nGold and recovery advance only while the game is running.", 12))
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var skip := Button.new()
	skip.text = "Explore first / close guide"
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_dismiss_welcome)
	actions.add_child(skip)
	welcome_start = Button.new()
	welcome_start.text = "Start first fight"
	welcome_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	welcome_start.pressed.connect(func():
		_dismiss_welcome()
		if not auto_fight and not fight.active:
			_toggle_running())
	actions.add_child(welcome_start)
	welcome.hide()


func _dismiss_welcome() -> void:
	fight.intro_seen = true
	welcome.hide()
	%Start.grab_focus()
	_save()


func _needs_rotation() -> bool:
	return not fight.active and not (fight.auto_fill_owned and fight.auto_fill_enabled) and fight.lineup_rest(selected) > 0.0 and fight.ready_lineup().size() >= 3


func _book_rested() -> void:
	if fight.active or fight.ready_lineup().size() < 3:
		return
	auto_fight = false
	%Tick.stop()
	selected = fight.ready_lineup()
	_show_fighters(selected)
	%Status.text = "Rested heroes booked / open the arena"
	%Commentary.text = "Injured heroes recover on the bench. Auto-fill can handle future swaps."
	%Commentary.tooltip_text = %Commentary.text
	_refresh()
	_save()


func _open_objective() -> void:
	if fight.completed == 0:
		if not auto_fight and not fight.active:
			_toggle_running()
		return
	if _needs_rotation():
		if not %HeroesDrawer.visible:
			_toggle_drawer(%HeroesDrawer)
		rotate_button.grab_focus()
		return
	var next := fight.next_milestone()
	if next.is_empty():
		return
	var drawer: Control = build_drawer if fight.building_levels.has(next.id) else (%HeroesDrawer if next.id == "recruit" else %ArenaDrawer)
	if not drawer.visible:
		_toggle_drawer(drawer)
	if fight.building_levels.has(next.id):
		build_rows[next.id].button.grab_focus()
	elif next.id == "recruit":
		%Scroll.ensure_control_visible(cards[next.target])
		cards[next.target].grab_focus()


func _open_building(id: String) -> void:
	if not build_drawer.visible:
		_toggle_drawer(build_drawer)
	build_rows[id].button.grab_focus()


func _building_purchase(id: String) -> void:
	if fight.building_levels[id] == 0:
		if fight.coins < fight.upgrade_cost(id):
			return
		_set_arranging(true)
		%World.begin_construction(id)
		var cell: Vector2i = %World.preview_cell
		var left: float = %World.point_for_cell(cell).x - 24.0
		var right: float = left + FightRules.TownGrid.BUILDINGS[id].size.x * 48.0
		%TownScroll.value = clampf(%TownScroll.value, right - size.x + 24.0, left - 24.0)
		%World.preview_cell = cell
		%World._update_preview()
		%ArrangeHint.text = "Place %s on green cells / Esc cancels without spending" % FightRules.TownGrid.BUILDINGS[id].name
	elif fight.purchase_upgrade(id):
		_refresh()
		_save()


func _construct(id: String, cell: Vector2i) -> void:
	if fight.building_levels.get(id, -1) != 0 or not fight.purchase_upgrade(id, cell):
		%ArrangeHint.text = "Cannot build here: use owned, empty ground and enough gold / Esc cancels"
		return
	%World.cancel_placement()
	%World.sync_buildings()
	_set_arranging(false)
	_refresh()
	_save()


func _purchase_arena(id: String) -> void:
	if fight.purchase_upgrade(id):
		_refresh()
		%Stage.queue_redraw()
		_save()


func _toggle_auto_fill() -> void:
	if not fight.auto_fill_owned:
		_purchase_arena("auto")
	else:
		fight.auto_fill_enabled = not fight.auto_fill_enabled
		_refresh()
		_save()


func _refresh_objective() -> void:
	if objective == null:
		return
	var text := ""
	var hint := ""
	if fight.completed == 0:
		text = "Watch your first fight / heroes earn gold from fights and skill tips" if fight.active else "FIRST: Open the arena to earn your first gold"
		hint = "Your first completed fight pays for a Tavern. Build it to earn another 100 gold each fight."
	elif _needs_rotation():
		text = "Your booked heroes need rest / click here, book rested heroes, then open the arena"
		hint = "Heroes lose one stamina per fight, then recover on the bench. Ready reserves can fight now."
	var next := fight.next_milestone()
	if text.is_empty() and next.is_empty():
		text = "Demo complete / your estate is fully upgraded / keep fighting!"
	elif text.is_empty():
		var action: String = next.name
		if fight.building_levels.has(next.id) and fight.building_levels[next.id] == 0:
			action = {"tavern": "Spend your earnings: build a Tavern", "training": "Fight longer: build a Training Yard", "hall": "Hire reserves: build a Recruitment Hall", "infirmary": "Recover faster: build an Infirmary"}[next.id]
		elif next.id == "hall" and next.target == 2:
			action = "Expand the Hall for a full replacement trio"
		elif next.id == "seats" and next.target == 1:
			action = "Grow your crowd: expand to 150 seats"
		elif next.id == "auto":
			action = "Keep matches running: buy Auto-fill"
		text = "NEXT: %s / %d gold / %s" % [action, next.cost, "Ready to buy" if fight.coins >= next.cost else "%d more needed" % (next.cost - fight.coins)]
		hint = "Reserves fight while injured heroes rest. Click an unowned hero to recruit." if next.id == "recruit" else fight.upgrade_benefit(next.id)
	objective.text = text
	objective.tooltip_text = save_message if not save_message.is_empty() else hint + "\nClick to open the matching controls. Progress saves automatically."


func _refresh_management() -> void:
	if objective == null:
		return
	_refresh_objective()
	for id in build_rows:
		var level: int = fight.building_levels[id]
		var cost := fight.upgrade_cost(id)
		build_rows[id].info.text = "%s / %s\n%s" % [FightRules.TownGrid.BUILDINGS[id].name, "Unbuilt" if level == 0 else "Level %d" % level, fight.upgrade_benefit(id)]
		build_rows[id].button.text = "%s / %d gold" % ["Build" if level == 0 else "Upgrade", cost] if cost > 0 else "Fully upgraded"
		build_rows[id].button.disabled = cost == 0 or fight.coins < cost
		build_rows[id].button.tooltip_text = fight.upgrade_benefit(id)
	var cost := fight.upgrade_cost("fighters")
	fighter_upgrade.text = "%d fighters / +1: %d gold" % [fight.fighter_capacity(), cost] if cost > 0 else "5 fighters / maximum"
	fighter_upgrade.disabled = cost == 0 or fight.coins < cost
	auto_upgrade.text = "Auto-fill: %s" % ("On" if fight.auto_fill_enabled else "Off") if fight.auto_fill_owned else "Auto-fill / %d gold" % FightRules.AUTO_FILL_COST
	auto_upgrade.disabled = not fight.auto_fill_owned and fight.coins < FightRules.AUTO_FILL_COST
	auto_upgrade.tooltip_text = "Retain ready bookings and fill with ready recruits, up to arena capacity. Runs with at least three ready heroes."
	for id in range(cards.size()):
		if not fight.heroes[id].owned:
			cards[id].disabled = not fight.can_recruit(id)


func _layout_town() -> void:
	var center: float = %TownScroll.value + town_view_width * 0.5
	%World.size = Vector2(%World.WORLD_WIDTH, size.y)
	%TownScroll.max_value = %World.WORLD_WIDTH
	%TownScroll.page = minf(size.x, %World.WORLD_WIDTH)
	%TownScroll.value = clampf(center - size.x * 0.5, 0.0, %TownScroll.max_value - %TownScroll.page) if town_view_width > 0.0 else 0.0
	town_view_width = size.x
	_scroll_world(%TownScroll.value)


func _scroll_world(value: float) -> void:
	%World.position.x = -value
	_sync_placement_pointer(town_pointer)


func _sync_placement_pointer(point: Vector2) -> void:
	if %World.selected_building.is_empty() or not _world_input_allowed(point):
		return
	%World.preview_cell = %World.cell_for_point(point - %World.global_position)
	%World._update_preview()


func _center_arena() -> void:
	%TownScroll.value = 1152.0 - size.x * 0.5


func _set_arranging(enabled: bool) -> void:
	if enabled:
		_close_drawers()
		%ArrangeHint.text = "Select a building / click green cells to place / Esc cancels"
	%World.set_arranging(enabled)
	%ArrangeHint.visible = enabled
	%Arrange.set_pressed_no_signal(enabled)


func _world_input_allowed(point: Vector2) -> bool:
	if in_main_menu:
		return false
	if welcome != null and welcome.visible:
		return false
	if %Dismiss.visible or not Rect2(Vector2.ZERO, Vector2(size.x, size.y - 88.0)).has_point(point):
		return false
	for panel in [%Bank, %ExcitementMeter, %Earnings]:
		if panel.get_global_rect().has_point(point):
			return false
	if objective != null and objective.get_global_rect().has_point(point):
		return false
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		town_pointer = event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if not event.pressed:
				panning = false
			elif _world_input_allowed(event.position):
				panning = true
				get_viewport().set_input_as_handled()
		elif event.pressed and event.shift_pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _world_input_allowed(event.position):
			%TownScroll.value += -96.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 96.0
			_sync_placement_pointer(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and panning:
		%TownScroll.value -= event.relative.x
		_sync_placement_pointer(event.position)
		get_viewport().set_input_as_handled()


func _toggle_drawer(drawer: Control) -> void:
	var opening := not drawer.visible
	_close_drawers()
	drawer.visible = opening
	%Dismiss.visible = opening
	%HeroesButton.set_pressed_no_signal(%HeroesDrawer.visible)
	%ArenaButton.set_pressed_no_signal(%ArenaDrawer.visible)
	build_button.set_pressed_no_signal(build_drawer.visible)
	if opening:
		(%CloseHeroes if drawer == %HeroesDrawer else (close_build if drawer == build_drawer else %CloseArena)).grab_focus()


func _close_drawers() -> void:
	var button: Button = %HeroesButton if %HeroesDrawer.visible else (build_button if build_drawer.visible else %ArenaButton)
	var was_open: bool = %HeroesDrawer.visible or %ArenaDrawer.visible or build_drawer.visible
	%HeroesDrawer.hide()
	%ArenaDrawer.hide()
	build_drawer.hide()
	build_button.set_pressed_no_signal(false)
	%Dismiss.hide()
	%HeroesButton.set_pressed_no_signal(false)
	%ArenaButton.set_pressed_no_signal(false)
	if was_open:
		button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if in_main_menu:
		if session_started:
			_continue_game()
	elif welcome.visible:
		_dismiss_welcome()
	elif %Dismiss.visible:
		_close_drawers()
	elif not %World.selected_building.is_empty():
		%World.cancel_placement()
	elif %World.arranging:
		_set_arranging(false)
	else:
		_open_main_menu()
	get_viewport().set_input_as_handled()


func _panel(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", MUTED)
	theme.set_color("font_color", "Button", Color("edf1f7"))
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _panel(Color("18222f"), Color("344355")))
	theme.set_stylebox("hover", "Button", _panel(Color("253344"), GOLD))
	theme.set_stylebox("pressed", "Button", _panel(Color("30352f"), GOLD, 2))
	theme.set_stylebox("disabled", "Button", _panel(Color("131b25"), Color("293444")))
	var focus := _panel(Color.TRANSPARENT, Color("ffffff"), 2)
	theme.set_stylebox("focus", "Button", focus)
	for panel in [%Bank, %Earnings, %ExcitementMeter, %Footer, %HeroesDrawer, %ArenaDrawer, %MenuPanel]:
		panel.add_theme_stylebox_override("panel", _panel(Color("172937f5"), Color("6e7c7c")))
	for drawer in [%HeroesDrawer, %ArenaDrawer]:
		drawer.get_theme_stylebox("panel").bg_color = Color("172937")
	for label in [%Coins, %FightIncome, %Multiplier, %Income, %Capacity, %Status]:
		label.add_theme_color_override("font_color", GOLD)
	%Tips.add_theme_color_override("font_color", Color("acd5bd"))
	for state in ["normal", "hover", "pressed", "focus"]:
		%Dismiss.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	%Start.add_theme_color_override("font_color", Color("171e29"))
	%Start.add_theme_stylebox_override("normal", _panel(GOLD, GOLD))
	%Start.add_theme_stylebox_override("hover", _panel(Color("ffda93"), GOLD))
	%Start.add_theme_stylebox_override("pressed", _panel(Color("d8ab55"), GOLD))
	for part in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var color := Color("182b35") if part == "scroll" else (Color("748d90") if part == "grabber" else GOLD)
		var style := _panel(color, color, 0)
		style.set_content_margin_all(0)
		style.set_corner_radius_all(3)
		%TownScroll.add_theme_stylebox_override(part, style)
	for part in ["background", "fill"]:
		var color := Color("c8ad72") if part == "fill" else Color("0b1119")
		var style := _panel(color, color, 0)
		style.set_content_margin_all(0)
		style.set_corner_radius_all(4)
		%Excitement.add_theme_stylebox_override(part, style)


func _label(text: String, font_size: int, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_roster() -> void:
	for id in range(fight.heroes.size()):
		var hero := fight.heroes[id]
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 43
		card.toggle_mode = true
		card.pressed.connect(_select_hero.bind(id))
		%Roster.add_child(card)
		cards.append(card)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.offset_top = 2
		row.offset_bottom = -2
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var portrait := TextureRect.new()
		var crop := AtlasTexture.new()
		crop.atlas = ART.frames(hero.unit, hero.red).get_frame_texture("idle", 0)
		crop.region = Rect2(crop.atlas.get_size() * 0.5 - Vector2(40, 40), Vector2(80, 80))
		portrait.texture = crop
		portrait.custom_minimum_size.x = 44
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(heading)
		var nameplate := _label(hero.name, 14, Color("edf1f7"))
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nameplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(nameplate)
		var details := {"level": _label("", 11, GOLD), "stats": _label("", 11),
			"skill": _label("", 11, Color("b2c9e7")), "rest": _label("Ready", 11, Color("a5ddc4")), "xp": ProgressBar.new()}
		heading.add_child(details.rest)
		heading.add_child(details.level)
		var info := HBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(info)
		details.skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_child(details.skill)
		info.add_child(details.stats)
		var record := _label("", 11, Color("a5ddc4"))
		info.add_child(record)
		card_records.append(record)
		details.xp.show_percentage = false
		details.xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.xp.custom_minimum_size = Vector2(0, 3)
		details.xp.add_theme_font_size_override("font_size", 1)
		for part in ["background", "fill"]:
			var color := GOLD if part == "fill" else Color("0b1119")
			var style := _panel(color, color, 0)
			style.set_content_margin_all(0)
			details.xp.add_theme_stylebox_override(part, style)
		content.add_child(details.xp)
		card_details.append(details)


func _select_hero(id: int) -> void:
	if not fight.heroes[id].owned:
		if fight.recruit(id):
			_refresh()
			_save()
		return
	if auto_fight or fight.active:
		return
	if id in selected:
		selected.erase(id)
	elif selected.size() < fight.fighter_capacity():
		selected.append(id)
	_show_fighters(selected)
	%Status.text = "The arena is ready" if fight.valid_lineup(selected) else "Choose at least three heroes"
	%Commentary.text = "Book 3–%d heroes, then open the arena." % fight.fighter_capacity()
	%Commentary.tooltip_text = %Commentary.text
	_refresh()
	_save()


func _refresh() -> void:
	var locked := auto_fight or fight.active
	for id in range(cards.size()):
		cards[id].set_pressed_no_signal(id in selected)
		cards[id].disabled = (locked or (selected.size() == fight.fighter_capacity() and id not in selected)) if fight.heroes[id].owned else not fight.can_recruit(id)
		cards[id].add_theme_stylebox_override("disabled", _panel(Color("30352f"), GOLD, 2) if id in selected else _panel(Color("131b25"), Color("293444")))
		cards[id].modulate = Color.WHITE if id in selected else Color("9aa8ba")
		card_records[id].text = " / %d wins" % fight.heroes[id].wins
		var hero: Dictionary = fight.heroes[id]
		var stats := fight.stats_for(id)
		var needed := fight.xp_needed(id)
		var details := card_details[id]
		details.level.text = "LV %d  /  %s" % [hero.level, "%d/%d XP" % [hero.xp, needed] if needed > 0 else "MAX"]
		details.xp.max_value = needed if needed > 0 else 1
		details.xp.value = hero.xp if needed > 0 else 1
		details.stats.text = "%d HP   /   %d ATK" % [stats.health, stats.attack]
		details.skill.text = "%s / %d gold" % [hero.skill.name, FightRules.CAST_TIP]
		var movement := "Keeps 110-160 units of distance; escape dash has a %.0f-second cooldown." % FightRules.ESCAPE_COOLDOWN if hero.ranged else "Chases into melee range (45 units); approach dash has a %.1f-second cooldown and keeps its target for that time, unless the target dies." % FightRules.APPROACH_COOLDOWN
		cards[id].tooltip_text = "%s / Level %d / %s\n%d HP, %d ATK / %d gold instantly per skill\nChooses the nearest opponent. %s\n%s: %s\nMana: +25 on normal hits, +15 when surviving a normal hit; cast at 100. Skills generate no mana. Damaging skills push surviving enemies back 65 units. Dashes generate no mana, tips, or excitement.\n10 XP per completed fight, +10 for winning. Each level: +5%% base HP/ATK and +5 base gold.\nFirst 50 career victories each add 5 base gold. Spectator seats multiply base income. Each cast adds 8 excitement; final excitement boosts fight income, not tips.\nOne stamina per completed fight. At zero, rest to recover. Infirmary shortens recovery; Training Yard increases stamina." % [hero.name, hero.level, hero.unit.capitalize(), stats.health, stats.attack, FightRules.CAST_TIP, movement, hero.skill.name, hero.skill.description]
		if not hero.owned:
			details.level.text = "Recruit / %d gold" % FightRules.RECRUIT_COSTS[id]
			cards[id].tooltip_text += "\nPurchase this hero. Recruitment Hall capacity: %d / %d." % [fight.owned_count(), fight.roster_capacity()]
	_refresh_money()
	_refresh_excitement(fight.excitement)
	%Record.text = "%d fights / %d of %d recruited / saves automatically" % [fight.completed, fight.owned_count(), fight.roster_capacity()]
	%Selection.text = "HEROES / %d OF %d BOOKED" % [selected.size(), fight.fighter_capacity()]
	%HeroesButton.text = "Heroes %d/%d" % [selected.size(), fight.fighter_capacity()]
	%Hint.text = "Stop to change bookings. Unowned cards recruit new heroes." if locked else "Book 3–%d heroes. Click an unowned card to recruit." % fight.fighter_capacity()
	%Hint.tooltip_text = %Hint.text
	var quote := fight.income_breakdown(fight.next_lineup(selected))
	%Income.text = "%d gold" % quote.guaranteed if not quote.is_empty() else "Choose 3 heroes"
	%Formula.text = "%d base\n+%d hero levels\n+%d career victories\nx%.1f arena capacity" % [quote.base, quote.levels, quote.victories, quote.multiplier] if not quote.is_empty() else "Book at least three heroes to see\nthe income breakdown."
	%Formula.tooltip_text = "Base income = round((100 + 5 x sum(level - 1) + 5 x sum(min(wins, 50))) x seats / 100).\nBase locked at fight start; later upgrades and level-ups affect the next booking.\nFinal fight income = round(base income x excitement multiplier). Tips are paid separately."
	%Start.disabled = (not fight.valid_lineup(selected) and not (fight.auto_fill_owned and fight.auto_fill_enabled)) or (fight.active and not auto_fight)
	%Start.text = ("Stop after this fight" if fight.active else "Cancel next fight") if auto_fight else "Open arena"
	if fight.active and not auto_fight:
		%Start.text = "Finishing fight..."
	_refresh_recovery()


func _refresh_recovery() -> void:
	if rotate_button != null:
		rotate_button.disabled = fight.active or fight.ready_lineup().size() < 3 or fight.ready_lineup() == selected
	_refresh_objective()
	for id in range(card_details.size()):
		var remaining: float = fight.rest_remaining[id]
		card_details[id].rest.text = ("Injured · %ds  " % ceili(remaining) if remaining > 0.0 else "%d/%d stamina  " % [fight.heroes[id].stamina, fight.max_stamina()]) if fight.heroes[id].owned else "Unowned  "
		card_details[id].rest.add_theme_color_override("font_color", GOLD if remaining > 0.0 else Color("a5ddc4"))
	if auto_fight and not fight.active:
		var remaining := maxf(fight.lineup_rest(fight.next_lineup(selected)), %Tick.time_left)
		%Start.text = "Cancel / next in %ds" % ceili(remaining)
		if fight.auto_fill_enabled and fight.next_lineup(selected).size() < 3:
			%Start.text = "Cancel / waiting for heroes"
		%Start.tooltip_text = "One stamina per fight. Injured heroes recover before returning. Auto-fill uses ready recruits when unlocked and enabled."


func _refresh_money() -> void:
	%Coins.text = "%d gold" % fight.coins
	%Tips.text = "%d tips paid" % fight.crowd_tips
	_refresh_venue()
	_refresh_management()


func _draw_excitement_markers() -> void:
	for threshold in FightRules.EXCITEMENT_THRESHOLDS.slice(1):
		var x: float = %Excitement.size.x * threshold / FightRules.EXCITEMENT_MAX
		%Excitement.draw_line(Vector2(x, 0), Vector2(x, %Excitement.size.y), Color("edf1f7"), 2.0)


func _refresh_excitement(score: float) -> void:
	var tier := FightRules.excitement_tier(score)
	var multiplier: float = FightRules.EXCITEMENT_MULTIPLIERS[tier]
	var color: Color = [Color("c8ad72"), GOLD, Color("ffa06b")][tier]
	%Excitement.value = score
	%Excitement.get_theme_stylebox("fill").bg_color = color
	%ExcitementLabel.text = "%s  %d/100" % [FightRules.EXCITEMENT_NAMES[tier], floori(score)]
	%Multiplier.text = "x%.2f" % multiplier
	%ExcitementLabel.add_theme_color_override("font_color", color)
	if fight.active:
		%FightIncome.text = "%d at finish" % fight.income_with_excitement(score)
		if fight.elapsed > FightRules.OVERTIME_AFTER:
			%Status.text = "Overtime / x%.1f damage" % fight.overtime_multiplier()
			%Status.tooltip_text = "After 60 seconds, damage rises 10% per second so healing matchups finish. Healing is unchanged."
	elif fight.completed > 0:
		%FightIncome.text = "%d paid / last fight" % fight.settled_income
	else:
		%FightIncome.text = "%d base / next fight" % fight.income_for(selected) if fight.valid_lineup(selected) else "Book three heroes"
	%FightIncome.tooltip_text = "Fight payout excludes tips already in your bank. Base income is locked at fight start; excitement multiplies it. Open Arena for the next booking's breakdown."
	if tavern_income != null:
		tavern_income.text = "Tavern: %d %s" % [fight.tavern_payout if fight.active else fight.settled_tavern, "at finish" if fight.active else "paid / last fight"]
	%ExcitementHint.text = ["25: Excited x1.25 / Skills +8", "60: Wild x2.50 / Skills +8", "Wild crowd! / Maximum multiplier"][tier]
	if tier > displayed_tier:
		feedback.tier_crossed(tier)
		cheer = 1.0
		if excitement_pulse and excitement_pulse.is_valid():
			excitement_pulse.kill()
		%ExcitementMeter.modulate = Color(1.7, 1.5, 1.2)
		excitement_pulse = %ExcitementMeter.create_tween()
		excitement_pulse.tween_property(%ExcitementMeter, "modulate", Color.WHITE, 0.7)
	displayed_tier = tier


func _refresh_venue() -> void:
	var capacity := fight.arena_capacity()
	var cost := fight.arena_upgrade_cost()
	%Capacity.text = "%d seats" % capacity
	%ArenaButton.text = "Arena / %d" % capacity
	%CapacityInfo.text = "Full house / x%.1f income" % (float(capacity) / FightRules.ARENA_CAPACITIES[0])
	%Expand.disabled = cost == 0 or fight.coins < cost
	%Expand.text = "Expand / %d gold" % cost if cost > 0 else "Fully expanded"
	%NextCapacity.text = "Next: %d seats / x%.1f" % [capacity + 50, float(capacity + 50) / FightRules.ARENA_CAPACITIES[0]] if cost > 0 else "Maximum capacity reached"
	%UpgradeHint.text = "Applies to your next booking" if cost > 0 else "200 seats / all upgrades owned"
	%Expand.tooltip_text = "Spend gold to expand seating. Your current fight keeps its quoted payout; the next booking earns more."


func _expand_arena() -> void:
	_purchase_arena("seats")


func _toggle_running() -> void:
	if auto_fight:
		auto_fight = false
		if not fight.active:
			%Tick.stop()
			%Status.text = "Arena closed / change bookings"
	elif not fight.active and (fight.valid_lineup(selected) or (fight.auto_fill_owned and fight.auto_fill_enabled)):
		auto_fight = true
		_close_drawers()
		_try_begin_fight()
	_refresh()


func _begin_fight() -> void:
	if not fight.start(fight.next_lineup(selected)):
		return
	_show_fighters(fight.participants)
	cheer = 0.0
	if excitement_pulse and excitement_pulse.is_valid():
		excitement_pulse.kill()
	%ExcitementMeter.modulate = Color.WHITE
	displayed_tier = 0
	%Status.text = "Fight %02d  /  %d base gold" % [fight.completed + 1, fight.payout]
	%Commentary.text = "Nearest opponent / Melee heroes chase / Nia keeps her distance"
	%Commentary.tooltip_text = %Commentary.text
	%Status.tooltip_text = %Status.text
	%Tick.stop()
	_refresh()


func _try_begin_fight() -> void:
	if not in_main_menu and auto_fight and not fight.active and %Tick.is_stopped():
		_begin_fight()


func _intermission_finished() -> void:
	%Tick.stop()
	_try_begin_fight()


func _physics_process(delta: float) -> void:
	if in_main_menu:
		return
	var was_active := fight.active
	var events := fight.advance(delta)
	_refresh_recovery()
	if not was_active:
		_try_begin_fight()
		return
	_layout_fighters()
	for event in events:
		_present_action(event)
	_refresh_excitement(fight.excitement)
	_sync_fighters()
	feedback.flush_celebration()


func _process(delta: float) -> void:
	if in_main_menu:
		return
	save_elapsed += delta
	if save_elapsed >= 30.0:
		save_elapsed = 0.0
		_save()
	crowd_clock += delta
	crowd_tick += delta
	cheer = maxf(0.0, cheer - delta * 0.5)
	if crowd_tick >= 1.0 / 12.0:
		%Stage.queue_redraw()
		crowd_tick = 0.0


func _present_action(event: Dictionary) -> void:
	if event.kind == "move":
		feedback.present(event)
		fighters[event.attacker].sprite.play("run")
		%Commentary.text = "%s %s" % [fight.heroes[event.attacker].name, "dashes to safety" if event.move_kind == "escape" else "rushes into range"]
		%Commentary.tooltip_text = %Commentary.text
		return
	_animate_action(event)
	var attacker: Dictionary = fight.heroes[event.attacker]
	if event.kind == "skill":
		%Commentary.text = "%s casts %s / +%d crowd tip / +%s excitement%s" % [attacker.name, attacker.skill.name, event.tip, String.num(event.excitement_gain, 1).trim_suffix(".0"), " / heals %d HP" % event.healing if event.healing > 0 else ""]
	else:
		var hit: Dictionary = event.hits[0]
		%Commentary.text = "%s hits %s for %d%s" % [attacker.name, fight.heroes[hit.target].name, hit.damage, " / knocked out!" if fight.health[hit.target] == 0 else ""]
	%Commentary.tooltip_text = %Commentary.text
	if event.winner >= 0:
		var winner: Dictionary = fight.heroes[event.winner]
		%Status.text = "%s wins!  /  +1 career victory" % winner.name
		var multiplier: float = FightRules.EXCITEMENT_MULTIPLIERS[FightRules.excitement_tier(event.excitement)]
		%Commentary.text = "%d fight + %d tips + %d Tavern = %d gold" % [fight.settled_income, fight.crowd_tips, fight.settled_tavern, fight.settled_income + fight.crowd_tips + fight.settled_tavern]
		%Commentary.tooltip_text = "%d base x%.2f = %d fight income. Tips already paid: %d. Tavern sales: %d. Total: %d gold." % [fight.payout, multiplier, fight.settled_income, fight.crowd_tips, fight.settled_tavern, fight.settled_income + fight.crowd_tips + fight.settled_tavern]
		_refresh()
		_save()
		var xp_results := PackedStringArray()
		var leveled := PackedStringArray()
		for progress in event.progression:
			var hero: Dictionary = fight.heroes[progress.hero]
			xp_results.append("%s +%d XP" % [hero.name, progress.xp] if progress.xp > 0 else "%s MAX" % hero.name)
			if progress.level > progress.before:
				leveled.append("%s Lv.%d" % [hero.name, progress.level])
				var label: Label = card_details[progress.hero].level
				label.modulate = Color(1.6, 1.6, 1.6)
				label.create_tween().tween_property(label, "modulate", Color.WHITE, 0.8)
		%Hint.text = " / ".join(xp_results)
		%Hint.tooltip_text = %Hint.text
		if not leveled.is_empty():
			%Status.text += " / Level up: " + ", ".join(leveled)
		%Status.tooltip_text = %Status.text + "\n" + " / ".join(xp_results)
		if auto_fight:
			%Tick.start(INTERMISSION)


func _show_fighters(lineup: Array[int]) -> void:
	feedback.reset()
	for fighter in fighters.values():
		%Stage.remove_child(fighter.body)
		fighter.body.queue_free()
	fighters.clear()
	for id in lineup:
		var hero := fight.heroes[id]
		var stats: Dictionary = fight.battle_stats[id] if fight.active else fight.stats_for(id)
		var body := Node2D.new()
		%Stage.add_child(body)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = ART.frames(hero.unit, hero.red)
		sprite.scale = Vector2.ONE * 0.78
		sprite.position.y = -23
		sprite.play("idle")
		sprite.animation_finished.connect(func(): sprite.play("idle"))
		body.add_child(sprite)
		var bars := {}
		for stat in ["health", "mana"]:
			var bar := ProgressBar.new()
			bar.position = Vector2(-27, -65 if stat == "health" else -58)
			bar.max_value = stats.health if stat == "health" else FightRules.MANA_MAX
			bar.value = stats.health if stat == "health" else 0
			bar.show_percentage = false
			bar.add_theme_font_size_override("font_size", 1)
			for part in ["background", "fill"]:
				var color := Color("78c5a4") if stat == "health" else Color("89aaff")
				if part == "background":
					color = Color("0b1119")
				var style := _panel(color, color, 0)
				style.set_content_margin_all(0)
				style.set_corner_radius_all(3)
				bar.add_theme_stylebox_override(part, style)
			body.add_child(bar)
			bar.set_deferred("size", Vector2(54, 5))
			bars[stat] = bar
		var nameplate := _label(hero.name, 13, Color("edf1f7"))
		nameplate.add_theme_color_override("font_outline_color", Color("18222f"))
		nameplate.add_theme_constant_override("outline_size", 4)
		nameplate.position = Vector2(-60, 6)
		nameplate.size.x = 120
		body.add_child(nameplate)
		fighters[id] = {"body": body, "sprite": sprite, "bar": bars.health, "mana": bars.mana, "name": nameplate, "tint": null}
	_layout_fighters()


func _layout_fighters() -> void:
	var index := 0
	for id in fighters:
		var ground := Vector2.from_angle(-PI / 2.0 + TAU * index / maxi(1, fighters.size())) * FightRules.ARENA_RADIUS * 0.72
		if fight.active or (fight.completed > 0 and fight.participants == Array(fighters.keys())):
			ground = fight.positions.get(id, ground)
		fighters[id].body.position = _project(ground)
		fighters[id].body.z_index = roundi(ground.y) + 300
		index += 1
	%Stage.queue_redraw()


func _ground_scale() -> float:
	return maxf(0.1, (%Stage.size.x - 48.0) / (FightRules.ARENA_RADIUS * 2.0))


func _project(ground: Vector2) -> Vector2:
	var scale_x := _ground_scale()
	var scale_y := minf(scale_x * GROUND_DEPTH, 80.0 / FightRules.ARENA_RADIUS)
	return Vector2(%Stage.size.x * 0.5, %Stage.size.y - 90.0) + ground * Vector2(scale_x, scale_y)


func _circle_points(origin: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(65):
		points.append(_project(origin + Vector2.from_angle(TAU * i / 64.0) * radius))
	return points


func _draw_ring() -> void:
	# Each row represents 50 filled seats; expansion adds seating, not combat space.
	for row in range(fight.arena_capacity() / 50 - 1, -1, -1):
		var radius := FightRules.ARENA_RADIUS + 28.0 + row * 22.0
		var bench := PackedVector2Array()
		for seat in range(50):
			bench.append(_project(Vector2.from_angle(PI + 0.1 + (PI - 0.2) * seat / 49.0) * radius))
		%Stage.draw_polyline(bench, Color("39464a"), 23.0, false)
		%Stage.draw_polyline(bench, Color("70503a"), 18.0, false)
		%Stage.draw_polyline(bench, Color("b48a54"), 3.0, false)
		for seat in range(bench.size()):
			var pos := bench[seat]
			var bounce := maxf(0.0, sin(crowd_clock * 7.0 + seat * 0.7)) * cheer * 6.0
			var frame := (int(crowd_clock * 5) + seat) % 6
			var tint := Color("ead3a0") if (seat + row) % 3 == 0 else Color.WHITE
			%Stage.draw_texture_rect_region(SPECTATOR, Rect2(pos - Vector2(7, 23 + bounce), Vector2(14, 21)), Rect2(frame * 192 + 64, 48, 64, 88), tint)
			if seat % 5 == 0:
				%Stage.draw_line(pos + Vector2(0, 5), pos + Vector2(0, 17), Color("54452f"), 5.0)
	var points := _circle_points(Vector2.ZERO, FightRules.ARENA_RADIUS)
	%Stage.draw_polyline(points, Color("324c53"), 24.0, false)
	%Stage.draw_polyline(points, Color("72918b"), 17.0, false)
	%Stage.draw_colored_polygon(points.slice(0, 64), Color("d8bc80"))
	%Stage.draw_polyline(points, Color("ad8754"), 5.0, false)
	%Stage.draw_polyline(_circle_points(Vector2.ZERO, FightRules.ARENA_RADIUS - 16.0), Color("ead099"), 2.0, false)
	# Sparse sand marks, deterministic and purely visual; never consume combat RNG.
	for i in range(90):
		var ground := Vector2.from_angle(i * 2.399) * sqrt(float(i) / 90.0) * (FightRules.ARENA_RADIUS - 25)
		var pos := _project(ground)
		%Stage.draw_line(pos, pos + Vector2(3 + i % 4, 0), Color("cbae76"), 1.0)
	for i in range(24):
		var pos := _project(Vector2.from_angle(TAU * i / 24.0) * (FightRules.ARENA_RADIUS + 2.0))
		%Stage.draw_rect(Rect2(pos - Vector2(3, 8), Vector2(6, 15)), Color("6b5137"))
		%Stage.draw_rect(Rect2(pos - Vector2(4, 9), Vector2(8, 4)), Color("c29a61"))
	for side in [-1, 1]:
		var post := _project(Vector2(side * 275, -165))
		%Stage.draw_line(post, post - Vector2(0, 53), Color("5e4935"), 5.0)
		%Stage.draw_circle(post - Vector2(0, 55), 4.0, GOLD)
		var sway := sin(crowd_clock * 2 + side) * 2.0
		var flag := PackedVector2Array([post + Vector2(2, -49), post + Vector2(26, -47 + sway), post + Vector2(26, -12 + sway), post + Vector2(14, -18), post + Vector2(2, -14)])
		%Stage.draw_colored_polygon(flag, Color("3c698b") if side < 0 else Color("a55345"))
		%Stage.draw_line(post + Vector2(13, -41), post + Vector2(13, -24), GOLD, 3)
	# Upgrades visibly add a covered stand, then a broader blue-and-cream canopy.
	if fight.arena_tier > 0:
		var roof := _project(Vector2(0, -365)) - Vector2(0, 28)
		var width := 160.0 + fight.arena_tier * 80.0
		for side in [-1, 1]:
			%Stage.draw_line(roof + Vector2(side * width * 0.5, 12), roof + Vector2(side * width * 0.5, 45), Color("695138"), 5)
		for stripe in range(12):
			var x := roof.x - width * 0.5 + stripe * width / 12.0
			%Stage.draw_rect(Rect2(x, roof.y, width / 12.0 + 1, 19), Color("3e718e") if stripe % 2 == 0 else Color("ebd6a2"))
			%Stage.draw_rect(Rect2(x, roof.y + 18, width / 12.0 + 1, 4), Color("294957") if stripe % 2 == 0 else Color("b9a981"))
	for id in fighters:
		var pos: Vector2 = fighters[id].body.position
		%Stage.draw_set_transform(pos, 0.0, Vector2(1.0, 0.3))
		%Stage.draw_circle(Vector2.ZERO, 19.0, Color(0.24, 0.18, 0.1, 0.3))
		%Stage.draw_set_transform(Vector2.ZERO)


func _sync_fighters() -> void:
	for id in fighters:
		var fighter: Dictionary = fighters[id]
		fighter.bar.value = fight.health[id]
		fighter.mana.value = fight.mana[id]
		fighter.mana.tooltip_text = "%d / 100 mana" % fight.mana[id]
		if fight.health[id] <= 0:
			fighter.sprite.stop()
			fighter.bar.hide()
			fighter.mana.hide()
			fighter.name.hide()
			continue
		var pushed: bool = fight.motions.has(id) and fight.motions[id].kind == "pushback"
		var moving: bool = fight.velocities[id].length() > 1.0 and not pushed
		var direction: Vector2 = fight.velocities[id] if not pushed else Vector2.ZERO
		if not moving and fight.targets[id] >= 0:
			direction = fight.positions[fight.targets[id]] - fight.positions[id]
		if absf(direction.x) > 0.1:
			fighter.sprite.flip_h = direction.x < 0.0
		if not (fighter.sprite.animation == "attack" and fighter.sprite.is_playing()) and (not fight.active or fight.pauses[id] <= 0.0):
			fighter.sprite.play("run" if moving and fight.active else "idle")


func _animate_action(event: Dictionary) -> void:
	# Update money in the same frame that starts the cast animation, before any tween.
	%Coins.text = "%d gold" % event.coins
	%Tips.text = "%d tips paid" % event.crowd_tips
	_refresh_venue()
	_refresh_management()
	_refresh_excitement(event.excitement)
	var source: Dictionary = fighters[event.attacker]
	var sprite: AnimatedSprite2D = source.sprite
	sprite.play("attack")
	sprite.frame = 0
	if not event.hits.is_empty():
		sprite.flip_h = event.hits[0].position.x < event.origin.x
	feedback.present(event)
	if event.kind == "skill":
		_tint_fighter(event.attacker, Color("a5ffd0") if event.healing > 0 else GOLD)
	for hit in event.hits:
		_tint_fighter(hit.target, Color("ffbc9e"))
	if event.winner >= 0:
		fighters[event.winner].name.text = "%s / WINNER" % fight.heroes[event.winner].name
		fighters[event.winner].name.add_theme_color_override("font_color", GOLD)


func _tint_fighter(id: int, color: Color) -> void:
	var fighter: Dictionary = fighters[id]
	if fighter.tint and fighter.tint.is_valid():
		fighter.tint.kill()
	fighter.sprite.modulate = color
	fighter.tint = fighter.sprite.create_tween()
	fighter.tint.tween_property(fighter.sprite, "modulate", Color("515c68") if fight.health[id] == 0 else Color.WHITE, 0.4)
