extends Control

const FightRules := preload("res://game/fight.gd")
const CombatFeedback := preload("res://game/combat_feedback.gd")
const SaveGame := preload("res://game/save_game.gd")
const Actor := preload("res://resources/art/sunnyside_actor.gd")
const GOLD := Color("f2c771")
const MUTED := Color("a5b2c3")
const INTERMISSION := 3.0
const EVENT_ROUNDS := 10
const GROUND_DEPTH := 1.0
const SPECTATOR := preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/base_idle_strip9.png")
const SPECTATOR_HAIR := preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/mophair_idle_strip9.png")
const SPECTATOR_HAIRS := [SPECTATOR_HAIR, preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/curlyhair_idle_strip9.png"), preload("res://asset/Sunnyside_World_Assets/Characters/Human/IDLE/shorthair_idle_strip9.png")]

var fight := FightRules.new()
var selected: Array[int] = [0, 1]
var auto_fight := false
var event_rounds := 0
var event_gold := 0
var event_progression: Dictionary = {}
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
var management_revision := -1
var management_tick := 0.0
var facility_id := ""
var facility_title: Label
var facility_summary: Label
var facility_note: Label
var facility_back: Button
var facility_upgrade: Button
var build_list: VBoxContainer
var facility_list: VBoxContainer
var facility_rows: Dictionary = {}


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
	%EventButton.pressed.connect(_toggle_drawer.bind(%EventDrawer))
	%ManageEventHeroes.pressed.connect(_toggle_drawer.bind(%HeroesDrawer))
	var event_scroll := %EventHeroes.get_parent().get_v_scroll_bar()
	event_scroll.focus_mode = Control.FOCUS_ALL
	event_scroll.custom_step = 24
	event_scroll.focus_neighbor_top = NodePath(".")
	event_scroll.focus_neighbor_bottom = NodePath(".")
	for button in [%CloseHeroes, %CloseArena, %CloseEvent, %Dismiss]:
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
	_show_fighters(selected.filter(func(id: int): return fight.ready(id)))
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
	var starters: Array[int] = [0, 1]
	if saving_enabled:
		var error := SaveGame.save_game(fresh, starters, save_path)
		if error != OK:
			%MenuStatus.text = "Could not start a new game (%s). Your current estate is retained." % error_string(error)
			return
		has_saved_game = true
	%NewGameConfirmation.hide()
	%Tick.stop()
	auto_fight = false
	event_rounds = 0
	event_gold = 0
	event_progression.clear()
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
	%Commentary.text = "Bram and Ivo / Recruit Nia after your first fight"
	%Commentary.tooltip_text = %Commentary.text
	welcome_start.text = "Start first event"
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
	facility_title = title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_child(title)
	facility_back = Button.new()
	facility_back.text = "All buildings"
	facility_back.pressed.connect(_show_build_overview)
	facility_back.hide()
	heading.add_child(facility_back)
	close_build = Button.new()
	close_build.text = "Close"
	close_build.pressed.connect(_close_drawers)
	heading.add_child(close_build)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	list.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var rows := VBoxContainer.new()
	build_list = rows
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	content.add_child(rows)
	for id in FightRules.TownGrid.BUILDINGS:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var info := _label("", 13)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var manage := Button.new()
		manage.text = "Manage"
		manage.pressed.connect(_open_building.bind(id))
		row.add_child(manage)
		var button := Button.new()
		button.custom_minimum_size = Vector2(166, 48)
		button.pressed.connect(_building_purchase.bind(id))
		row.add_child(button)
		build_rows[id] = {"info": info, "button": button, "manage": manage}
	facility_list = VBoxContainer.new()
	facility_list.add_theme_constant_override("separation", 8)
	content.add_child(facility_list)
	facility_summary = _label("", 12)
	facility_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facility_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	facility_list.add_child(facility_summary)
	facility_upgrade = Button.new()
	facility_upgrade.pressed.connect(func(): _building_purchase(facility_id))
	facility_list.add_child(facility_upgrade)
	facility_note = _label("", 12, GOLD)
	facility_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facility_list.add_child(facility_note)
	for id in range(fight.heroes.size()):
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 48
		facility_list.add_child(row)
		var portrait := _hero_portrait(id)
		row.add_child(portrait)
		var info := _label("", 12)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var primary := Button.new()
		primary.pressed.connect(_facility_action.bind(id, false))
		row.add_child(primary)
		var secondary := Button.new()
		secondary.pressed.connect(_facility_action.bind(id, true))
		row.add_child(secondary)
		facility_rows[id] = {"row": row, "info": info, "primary": primary, "secondary": secondary}
	facility_list.hide()
	list.add_child(_label("One of each / move freely with Arrange / outer land is a preview", 11))
	build_button.pressed.connect(func():
		_show_build_overview()
		_toggle_drawer(build_drawer))
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
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective.offset_left = 16
	objective.offset_right = 320
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
	rotate_button.text = "Use rested heroes"
	rotate_button.tooltip_text = "Choose the ready heroes with the most stamina. Auto-fill handles substitutions during a booked event."
	rotate_button.pressed.connect(_book_rested)
	var roster_heading := %HeroesDrawer.get_node("Details/Heading")
	roster_heading.add_child(rotate_button)
	roster_heading.move_child(rotate_button, 1)
	_build_welcome()


func _hero_portrait(id: int) -> Control:
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(36, 42)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var actor := Actor.new()
	portrait.add_child(actor)
	actor.setup(id, fight.heroes[id].unit, fight.heroes[id].red)
	actor.position = Vector2(18, 38)
	actor.scale = Vector2.ONE * 0.85
	actor.play("idle")
	return portrait


func _show_build_overview() -> void:
	facility_id = ""
	build_list.show()
	facility_list.hide()
	facility_back.hide()
	facility_title.text = "BUILD YOUR ESTATE"


func _show_facility(id: String) -> void:
	facility_id = id
	build_list.hide()
	facility_list.show()
	facility_back.show()
	facility_title.text = FightRules.TownGrid.BUILDINGS[id].name.to_upper()
	facility_note.text = ""
	_refresh_facility()


func _facility_action(id: int, secondary: bool) -> void:
	var success := false
	if facility_id == "training":
		if fight.training_elapsed.has(id):
			success = fight.training_recall(id)
			facility_note.text = "%s recalled / incomplete training interval discarded" % fight.heroes[id].name
		else:
			success = fight.training_assign(id, selected)
			facility_note.text = "%s started training / +5 XP every 30s" % fight.heroes[id].name
	elif facility_id == "tavern":
		var kind := "feast" if secondary else "light"
		var quote: Dictionary = fight.meal_quote(id, kind)
		success = fight.feed(id, kind)
		facility_note.text = "%s +%d stamina / %d gold" % [fight.heroes[id].name, quote.restored, quote.cost] if success else quote.reason
	if success:
		_refresh()
		%World.sync_management(fight)
		_save()
	else:
		if facility_id == "training":
			facility_note.text = fight.training_reason(id, selected)
		_refresh_facility()


func _refresh_facility() -> void:
	if facility_id.is_empty() or facility_list == null:
		return
	var level: int = fight.building_levels[facility_id]
	var cost: int = fight.upgrade_cost(facility_id)
	facility_upgrade.text = "%s / %d gold" % ["Build" if level == 0 else "Upgrade", cost] if cost > 0 else "Maximum level"
	facility_upgrade.disabled = cost == 0 or fight.coins < cost
	facility_upgrade.visible = cost > 0
	facility_note.visible = not facility_note.text.is_empty()
	facility_upgrade.tooltip_text = fight.upgrade_benefit(facility_id)
	var patients: Array = fight.hospital_patients()
	match facility_id:
		"training":
			facility_summary.text = "%d / %d training slots / 5 XP every 30s\nAssign unbooked reserves. Recall is free." % [fight.training_elapsed.size(), fight.training_capacity()]
		"infirmary":
			facility_summary.text = "%d / %d beds / %.0fx treatment / %d waiting\nOldest injury first. Free recovery continues outside." % [patients.size(), fight.hospital_capacity(), fight.hospital_rate(), fight.hospital_waiting().size()]
		"tavern":
			facility_summary.text = "%s / meals never heal injuries\nLight: 20 gold / +5 stamina. Full: 50 gold / refill." % ("Next serving in %ds" % ceili(fight.restaurant_cooldown) if fight.restaurant_cooldown > 0.0 else "Ready to serve")
	var ordered: Array = facility_rows.keys()
	ordered.sort_custom(func(a: int, b: int):
		var first := _facility_priority(a)
		var second := _facility_priority(b)
		return first < second if first != second else a < b)
	var index := 3
	for id in ordered:
		var row: Dictionary = facility_rows[id]
		facility_list.move_child(row.row, index)
		index += 1
		var hero: Dictionary = fight.heroes[id]
		row.row.visible = hero.owned and (facility_id != "infirmary" or fight.injury_remaining[id] > 0 or fight.rest_remaining[id] > 0)
		row.primary.visible = facility_id != "infirmary"
		row.secondary.visible = facility_id == "tavern"
		if not hero.owned:
			continue
		row.info.text = "%s / Lv.%d\n%s" % [hero.name, hero.level, _hero_condition(id)]
		match facility_id:
			"training":
				var assigned: bool = fight.training_elapsed.has(id)
				var reason: String = fight.training_reason(id, selected)
				row.primary.text = "Recall" if assigned else "Train"
				row.primary.disabled = not assigned and not reason.is_empty()
				row.primary.tooltip_text = "Return to the reserve roster immediately" if assigned else ("Assign for 5 XP every 30s" if reason.is_empty() else reason)
				if assigned:
					row.info.text = "%s / Lv.%d / %d XP\nNext +5 XP in %ds" % [hero.name, hero.level, hero.xp, ceili(30.0 - float(fight.training_elapsed[id]))]
			"infirmary":
				if fight.injury_remaining[id] > 0.0:
					var rate: float = fight.hospital_rate() if id in patients else 1.0
					row.info.text = "%s / %s / injury ~%ds\n%s" % [hero.name, "In treatment" if id in patients else "Recovering outside", ceili(fight.injury_remaining[id] / rate), "Also resting: %ds" % ceili(fight.rest_remaining[id]) if fight.rest_remaining[id] > 0 else "Fatigue recovered" ]
			"tavern":
				for kind in ["light", "feast"]:
					var quote: Dictionary = fight.meal_quote(id, kind)
					var button: Button = row.primary if kind == "light" else row.secondary
					button.text = "+%d / %dg" % [quote.restored, quote.cost]
					button.disabled = not quote.allowed
					button.tooltip_text = ("Light meal" if kind == "light" else "Full meal") + (" / " + quote.reason if not quote.allowed else " / restore %d stamina" % quote.restored)


func _facility_priority(id: int) -> int:
	if not fight.heroes[id].owned:
		return 9
	match facility_id:
		"training":
			return 0 if fight.training_elapsed.has(id) else (1 if fight.training_reason(id, selected).is_empty() else 2)
		"infirmary":
			return 0 if id in fight.hospital_patients() else (1 if fight.injury_remaining[id] > 0.0 else 2)
		"tavern":
			return 0 if fight.meal_quote(id, "light").restored > 0 else 2
	return 0


func _hero_condition(id: int) -> String:
	var state: Dictionary = fight.availability(id)
	var result: String = state.state.capitalize()
	if state.seconds > 0.0 and state.seconds < INF:
		result += " %ds" % ceili(state.seconds)
	if fight.injury_remaining[id] > 0.0 and fight.rest_remaining[id] > 0.0:
		result += " / fatigue %ds" % ceili(fight.rest_remaining[id])
	return result


func _build_welcome() -> void:
	var guide := Button.new()
	guide.text = "Guide"
	guide.pressed.connect(func():
		_close_drawers()
		welcome.show()
		welcome_start.text = "Return to arena" if fight.active or auto_fight else "Start %d-fight event" % EVENT_ROUNDS
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
	var body := _label("Book heroes for a %d-fight event. Fights run automatically, then the arena waits for you to prepare the next event. Rewards are paid as you go.\n\nRecruit Nia after your first fight. Rotate tired heroes, train reserves, and use meals or recovery before your next booking. Three defeats cause injury." % EVENT_ROUNDS, 15, Color("edf1f7"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	content.add_child(_label("Follow the objective above the arena. Progress saves automatically.\nGold and recovery require the game to run. Sunnyside World art by Daniel Diggle.", 12))
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var skip := Button.new()
	skip.text = "Explore first / close guide"
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_dismiss_welcome)
	actions.add_child(skip)
	welcome_start = Button.new()
	welcome_start.text = "Start first event"
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
	return not fight.active and not (fight.auto_fill_owned and fight.auto_fill_enabled) and selected.any(func(id: int): return not fight.ready(id)) and fight.ready_lineup().size() >= 2


func _book_rested() -> void:
	if fight.active or fight.ready_lineup().size() < 2:
		return
	%Tick.stop()
	selected = fight.ready_lineup()
	_show_fighters(selected)
	%Status.text = "Rested heroes booked" + (" / event running" if auto_fight else " / start an event")
	%Commentary.text = "Reserves replace unavailable heroes. Auto-fill can handle future swaps."
	%Commentary.tooltip_text = %Commentary.text
	_refresh()
	_save()
	if auto_fight:
		_try_begin_fight()


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
		_show_build_overview()
		build_rows[next.id].button.grab_focus()
	elif next.id == "recruit":
		%Scroll.ensure_control_visible(cards[next.target])
		cards[next.target].grab_focus()


func _open_building(id: String) -> void:
	if id == "hall":
		if not %HeroesDrawer.visible:
			_toggle_drawer(%HeroesDrawer)
		return
	if not build_drawer.visible:
		_toggle_drawer(build_drawer)
	_show_facility(id)


func _building_purchase(id: String) -> void:
	if fight.building_levels[id] == 0:
		if fight.coins < fight.upgrade_cost(id):
			return
		_set_arranging(true)
		%World.begin_construction(id)
		var cell: Vector2i = %World.preview_cell
		var left: float = %World.point_for_cell(cell).x - 24.0
		var right: float = left + FightRules.TownGrid.BUILDINGS[id].size.x * float(FightRules.TownGrid.CELL_SIZE.x)
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
		text = "Watch your first fight / heroes earn gold from fights and skill tips" if fight.active else "FIRST: Book an event to earn your first gold"
		hint = "Your first completed fight pays for Nia, your first reserve. Three defeats cause injury; a minute on the bench removes one injury-meter point."
	elif _needs_rotation():
		text = "A preferred hero is unavailable / use rested heroes to keep fighting"
		hint = "Fatigue, injury and training block bookings. Ready reserves can fight now; basic recovery is always free."
	var next := fight.next_milestone()
	if text.is_empty() and next.is_empty():
		text = "Demo complete / your estate is fully upgraded / keep fighting!"
	elif text.is_empty():
		var action: String = next.name
		if fight.building_levels.has(next.id) and fight.building_levels[next.id] == 0:
			action = {"tavern": "Serve food and earn sales: build a Restaurant", "training": "Develop reserves: build a Gym", "hall": "Hire reserves: build a Recruitment Hall", "infirmary": "Treat injuries: build a Hospital"}[next.id]
		elif next.id == "hall" and next.target == 2:
			action = "Expand the Hall for more reserves"
		elif next.id == "seats" and next.target == 1:
			action = "Grow your crowd: expand to 150 seats"
		elif next.id == "auto":
			action = "Rotate reserves during events: buy Auto-fill"
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
		build_rows[id].manage.disabled = level == 0
	var cost := fight.upgrade_cost("fighters")
	fighter_upgrade.text = "%d fighters / +1: %d gold" % [fight.fighter_capacity(), cost] if cost > 0 else "5 fighters / maximum"
	fighter_upgrade.disabled = cost == 0 or fight.coins < cost
	auto_upgrade.text = "Auto-fill: %s" % ("On" if fight.auto_fill_enabled else "Off") if fight.auto_fill_owned else "Auto-fill / %d gold" % FightRules.AUTO_FILL_COST
	auto_upgrade.disabled = not fight.auto_fill_owned and fight.coins < FightRules.AUTO_FILL_COST
	auto_upgrade.tooltip_text = "Retain ready bookings and fill with ready recruits during this event. Needs two ready heroes. Never books the next event."
	for id in range(cards.size()):
		if not fight.heroes[id].owned:
			cards[id].disabled = not fight.can_recruit(id)


func _layout_town() -> void:
	var center: float = %TownScroll.value + town_view_width * 0.5
	%World.size = Vector2(%World.WORLD_WIDTH, size.y)
	%Stage.position = Vector2(FightRules.TownGrid.ARENA.position.x * FightRules.TownGrid.CELL_SIZE.x, size.y - 340.0)
	%Stage.size = Vector2(FightRules.TownGrid.ARENA.size.x * FightRules.TownGrid.CELL_SIZE.x, 256)
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
	%TownScroll.value = float(FightRules.TownGrid.WORLD_WIDTH) * 0.5 - size.x * 0.5


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
	for panel in [%Bank, %ExcitementMeter, %Earnings, %EventButton]:
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
	%EventButton.set_pressed_no_signal(%EventDrawer.visible)
	build_button.set_pressed_no_signal(build_drawer.visible)
	if opening:
		(%CloseHeroes if drawer == %HeroesDrawer else (close_build if drawer == build_drawer else (%CloseEvent if drawer == %EventDrawer else %CloseArena))).grab_focus()


func _close_drawers() -> void:
	var button: Button = %HeroesButton if %HeroesDrawer.visible else (build_button if build_drawer.visible else (%EventButton if %EventDrawer.visible else %ArenaButton))
	var was_open: bool = %Dismiss.visible
	%HeroesDrawer.hide()
	%ArenaDrawer.hide()
	%EventDrawer.hide()
	build_drawer.hide()
	build_button.set_pressed_no_signal(false)
	%Dismiss.hide()
	%HeroesButton.set_pressed_no_signal(false)
	%ArenaButton.set_pressed_no_signal(false)
	%EventButton.set_pressed_no_signal(false)
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
	for panel in [%Bank, %Earnings, %ExcitementMeter, %Footer, %HeroesDrawer, %ArenaDrawer, %EventDrawer, %MenuPanel]:
		panel.add_theme_stylebox_override("panel", _panel(Color("172937f5"), Color("6e7c7c")))
	for drawer in [%HeroesDrawer, %ArenaDrawer, %EventDrawer]:
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
		card.custom_minimum_size.y = 62
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
		row.add_child(_hero_portrait(id))
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
	if id in selected:
		selected.erase(id)
	elif not fight.active and fight.ready(id) and selected.size() < fight.fighter_capacity():
		selected.append(id)
	else:
		return
	if not fight.active:
		_show_fighters(selected.filter(func(hero_id: int): return fight.ready(hero_id)))
	%Status.text = "Preferred lineup updated / next fight" if fight.active else ("The arena is ready" if fight.valid_lineup(selected) else "Choose at least two heroes")
	%Commentary.text = "Book 2–%d available heroes. Unavailable preferences wait on the bench." % fight.fighter_capacity()
	%Commentary.tooltip_text = %Commentary.text
	_refresh()
	_save()


func _refresh() -> void:
	for id in range(cards.size()):
		var preferred: bool = id in selected
		var state: Dictionary = fight.availability(id)
		cards[id].set_pressed_no_signal(preferred and (state.ready or (fight.active and id in fight.participants)))
		cards[id].disabled = (not preferred and (fight.active or not state.ready or selected.size() >= fight.fighter_capacity())) if fight.heroes[id].owned else not fight.can_recruit(id)
		cards[id].add_theme_stylebox_override("disabled", _panel(Color("30352f"), GOLD, 2) if preferred else _panel(Color("131b25"), Color("293444")))
		cards[id].modulate = Color.WHITE if preferred or state.ready else Color("a8adb0")
		var hero: Dictionary = fight.heroes[id]
		var stats := fight.stats_for(id)
		var needed := fight.xp_needed(id)
		var details: Dictionary = card_details[id]
		card_records[id].text = " / %d wins" % hero.wins
		details.level.text = "LV %d / %s" % [hero.level, "%d/%d XP" % [hero.xp, needed] if needed > 0 else "MAX"]
		details.xp.max_value = needed if needed > 0 else 1
		details.xp.value = hero.xp if needed > 0 else 1
		details.stats.text = "%d HP / %d ATK" % [stats.health, stats.attack]
		details.skill.text = hero.skill.name
		cards[id].tooltip_text = "%s / %s\n%s\n%d HP / %d ATK / %d career wins\nOne stamina per fight. Three defeats cause injury. A minute on the bench removes one injury point.\nFatigue recovers in 60s. Injuries recover freely; Hospital beds accelerate treatment.\n10 XP per fight, +10 for winning. Each level adds 5%% base HP/ATK.\n%s" % [hero.name, _hero_condition(id), state.reason, stats.health, stats.attack, hero.wins, hero.skill.description]
		if preferred:
			cards[id].tooltip_text += "\nPreferred lineup / click to remove this preference."
		if not hero.owned:
			details.level.text = "Recruit / %d gold" % FightRules.RECRUIT_COSTS[id]
			cards[id].tooltip_text = "%s / %s\nRecruit for %d gold. Hall capacity: %d/%d.\n%s" % [hero.name, hero.unit.capitalize(), FightRules.RECRUIT_COSTS[id], fight.owned_count(), fight.roster_capacity(), hero.skill.description]
	_refresh_money()
	_refresh_excitement(fight.excitement)
	%Record.text = "%d fights / %d of %d recruited / %d available" % [fight.completed, fight.owned_count(), fight.roster_capacity(), range(fight.heroes.size()).filter(func(id: int): return fight.ready(id)).size()]
	var eligible: Array = selected.filter(func(id: int): return fight.ready(id))
	%Selection.text = "HEROES / %d PREFERRED" % selected.size()
	%HeroesButton.text = "Heroes %d/%d" % [fight.participants.size() if fight.active else eligible.size(), fight.fighter_capacity()]
	%Hint.text = "Click a preferred hero to unbook. Stop the fight to add heroes." if fight.active else "Choose 2–%d ready heroes. Unavailable preferences wait; Auto-fill uses reserves." % fight.fighter_capacity()
	%Hint.tooltip_text = %Hint.text
	var quote := fight.income_breakdown(fight.next_lineup(selected) if not fight.active and fight.auto_fill_owned and fight.auto_fill_enabled else selected)
	%Income.text = "%d gold" % quote.guaranteed if not quote.is_empty() else "Choose 2 heroes"
	%Formula.text = "%d base\n+%d hero levels\n+%d career victories\nx%.1f arena capacity" % [quote.base, quote.levels, quote.victories, quote.multiplier] if not quote.is_empty() else "Book at least two heroes to see\nthe income breakdown."
	%Formula.tooltip_text = "Base = (100 + 5 per level above 1 + 5 per victory, first 50 per hero) x seats / 100. Excitement multiplies the fight reward. Tips and Restaurant sales are separate."
	%Start.disabled = not auto_fight and ((not fight.valid_lineup(selected) and not (fight.auto_fill_owned and fight.auto_fill_enabled)) or fight.active)
	%Start.text = ("End after fight" if fight.active else "End event") if auto_fight else "Start event / %d fights" % EVENT_ROUNDS
	%Start.tooltip_text = "End this event and keep all earned rewards." if auto_fight else "Book %d automatic fights with your preferred heroes. Review their condition in Heroes. The next event needs a new booking." % EVENT_ROUNDS
	if fight.active and not auto_fight:
		%Start.text = "Finishing fight..."
	_refresh_recovery()
	_refresh_facility()
	management_revision = fight.management_revision


func _refresh_recovery() -> void:
	if rotate_button != null:
		rotate_button.disabled = fight.active or fight.ready_lineup().size() < 2 or fight.ready_lineup() == selected
	_refresh_objective()
	for id in range(card_details.size()):
		var owned: bool = fight.heroes[id].owned
		var state: Dictionary = fight.availability(id)
		card_details[id].rest.text = ("%s / %d/%d stamina / injury %d/3" % [_hero_condition(id), fight.heroes[id].stamina, fight.max_stamina(), fight.defeat_strain[id]]) if owned else "Not recruited"
		card_details[id].rest.add_theme_color_override("font_color", Color("efa68d") if fight.injury_remaining[id] > 0 else (GOLD if not state.ready and state.state != "fighting" else Color("a5ddc4")))
	if auto_fight and not fight.active:
		var waiting := PackedStringArray()
		for id in selected:
			if not fight.ready(id):
				waiting.append("%s: %s" % [fight.heroes[id].name, _hero_condition(id)])
		if selected.size() < 2 and not (fight.auto_fill_owned and fight.auto_fill_enabled):
			%Status.text = "Book at least two heroes / open Heroes to choose"
		elif not waiting.is_empty() and not (fight.auto_fill_enabled and fight.next_lineup(selected).size() >= 2):
			%Status.text = "Waiting / " + " / ".join(waiting)
		elif fight.next_lineup(selected).size() < 2:
			%Status.text = "Waiting for two available heroes"
		%Start.text = "End event"
		%Start.tooltip_text = "End the current event; completed fights stay paid. Recovery is free and does not use a round."
	_refresh_event()
	if not fight.active:
		for id in fighters:
			fighters[id].body.visible = fight.ready(id)


func _refresh_event() -> void:
	var running := auto_fight or fight.active
	var title := "EVENT IN PROGRESS" if running else ("EVENT COMPLETE" if event_rounds >= EVENT_ROUNDS else ("EVENT ENDED EARLY" if event_rounds > 0 else "PREPARE AN EVENT"))
	%EventTitle.text = title
	%EventButton.text = ("Event / %d of %d fights" % [event_rounds, EVENT_ROUNDS]) if running else ("Event complete / Review results" if event_rounds >= EVENT_ROUNDS else ("Event ended / Review results" if event_rounds > 0 else "Prepare event / %d fights" % EVENT_ROUNDS))
	%EventButton.tooltip_text = "Review this event's rewards and hero condition. Recovery and training continue between events."
	%EventButton.add_theme_color_override("font_color", GOLD if not running and event_rounds > 0 else Color("edf1f7"))
	var total_xp := 0
	var lines := PackedStringArray()
	var ids: Array = event_progression.keys()
	if ids.is_empty():
		ids = fight.participants if fight.active else (fight.next_lineup(selected) if fight.auto_fill_owned and fight.auto_fill_enabled else selected)
	for id in ids:
		var hero: Dictionary = fight.heroes[id]
		var earned: Dictionary = event_progression.get(id, {"xp": 0, "before": hero.level})
		total_xp += int(earned.xp)
		var level := "Lv.%d" % hero.level if hero.level == earned.before else "Lv.%d → %d" % [earned.before, hero.level]
		lines.append("%s / +%d fight XP / %s now\n%s / stamina %d/%d / injury %d/3" % [hero.name, earned.xp, level, _hero_condition(id), hero.stamina, fight.max_stamina(), fight.defeat_strain[id]])
	%EventHeroes.text = "\n\n".join(lines) if not lines.is_empty() else ("Auto-fill is waiting for two ready heroes." if fight.auto_fill_owned and fight.auto_fill_enabled else "Choose heroes or enable Auto-fill in Arena.")
	%EventSummary.text = "%d / %d fights completed / %d gold earned / %d fight XP\nRewards from completed fights are already paid." % [event_rounds, EVENT_ROUNDS, event_gold, total_xp]
	%EventNote.text = "Fights and recovery run automatically within this event. Auto-fill uses ready reserves." if running else "Review your heroes, rotate reserves or visit facilities, then start the next event."
	if not running and event_rounds == 0:
		%EventSummary.text = "%d automatic fights, then the arena waits for your next booking.\nEach fight pays immediately. Recovery does not use a round." % EVENT_ROUNDS


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
		%FightIncome.text = "%d base / next fight" % fight.income_for(selected) if fight.valid_lineup(selected) else "Book two heroes"
	%FightIncome.tooltip_text = "Fight payout excludes tips already in your bank. Base income is locked at fight start; excitement multiplies it. Open Arena for the next booking's breakdown."
	if tavern_income != null:
		tavern_income.text = "Restaurant: %d %s" % [fight.tavern_payout if fight.active else fight.settled_tavern, "at finish" if fight.active else "paid / last fight"]
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
			%Status.text = "Event ended / %d fights completed" % event_rounds
	elif not fight.active and (fight.valid_lineup(selected) or (fight.auto_fill_owned and fight.auto_fill_enabled)):
		event_rounds = 0
		event_gold = 0
		event_progression.clear()
		auto_fight = true
		_close_drawers()
		_try_begin_fight()
	_refresh()


func _begin_fight() -> void:
	if event_rounds >= EVENT_ROUNDS or not fight.start(fight.next_lineup(selected)):
		return
	_show_fighters(fight.participants)
	cheer = 0.0
	if excitement_pulse and excitement_pulse.is_valid():
		excitement_pulse.kill()
	%ExcitementMeter.modulate = Color.WHITE
	displayed_tier = 0
	%Status.text = "Event fight %d/%d / %d base gold" % [event_rounds + 1, EVENT_ROUNDS, fight.payout]
	%Commentary.text = "Defeats build injury risk / rotate reserves before three defeats"
	%Commentary.tooltip_text = %Commentary.text
	%Status.tooltip_text = %Status.text
	%Tick.stop()
	_refresh()


func _try_begin_fight() -> void:
	if not (fight.auto_fill_owned and fight.auto_fill_enabled) and selected.any(func(id: int): return not fight.ready(id)):
		return
	if not in_main_menu and auto_fight and event_rounds < EVENT_ROUNDS and not fight.active and %Tick.is_stopped():
		_begin_fight()


func _intermission_finished() -> void:
	%Tick.stop()
	_try_begin_fight()


func _physics_process(delta: float) -> void:
	if in_main_menu:
		return
	var was_active := fight.active
	var events := fight.advance(delta)
	if management_revision != fight.management_revision:
		_refresh()
		%World.sync_management(fight)
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
	management_tick += delta
	if management_tick >= 0.25:
		management_tick = 0.0
		_refresh_facility()
		%World.sync_management(fight)
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
		event_rounds += 1
		event_gold += fight.settled_income + fight.crowd_tips + fight.settled_tavern
		for progress in event.progression:
			if not event_progression.has(progress.hero):
				event_progression[progress.hero] = {"xp": 0, "before": progress.before}
			event_progression[progress.hero].xp += progress.xp
		if event_rounds >= EVENT_ROUNDS:
			auto_fight = false
			%Tick.stop()
		var winner: Dictionary = fight.heroes[event.winner]
		%Status.text = "%s wins!  /  +1 career victory" % winner.name
		var multiplier: float = FightRules.EXCITEMENT_MULTIPLIERS[FightRules.excitement_tier(event.excitement)]
		%Commentary.text = "%d fight + %d tips + %d Restaurant = %d gold" % [fight.settled_income, fight.crowd_tips, fight.settled_tavern, fight.settled_income + fight.crowd_tips + fight.settled_tavern]
		%Commentary.tooltip_text = "%d base x%.2f = %d fight income. Tips already paid: %d. Restaurant sales: %d. Total: %d gold." % [fight.payout, multiplier, fight.settled_income, fight.crowd_tips, fight.settled_tavern, fight.settled_income + fight.crowd_tips + fight.settled_tavern]
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
		if event_rounds >= EVENT_ROUNDS:
			%Status.text = "Event complete / %d fights / %d gold earned" % [event_rounds, event_gold]
			%Commentary.text = "Review results and prepare your next event"
			%Commentary.tooltip_text = "Open Review results above the arena to inspect event rewards and hero condition. Start event books the next %d fights." % EVENT_ROUNDS
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
		var sprite := Actor.new()
		body.add_child(sprite)
		sprite.setup(id, hero.unit, hero.red)
		sprite.play("idle")
		sprite.animation_finished.connect(func():
			if not fight.health.has(id) or fight.health[id] > 0:
				sprite.play("idle"))
		var bars := {}
		for stat in ["health", "mana"]:
			var bar := ProgressBar.new()
			bar.position = Vector2(-15, -43 if stat == "health" else -38)
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
			bar.set_deferred("size", Vector2(30, 3))
			bars[stat] = bar
		var nameplate := _label(hero.name, 11, Color("edf1f7"))
		nameplate.add_theme_color_override("font_outline_color", Color("18222f"))
		nameplate.add_theme_constant_override("outline_size", 4)
		nameplate.position = Vector2(-60, 6)
		nameplate.size.x = 120
		body.add_child(nameplate)
		nameplate.hide()
		var hover := Control.new()
		hover.position = Vector2(-16, -36)
		hover.size = Vector2(32, 42)
		hover.mouse_filter = Control.MOUSE_FILTER_PASS
		hover.tooltip_text = "%s / Lv.%d / %s" % [hero.name, hero.level, hero.skill.name]
		hover.mouse_entered.connect(nameplate.show)
		hover.mouse_exited.connect(nameplate.hide)
		body.add_child(hover)
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
	# Fan small health/mana pairs when fighters overlap, without moving combatants.
	var occupied: Array[Rect2] = []
	for id in fighters:
		var fighter: Dictionary = fighters[id]
		var at: Vector2 = fighter.body.position
		var chosen := Vector2(-15, -43)
		for offset in [Vector2.ZERO, Vector2(-18, -10), Vector2(18, -10), Vector2(-36, -20), Vector2(36, -20), Vector2(0, -30)]:
			var candidate: Vector2 = at + Vector2(-15, -43) + offset
			candidate.y = maxf(10, candidate.y)
			var rect := Rect2(candidate - Vector2(2, 2), Vector2(34, 12))
			if occupied.all(func(other: Rect2): return not other.intersects(rect)):
				chosen = candidate - at
				occupied.append(rect)
				break
		fighter.bar.position = chosen.round()
		fighter.mana.position = chosen.round() + Vector2(0, 5)
	%Stage.queue_redraw()


func _ground_scale() -> float:
	return 90.0 / FightRules.ARENA_RADIUS


func _project(ground: Vector2) -> Vector2:
	return Vector2(%Stage.size.x * 0.5, 124.0) + ground * _ground_scale()


func _circle_points(origin: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(65):
		points.append(_project(origin + Vector2.from_angle(TAU * i / 64.0) * radius))
	return points


func _draw_ring() -> void:
	var center := _project(Vector2.ZERO)
	# Two-pixel scanlines give the circular court the same pixel size as the atlas.
	for layer in [[96, 4, "344b43"], [96, 0, "485a53"], [94, -2, "a6aa85"], [90, 0, "e2bf80"], [86, 0, "d4ae73"]]:
		var radius: int = layer[0]
		for y in range(-radius, radius, 2):
			var half_width := floorf(sqrt(maxf(0.0, radius * radius - (y + 1) * (y + 1))) / 2.0) * 2.0
			%Stage.draw_rect(Rect2(center + Vector2(-half_width, y + layer[1]), Vector2(half_width * 2, 2)), Color(layer[2]))
	for i in range(28):
		var direction := Vector2.from_angle(TAU * i / 28.0)
		var outer := (center + direction * 94).snapped(Vector2(2, 2))
		var inner := (center + direction * 90).snapped(Vector2(2, 2))
		%Stage.draw_line(inner, outer, Color("61705c"), 2, false)
	for i in range(54):
		var at := (center + Vector2.from_angle(i * 2.399) * sqrt(float(i) / 54.0) * 80).snapped(Vector2(2, 2))
		%Stage.draw_rect(Rect2(at, Vector2(4 if i % 4 == 0 else 2, 2)), Color("bb955f") if i % 3 == 0 else Color("e0ba7c"))
	# A short stone threshold connects the court to the public path.
	for step in range(3):
		%Stage.draw_rect(Rect2(center.x - 14 - step * 2, 216 + step * 4, 28 + step * 4, 4), Color("667463"))
		%Stage.draw_rect(Rect2(center.x - 12 - step * 2, 216 + step * 4, 24 + step * 4, 2), Color("b4b58e"))
	# Each wing uses representative spectators; purchased seats remain economic capacity.
	var columns := 2 + fight.arena_tier
	for side in [-1, 1]:
		var wing_left: float = center.x + (100 if side > 0 else -132 - (columns - 1) * 27)
		var wing_width := columns * 27 + 5
		%Stage.draw_rect(Rect2(wing_left - 2, 42, wing_width + 4, 176), Color("344b43"))
		%Stage.draw_rect(Rect2(wing_left, 38, wing_width, 174), Color("654b39"))
		%Stage.draw_rect(Rect2(wing_left + 2, 40, wing_width - 4, 168), Color("aa7c49"))
		for plank in range(10):
			%Stage.draw_rect(Rect2(wing_left + 2, 44 + plank * 16, wing_width - 4, 2), Color("805d3e"))
		for edge in [wing_left, wing_left + wing_width - 4]:
			%Stage.draw_rect(Rect2(edge, 34, 4, 180), Color("594b39"))
			%Stage.draw_rect(Rect2(edge, 34, 2, 176), Color("c59858"))
			%Stage.draw_rect(Rect2(edge - 2, 34, 8, 4), Color("e1bc77"))
		%Stage.draw_rect(Rect2(wing_left - 2, 208, wing_width + 4, 4), Color("d0a365"))
		%Stage.draw_rect(Rect2(wing_left + 4, 214, wing_width - 8, 4), Color("af8852"))
		for column in range(columns):
			var x: float = center.x + side * (116 + column * 27)
			for seat in range(7):
				var bench_y := 54 + seat * 23
				%Stage.draw_rect(Rect2(x - 12, bench_y, 24, 6), Color("70523a"))
				%Stage.draw_rect(Rect2(x - 12, bench_y, 24, 2), Color("dfb373"))
				var frame := (int(crowd_clock * 5) + seat + column) % 9
				var bounce := roundf(maxf(0.0, sin(crowd_clock * 7 + seat)) * cheer * 4)
				var foot := Vector2(x, 58 + seat * 23 - bounce)
				var target := Rect2(foot - Vector2(16, 26), Vector2(32, 40))
				var source := Rect2(frame * 96 + 32, 13, 32, 40)
				%Stage.draw_texture_rect_region(SPECTATOR, target, source, Color("ead8bc") if (seat + column) % 2 == 0 else Color.WHITE)
				%Stage.draw_texture_rect_region(SPECTATOR_HAIRS[(seat + column) % 3], target, source, [Color("dca583"), Color("ffdf99"), Color("766776")][(seat + column) % 3])
		var flag_at := center + Vector2(side * (120 + columns * 27), -72)
		%Stage.draw_rect(Rect2(flag_at + Vector2(-4, 50), Vector2(12, 4)), Color("485a53"))
		%Stage.draw_rect(Rect2(flag_at, Vector2(4, 50)), Color("705038"))
		%Stage.draw_rect(Rect2(flag_at, Vector2(2, 48)), Color("cba66b"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(4, -2), Vector2(20, 28)), Color("354f50") if side < 0 else Color("794c40"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(6, 0), Vector2(16, 22)), Color("548e88") if side < 0 else Color("b9684e"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(6, 0), Vector2(16, 2)), Color("a5c3a1") if side < 0 else Color("e49b66"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(12, 6), Vector2(4, 10)), Color("e6c77d"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(10, 10), Vector2(8, 2)), Color("e6c77d"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(-2, -8), Vector2(8, 8)), Color("485a53"))
		%Stage.draw_rect(Rect2(flag_at + Vector2(0, -6), Vector2(4, 4)), Color("ffe3a0"))
	for id in fighters:
		var at: Vector2 = fighters[id].body.position.snapped(Vector2(2, 2))
		%Stage.draw_rect(Rect2(at - Vector2(10, 2), Vector2(20, 4)), Color("a48a60"))
		%Stage.draw_rect(Rect2(at - Vector2(6, 4), Vector2(12, 8)), Color("a48a60"))


func _sync_fighters() -> void:
	for id in fighters:
		var fighter: Dictionary = fighters[id]
		fighter.bar.value = fight.health[id]
		fighter.mana.value = fight.mana[id]
		fighter.mana.tooltip_text = "%d / 100 mana" % fight.mana[id]
		if fight.health[id] <= 0:
			if fighter.sprite.animation != "death":
				fighter.sprite.play("death")
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
	var sprite = source.sprite
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
		fighters[event.winner].name.show()
		fighters[event.winner].name.text = "%s / WINNER" % fight.heroes[event.winner].name
		fighters[event.winner].name.add_theme_color_override("font_color", GOLD)


func _tint_fighter(id: int, color: Color) -> void:
	var fighter: Dictionary = fighters[id]
	if fighter.tint and fighter.tint.is_valid():
		fighter.tint.kill()
	fighter.sprite.modulate = color
	fighter.tint = fighter.sprite.create_tween()
	fighter.tint.tween_property(fighter.sprite, "modulate", Color("515c68") if fight.health[id] == 0 else Color.WHITE, 0.4)
