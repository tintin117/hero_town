extends Node2D
## Rules own progress; authored scenes own presentation.
const Rules = preload("res://game/companion/farm_fight_state.gd")
const Presentation = preload("res://game/shared/presentation_scale.gd")
const COMPACT_HEIGHT := 220
const EXPANDED_HEIGHT := 640
@export_group("Campaign")
@export var balance: FarmFightBalance = preload("res://data/companion/farm_fight_balance.tres")
@export var save_path := Rules.SAVE
@export var persistence_enabled := true
@export_group("Presentation")
@export var land_scene: PackedScene = preload("res://game/companion/farm_land.tscn")
@export var land_variants: Array[PackedScene] = [preload("res://game/companion/farm_land.tscn"), preload("res://game/companion/farm_quarry.tscn"), preload("res://game/companion/farm_river.tscn")]
@export var unit_scene: PackedScene = preload("res://game/town/unit_view.tscn")
@export var combat_number_scene: PackedScene = preload("res://game/companion/combat_number.tscn")
@export var enemy_damage_color := Color("ffdc70")
@export var ally_damage_color := Color("ff8a7c")
@export var healing_color := Color("89f4aa")
@export var land_span := 1440.0
@export var scroll_speed := 420.0
@export var popup_top_margin := 12.0
@export var popup_edge_margin := 12.0
var game := Rules.new()
var land_width := 2880.0
var view_width := 960.0
var scroll_offset := 0.0
var scale_factor := 1.0
var previous_position := Vector2i.ZERO
var dragging := false
var drag_offset := Vector2i.ZERO
var taskbar_mode := false
var taskbar_screen := 0
var taskbar_pointer_down := false
var taskbar_dragged := false
var taskbar_press_position := Vector2i.ZERO
var taskbar_window_position := Vector2i.ZERO
var taskbar_positions: Dictionary = {}
var clock := 0.0
var save_clock := 0.0
var refresh_clock := 0.0
var toast_until := 0.0
var summary := ""
var popup_kind := ""
var selected_land := 0
var selected_class := "warrior"
var follow_frontier := false
var land_views: Dictionary = {}
var unit_views: Dictionary = {}
var panel_buttons: Array[Button] = []
@onready var settlement: Node2D = $Settlement
@onready var district: Node2D = $Settlement/TownDistrict
@onready var formation: Node2D = $Settlement/TownDistrict/Formation
@onready var damage_numbers: Node2D = $Settlement/TownDistrict/DamageNumbers
@onready var hud: Node2D = $HUD
@onready var gold: Button = $HUD/Bar/Gold
@onready var toast: Label = $HUD/Toast
@onready var popup: Panel = $ManagementPanel
@onready var sparring: Node2D = $TaskbarSparring

func _ready() -> void:
	GameState.persistence_enabled = false
	if game.balance != balance: game = Rules.new(balance)
	summary = game.load_game(save_path) if persistence_enabled else "Preview • saving disabled"
	land_width = (int(game.s.owned) + 2) * land_span
	for button in find_children("*", "Button", true, false):
		if button.has_meta("action"):
			var action: String = button.get_meta("action")
			var id: String = button.get_meta("class", "")
			var node: String = button.get_meta("node", "")
			button.pressed.connect(func(): perform(action, selected_class if action in ["build", "recruit"] else id, node))
			if popup.is_ancestor_of(button): panel_buttons.append(button)
	for tower in $Settlement/TownDistrict/Towers.get_children():
		var id: String = tower.class_id
		tower.selected.connect(func(): selected_class = id; open_panel("tower"))
		game.spawn_positions[id] = formation.to_local(tower.get_node("Spawn").global_position)
	for unit in game.simulation.units:
		if unit.side == 0: unit.home = game.spawn_positions[unit.army]
	$ManagementPanel/Research.game = game
	$ManagementPanel/Research.purchase_requested.connect(perform)
	$HUD/Guide.pressed.connect(guide_action)
	$HUD/Bar/Drag.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: drag_offset = Vector2i(event.global_position * scale_factor))
	$ManagementPanel/Farm/Land.value_changed.connect(func(value): select_land(int(value)))
	sparring.restore_requested.connect(restore_town)
	sparring.drag_started.connect(func(): begin_taskbar_drag(DisplayServer.mouse_get_position()))
	popup.hide()
	sparring.hide()
	configure_window()
	jump_frontier()
	refresh()
	show_toast(summary, 8)

func scroll_town(value: float) -> void:
	scroll_offset = clampf(value, 0.0, maxf(0, land_width - view_width))
	follow_frontier = scroll_offset + view_width >= land_width - 80
	settlement.position.x = -fposmod(scroll_offset, land_span)
	update_lands()

func layout_navigation() -> void:
	$HUD/Bar.size.x = view_width - 24
	toast.size.x = view_width - 32
	popup.size.x = minf(900, view_width - popup_edge_margin * 2)
	popup.position = Vector2((view_width - popup.size.x) / 2, popup_top_margin)
	$HUD/Guide.size.x = minf(680, view_width - 32)
	scroll_town(scroll_offset)

func update_lands() -> void:
	if not is_instance_valid(settlement): return
	var first := maxi(0, int(floor(scroll_offset / land_span)) - 1)
	var last := mini(int(game.s.owned) + 1, int(floor((scroll_offset + view_width) / land_span)) + 1)
	var origin := int(floor(scroll_offset / land_span))
	for index in land_views.keys():
		if index < first or index > last:
			land_views[index].queue_free()
			land_views.erase(index)
	for index in range(first, last + 1):
		if not land_views.has(index):
			var template: PackedScene = land_scene if index == 0 or land_variants.is_empty() else land_variants[(index - 1) % land_variants.size()]
			var land := template.instantiate()
			land_views[index] = land
			$Settlement/Lands.add_child(land)
			for resource in ["gold", "wood"]:
				land.get_node(resource.capitalize() + "Spot").selected.connect(func(): selected_land = index; open_panel("farm"))
		var view: Node2D = land_views[index]
		view.position.x = (index - origin) * land_span
		var owned := index <= int(game.s.owned)
		view.get_node("Title").text = balance.land_name(index) + (" • Farmland" if owned else " • Enemy frontier")
		for resource in ["gold", "wood"]:
			var spot = view.get_node(resource.capitalize() + "Spot")
			spot.visible = owned
			spot.update_spot(game.assigned(index, resource), balance.spot_capacity, game.spot_rate(index), owned)
	district.visible = int(game.s.owned) + 1 >= first and int(game.s.owned) + 1 <= last
	var fit := minf(1.0, view_width / land_span)
	district.scale = Vector2.ONE * fit
	district.position.y = 175.0 * (1.0 - fit)
	district.position.x = (int(game.s.owned) + 1 - origin) * land_span + land_span * (1.0 - fit) if district.visible else 0

func jump_frontier() -> void:
	scroll_town(land_width - view_width)
	follow_frontier = true

func select_land(index: int) -> void:
	selected_land = clampi(index, 0, int(game.s.owned))
	scroll_town(selected_land * land_span)
	update_panel()

func open_panel(kind: String) -> void:
	popup_kind = kind
	popup.show()
	set_height(EXPANDED_HEIGHT)
	layout_navigation()
	for group in ["Farm", "Tower", "Research"]:
		popup.get_node(group).visible = group.to_lower() == kind
	$ManagementPanel/Title.text = {"farm": "Farm • assign, hire, improve", "tower": selected_class.capitalize() + " tower", "research": "Hero skill tree"}.get(kind, kind.capitalize())
	update_panel()

func close_panel() -> void:
	popup.hide()
	popup_kind = ""
	set_height(COMPACT_HEIGHT)

static func number(value: float) -> String:
	for entry in [[1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]:
		if value >= entry[0]: return "%.1f%s" % [value / entry[0], entry[1]]
	return str(int(value))

func price_text(price: Dictionary) -> String:
	if price.is_empty(): return ""
	return number(price.gold) + "g" + (" + " + number(price.wood) + "w" if price.wood > 0 else "")

func perform(action: String, id := "", node := "") -> void:
	match action:
		"farm": select_land(selected_land); open_panel("farm"); return
		"research": open_panel("research"); return
		"frontier":
			if popup.visible: close_panel()
			jump_frontier()
			return
		"dock": dock(); return
		"fold": minimize_to_sparring(); return
		"close_panel": close_panel(); return
		"quit":
			if persist(): get_tree().quit()
			return
		"previous": select_land(selected_land - 1); return
		"next": select_land(selected_land + 1); return
		"latest": select_land(int(game.s.owned)); return
	var ok := game.assign_farmer(selected_land, id, int(node)) if action == "assign" else game.purchase(action, id, node)
	if ok:
		persist()
		refresh()
	else: show_toast("No idle farmer or spot is full" if action == "assign" else game.action_error(action, id, node))

func update_panel() -> void:
	if not popup.visible: return
	var farm := $ManagementPanel/Farm
	farm.get_node("Land").max_value = int(game.s.owned)
	farm.get_node("Land").set_value_no_signal(selected_land)
	farm.get_node("Summary").text = "%s • %d idle / %d farmers • efficiency %d" % [balance.land_name(selected_land), game.idle_farmers(), game.s.farmers, game.s.efficiency]
	for resource in ["gold", "wood"]:
		farm.get_node(resource.capitalize() + "/Info").text = "%s   %d / %d farmers\n%.2f per farmer / sec" % [resource.capitalize(), game.assigned(selected_land, resource), balance.spot_capacity, game.spot_rate(selected_land)]
	farm.get_node("Hire").text = "Hire farmer • " + price_text(game.quote("farmer"))
	farm.get_node("Efficiency").text = "Efficiency +%d%% • " % roundi(balance.efficiency_per_rank * 100) + price_text(game.quote("efficiency"))
	var tower := $ManagementPanel/Tower
	var built: bool = game.s.towers.has(selected_class)
	tower.get_node("Info").text = "%s\n%s\n%d / %d heroes alive • %.1fs spawn interval" % [balance.hero(selected_class).description, ("Next hero in %.1fs" % game.s.towers[selected_class].remaining) if built else "Unlock the class, then build its tower here.", game.simulation.living_class(selected_class), balance.hero_cap, game.spawn_seconds(selected_class)]
	for button_name in ["Build", "Recruit"]:
		var button: Button = tower.get_node(button_name)
		var action: String = button_name.to_lower()
		button.text = ("Tower built" if action == "build" and built else ("Build tower" if action == "build" else "Buy one hero") + " • " + price_text(game.quote(action, selected_class)))
		if action == "recruit" and built and game.s.towers[selected_class].get("recruit_remaining", 0.0) > 0:
			button.text = "Reinforcement • %.0fs" % ceil(game.s.towers[selected_class].recruit_remaining)
	$ManagementPanel/Research.refresh()
	for button in panel_buttons:
		var action: String = button.get_meta("action")
		var id: String = selected_class if action in ["build", "recruit"] else button.get_meta("class", "")
		var node: String = button.get_meta("node", "")
		if action == "assign":
			button.disabled = (game.idle_farmers() == 0 or game.assigned(selected_land, id) >= balance.spot_capacity) if node == "1" else game.assigned(selected_land, id) == 0
		elif action in ["build", "recruit", "farmer", "efficiency"]:
			button.disabled = not game.action_error(action, id, node).is_empty()
			button.tooltip_text = game.action_error(action, id, node)
		elif action == "previous": button.disabled = selected_land == 0
		elif action in ["next", "latest"]: button.disabled = selected_land >= int(game.s.owned)

func refresh() -> void:
	refresh_guide()
	gold.text = "%sg  +%.1f/s" % [number(game.s.gold), game.rates.gold]
	$HUD/Bar/Wood.text = "%sw  +%.1f/s" % [number(game.s.wood), game.rates.wood]
	$HUD/Bar/Farm.text = "Farm • %d idle" % game.idle_farmers()
	$HUD/Bar/Frontier.text = "Fight • %d" % (int(game.s.owned) + 1)
	for tower in $Settlement/TownDistrict/Towers.get_children(): tower.refresh(game)
	var target := game.simulation.tower()
	$Settlement/TownDistrict/Enemy/Health.value = 100.0 * target.hp / target.max_hp
	$Settlement/TownDistrict/Enemy/Status.text = "%s / %s HP\nWave %d • %.1fs" % [number(target.hp), number(target.max_hp), int(game.s.wave) + 1, game.s.wave_remaining]
	update_lands()
	update_panel()

func guide_step() -> int:
	if game.s.owned > 0: return 4
	if game.rates.gold <= 0 or game.rates.wood <= 0 or (int(game.s.hired) == 0 and game.idle_farmers() > 0): return 0
	if int(game.s.research.warrior.power) + int(game.s.research.warrior.health) == 0: return 1
	if int(game.s.hired) == 0 or game.idle_farmers() > 0: return 2
	return 3

func refresh_guide() -> void:
	var step := guide_step()
	$HUD/Guide.visible = step < 4
	$HUD/Guide.text = [
		"1 / 4   Your Warrior holds the line. Assign farmers to gold and wood.   >",
		"2 / 4   Save gold, then choose a Warrior upgrade in the skill tree.   >",
		"3 / 4   Hire another farmer to grow your income.   >" if int(game.s.hired) == 0 else "3 / 4   Assign your new farmer to gold to fund more upgrades.   >",
		"4 / 4   Keep upgrading. Break the enemy tower to claim richer farmland.   >",
		""][step]

func guide_action() -> void:
	match guide_step():
		0, 2: perform("farm")
		1:
			$ManagementPanel/Research.select_skill("warrior", "power")
			perform("research")
		3: perform("frontier")

func sync_units(delta: float) -> void:
	var live := {}
	for unit in game.simulation.units:
		if unit.get("objective", false): continue
		var id := int(unit.id)
		live[id] = true
		if not unit_views.has(id):
			var view := unit_scene.instantiate() as ArmyUnitView
			view.model = unit
			unit_views[id] = view
			formation.add_child(view)
		if not taskbar_mode and district.visible: unit_views[id].update_view(delta, game.simulation.elapsed)
	for id in unit_views.keys():
		if not live.has(id):
			var view: ArmyUnitView = unit_views[id]
			view.model.hp = 0
			view.update_view(delta, game.simulation.elapsed)
			get_tree().create_timer(view.death_fade_seconds + 0.05).timeout.connect(view.queue_free)
			unit_views.erase(id)

func show_toast(text: String, duration := 5.0) -> void:
	toast.text = text
	toast_until = clock + duration
	toast.show()
	update_mouse_region()

func persist() -> bool:
	if not persistence_enabled: return true
	if not game.save_game(save_path):
		show_toast("Save failed. " + game.save_error, 15)
		return false
	return true

func _process(delta: float) -> void:
	clock += delta
	save_clock += delta
	refresh_clock += delta
	if not popup.visible and not taskbar_mode:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0: scroll_town(scroll_offset + direction * scroll_speed * delta)
	if dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): get_window().position = DisplayServer.mouse_get_position() - drag_offset
		else: dragging = false; clamp_to_work_area()
	# Suspension is not gameplay time; ordinary background frames continue.
	var events := game.advance(minf(delta, 0.25))
	for event in events:
		if event.kind == "conquered":
			var following := follow_frontier
			land_width = (int(game.s.owned) + 2) * land_span
			if following: jump_frontier()
			show_toast("%s conquered • richer gold and wood spots opened" % balance.land_name(int(event.land)))
			persist()
		elif event.kind == "hit" and unit_views.has(int(event.unit)):
			unit_views[int(event.unit)].flash_remaining = 0.09
		if event.kind in ["hit", "heal"] and not taskbar_mode and district.visible and damage_numbers.get_child_count() < 24:
			var label: Label = combat_number_scene.instantiate()
			label.text = number(event.amount)
			label.position = event.position + formation.position + Vector2(-10, -40)
			label.modulate = healing_color if event.kind == "heal" else (ally_damage_color if event.get("side", 1) == 0 else enemy_damage_color)
			damage_numbers.add_child(label)
			var tween := label.create_tween()
			tween.tween_property(label, "position:y", label.position.y - 20, 0.7)
			tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
			tween.tween_callback(label.queue_free)
	sync_units(delta)
	queue_redraw()
	if refresh_clock >= 0.2: refresh_clock = 0; refresh()
	if save_clock >= 5: save_clock = 0; persist()
	if toast.visible and clock > toast_until: toast.hide(); update_mouse_region()
	if get_window().position != previous_position and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clamp_to_work_area()
		previous_position = get_window().position

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if persist(): get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT: persist()

func _draw() -> void:
	if not is_node_ready() or taskbar_mode or not district.visible: return
	for shot in game.simulation.projectiles:
		var target := game.simulation.find_unit(int(shot.target))
		if target.is_empty(): continue
		var direction: Vector2 = (target.position - shot.position).normalized()
		var tip := to_local(formation.to_global(shot.position + Vector2(0, -18)))
		var color := Color("8fd8ff") if shot.side == 0 else Color("ff9e7f")
		draw_line(tip - direction * 12, tip, color, 2)
		draw_line(tip - direction.rotated(0.55) * 5, tip, color, 2)
		draw_line(tip - direction.rotated(-0.55) * 5, tip, color, 2)

func configure_window() -> void:
	var w := get_window()
	w.title = "Hero Town • Farm and Fight"
	w.min_size = Vector2i(1,1)
	w.mode = Window.MODE_WINDOWED
	w.borderless = true
	w.unresizable = true
	w.always_on_top = true
	w.transparent = true
	w.transparent_bg = true
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	scale_factor = Presentation.window_width(w) / 960.0
	if DisplayServer.get_name() != "headless":
		scale_factor = minf(scale_factor, (DisplayServer.screen_get_usable_rect(w.current_screen).size.y - 32.0) / EXPANDED_HEIGHT)
		view_width = floorf(DisplayServer.screen_get_usable_rect(w.current_screen).size.x / scale_factor)
	# Map extent and painted cells belong to the scene, including intentional gaps.
	view_width = minf(view_width, land_width)
	layout_navigation()
	set_height(COMPACT_HEIGHT)
	dock()
	Engine.max_fps = 30
func minimize_to_sparring() -> void:
	if taskbar_mode: return
	taskbar_screen = get_window().current_screen
	persist()
	if popup.visible: close_panel()
	dragging = false
	taskbar_mode = true
	settlement.hide()
	hud.hide()
	sparring.show()
	var window := get_window()
	window.content_scale_size = sparring.VIEW_SIZE
	window.size = Vector2i(roundi(sparring.VIEW_SIZE.x * scale_factor), roundi(sparring.VIEW_SIZE.y * scale_factor))
	dock(taskbar_screen)
	update_mouse_region()

func restore_town() -> void:
	if not taskbar_mode: return
	taskbar_pointer_down = false
	taskbar_mode = false
	sparring.hide()
	settlement.show()
	hud.show()
	set_height(COMPACT_HEIGHT, taskbar_screen)
	dock(taskbar_screen)

func begin_taskbar_drag(pointer: Vector2i) -> void:
	if not taskbar_mode: return
	taskbar_pointer_down = true
	taskbar_dragged = false
	taskbar_press_position = pointer
	taskbar_window_position = get_window().position

func move_taskbar_drag(pointer: Vector2i) -> void:
	if not taskbar_pointer_down: return
	var distance := pointer.x - taskbar_press_position.x
	if abs(distance) >= 6: taskbar_dragged = true
	if not taskbar_dragged: return
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(taskbar_screen)
	window.position = Vector2i(clampi(taskbar_window_position.x + distance, usable.position.x, maxi(usable.position.x, usable.end.x - window.size.x)), usable.end.y - window.size.y)
	taskbar_positions[taskbar_screen] = window.position.x
	previous_position = window.position

func end_taskbar_drag() -> void:
	if not taskbar_pointer_down: return
	taskbar_pointer_down = false
	if not taskbar_dragged: restore_town()

func set_height(height: int, target_screen := -1) -> void:
	var w := get_window()
	var bottom := w.position.y+w.size.y
	var target_position := w.position
	var usable := Rect2i()
	if DisplayServer.get_name() != "headless":
		var screen := w.current_screen if target_screen < 0 else clampi(target_screen, 0, DisplayServer.get_screen_count() - 1)
		usable = DisplayServer.screen_get_usable_rect(screen)
		# Expand from inside the original monitor, never across its right edge.
		w.position = usable.position
	w.content_scale_size = Vector2i(roundi(view_width),height)
	w.size = Vector2i(roundi(view_width*scale_factor),roundi(height*scale_factor))
	if DisplayServer.get_name() != "headless":
		w.position = Vector2i(clampi(target_position.x, usable.position.x, maxi(usable.position.x, usable.end.x-w.size.x)), clampi(bottom-w.size.y, usable.position.y, maxi(usable.position.y, usable.end.y-w.size.y)))
	else: w.position.y = bottom-w.size.y
	settlement.position.y = height-COMPACT_HEIGHT
	hud.position.y = height-COMPACT_HEIGHT
	update_mouse_region()
func dock(target_screen := -1) -> void:
	if DisplayServer.get_name()=="headless": return
	var w := get_window()
	var screen := w.current_screen if target_screen < 0 else clampi(target_screen, 0, DisplayServer.get_screen_count()-1)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var dock_x := usable.end.x - w.size.x if taskbar_mode else usable.position.x + (usable.size.x - w.size.x) / 2
	if taskbar_mode and taskbar_positions.has(screen):
		dock_x = clampi(taskbar_positions[screen], usable.position.x, maxi(usable.position.x, usable.end.x-w.size.x))
	w.position = Vector2i(dock_x,usable.end.y-w.size.y)
	previous_position = w.position
func clamp_to_work_area() -> void:
	if DisplayServer.get_name()=="headless" or get_window().mode==Window.MODE_MINIMIZED: return
	var w := get_window()
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.position = Vector2i(clampi(w.position.x,usable.position.x,maxi(usable.position.x,usable.end.x-w.size.x)),clampi(w.position.y,usable.position.y,maxi(usable.position.y,usable.end.y-w.size.y)))
func update_mouse_region() -> void:
	if taskbar_mode:
		get_window().mouse_passthrough_polygon = PackedVector2Array([
			Vector2(10, 22) * scale_factor, Vector2(210, 22) * scale_factor,
			Vector2(210, 84) * scale_factor, Vector2(10, 84) * scale_factor])
		return
	# The visible town band stays interactive at every horizontal scroll position.
	var top := settlement.position.y + 30.0
	if popup.visible: top = 8.0
	elif toast.visible and clock < toast_until: top = settlement.position.y + 8.0
	get_window().mouse_passthrough_polygon = PackedVector2Array([
		Vector2(0, top) * scale_factor, Vector2(view_width, top) * scale_factor,
		Vector2(view_width, settlement.position.y + 220) * scale_factor,
		Vector2(0, settlement.position.y + 220) * scale_factor])

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and popup.visible: close_panel()
func _input(event: InputEvent) -> void:
	if taskbar_mode and taskbar_pointer_down:
		if event is InputEventMouseMotion:
			move_taskbar_drag(DisplayServer.mouse_get_position())
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			move_taskbar_drag(DisplayServer.mouse_get_position())
			end_taskbar_drag()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and not popup.visible and not taskbar_mode:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			scroll_town(scroll_offset - 80)
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_town(scroll_offset + 80)
			get_viewport().set_input_as_handled()
	if dragging and event is InputEventMouseMotion:
		get_window().position = DisplayServer.mouse_get_position()-drag_offset
	if dragging and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		dragging=false
		clamp_to_work_area()
