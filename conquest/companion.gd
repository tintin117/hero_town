extends Node2D
## A separate desktop presentation of the same conquest rules.
const Rules = preload("res://conquest/conquest_state.gd")
const Presentation = preload("res://scripts/presentation_scale.gd")
const COMPACT_HEIGHT := 220
const EXPANDED_HEIGHT := 500
@export var save_path := "user://conquest_companion_v1.json"
@export var seed_from_full_window := true
var game = Rules.new()
@export var balance: ConquestBalance = Rules.DEFAULT_BALANCE:
	set(value):
		balance = value
		game = Rules.new(value)
@export_range(960.0, 20000.0) var land_width := 2880.0
@export var warrior_scene: PackedScene = preload("res://conquest/units/warrior.tscn")
@export var mage_scene: PackedScene = preload("res://conquest/units/mage.tscn")
@export var enemy_scene: PackedScene = preload("res://conquest/units/enemy.tscn")
@export var ally_spacing := Vector2(27, 14)
@export var enemy_spacing := Vector2(25, 20)
@export_range(1, 20) var ally_columns := 5
@export_range(1, 20) var enemy_columns := 4
var buildings: Array[ConquestBuilding] = []
var resource_spots: Dictionary = {}
var villager_views: Dictionary = {}
var selected_spot: ConquestResourceSpot
const ACTION_SCENE = preload("res://conquest/ui/action.tscn")
var settlement: Node2D
var formation: Node2D
var popup: Panel
var popup_body: Label
var popup_kind := ""
var popup_anchor := 480.0
var gold: Button
var frontier: Button
var activity: Dictionary = {}
var animations: Array[Sprite2D] = []
var flash: Dictionary = {}
var clock := 0.0
var save_clock := 0.0
var stamp := ""
var summary := ""
var toast: Label
var toast_until := 0.0
var scale_factor := 1.0
var previous_position := Vector2i.ZERO
var dragging := false
var drag_offset := Vector2i.ZERO
var fire: Sprite2D
var damage_numbers: Node2D
var last_damage_step := -1
var last_counter_step := -1


var panel_buttons: Array[Button] = []
var trainees: Array[AnimatedSprite2D] = []
var hud: Node2D
var view_width := 960.0
var scroll_offset := 0.0
var right_controls: Array[Control] = []
var taskbar_mode := false
var taskbar_screen := 0
var taskbar_pointer_down := false
var taskbar_dragged := false
var taskbar_press_position := Vector2i.ZERO
var taskbar_window_position := Vector2i.ZERO
var taskbar_positions: Dictionary = {}
var sparring: Node2D
var district: Node2D
var workers: Node2D
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settlement = $Settlement
	district = $Settlement/TownDistrict
	formation = $Settlement/TownDistrict/Formation
	damage_numbers = $Settlement/TownDistrict/DamageNumbers
	workers = $Settlement/WorkingHamlet
	hud = $HUD
	popup = $Popup
	popup_body = $Popup/Content/BodyScroll/Body
	sparring = $Sparring
	make_controls()
	for node in settlement.find_children("*", "", true, false):
		if node is ConquestBuilding:
			buildings.append(node)
			node.action_requested.connect(func(action, anchor): open_panel(action, anchor))
			activity[node.action] = node.get_node("Activity")
		elif node is AnimatedSprite2D and node.animation == &"practice": trainees.append(node)
	sparring.restore_requested.connect(restore_town)
	sparring.drag_started.connect(func(): begin_taskbar_drag(DisplayServer.mouse_get_position()))
	if seed_from_full_window and not FileAccess.file_exists(save_path):
		summary = game.load_game(Rules.SAVE)
		persist()
	else: summary = game.load_game(save_path)
	register_gathering()
	persist()
	for building in game.completed: flash[building] = 5.0
	game.completed.clear()
	configure_window()
	show_toast(summary.get_slice("\n",0).replace("While you were away: ","Welcome back: "),9)
	refresh()
func make_controls() -> void:
	gold = $HUD/Gold
	frontier = $HUD/Frontier
	toast = $HUD/Toast
	gold.pressed.connect(func(): open_panel("ledger"))
	frontier.pressed.connect(func(): open_panel("frontier"))
	$HUD/Grip.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: drag_offset = Vector2i(event.global_position * scale_factor))
	$HUD/Dock.pressed.connect(dock)
	$HUD/Minimize.pressed.connect(minimize_to_sparring)
	$HUD/Quit.pressed.connect(func(): persist(); get_tree().quit())
	$Popup/Close.pressed.connect(close_panel)
	right_controls.assign([frontier, $HUD/Grip, $HUD/Dock, $HUD/Minimize, $HUD/Quit])

func register_gathering() -> void:
	var spot_definitions: Array = []
	var villager_definitions: Array = []
	for node in settlement.find_children("*", "", true, false):
		if node is ConquestResourceSpot:
			spot_definitions.append({"id": node.spot_id, "capacity": node.capacity, "settings": node.gathering})
			if not resource_spots.has(node.spot_id): resource_spots[node.spot_id] = node
			node.assignment_requested.connect(open_resource_panel)
		elif node is ConquestVillager:
			villager_definitions.append({"id": node.villager_id, "initial_spot": node.initial_spot_id})
			if not villager_views.has(node.villager_id): villager_views[node.villager_id] = node
	game.gathering_changed.connect(refresh_gathering)
	var errors := game.register_gathering(spot_definitions, villager_definitions)
	for node in settlement.find_children("*", "", true, false):
		if node is ConquestResourceSpot:
			node.get_node("Hit").disabled = not game.spots.has(node.spot_id) or resource_spots.get(node.spot_id) != node
	for error in errors: push_warning(error)
	if not errors.is_empty(): summary += "\nLevel settings: " + "; ".join(errors)
	refresh_gathering()

func refresh_gathering() -> void:
	for id in villager_views:
		villager_views[id].destination = resource_spots.get(game.s.assignments.get(id, ""))
	for id in resource_spots:
		resource_spots[id].get_node("Activity").text = "%d/%d" % [game.s.assignments.values().count(id), resource_spots[id].capacity]
	if selected_spot != null and popup.visible: rebuild_picker()

func open_resource_panel(spot: ConquestResourceSpot) -> void:
	selected_spot = spot
	open_panel("gathering", spot.get_node("PopupAnchor"))

func rebuild_picker() -> void:
	var rows := $Popup/Content/Picker/Rows
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if selected_spot == null: return
	var ids: Array = game.villagers.keys()
	ids.sort()
	for id in ids:
		var current: String = game.s.assignments.get(id, "")
		var current_name: String = resource_spots[current].display_name if resource_spots.has(current) else "Idle"
		var row: Button = ACTION_SCENE.instantiate()
		row.text = "%s · %s%s" % [villager_views[id].display_name, current_name, " · Unassign" if current == selected_spot.spot_id else " · Assign"]
		row.disabled = current != selected_spot.spot_id and game.s.assignments.values().count(selected_spot.spot_id) >= selected_spot.capacity
		var target: String = "" if current == selected_spot.spot_id else selected_spot.spot_id
		row.pressed.connect(func():
			if game.assign_villager(id, target): persist(); refresh()
			else: show_toast("Spot is full or unavailable"))
		rows.add_child(row)

func scroll_town(value: float) -> void:
	scroll_offset = clampf(value, 0.0, maxf(0.0, land_width - view_width))
	settlement.position.x = -scroll_offset

func layout_navigation() -> void:
	for i in right_controls.size(): right_controls[i].position.x = view_width - 182 + i * 35
	toast.position.x = maxf(0, view_width - 480)
	scroll_town(scroll_offset)
func update_training_drill() -> void:
	var training: bool = game.s.projects.has("barracks")
	var paused: bool = not game.s.battle.is_empty()
	for trainee in trainees:
		trainee.visible = training
		trainee.modulate.a = 0.55 if paused else 1.0
		if training and not paused: trainee.play("practice")
		else: trainee.pause()

func configure_window() -> void:
	var w := get_window()
	w.title = "The Growing Banner • Companion"
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
		view_width = floorf(DisplayServer.screen_get_usable_rect(w.current_screen).size.x / scale_factor)
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
func open_panel(kind: String, anchor: Node2D = null) -> void:
	popup_kind = kind
	if kind != "gathering": selected_spot = null
	if anchor == null:
		for building in buildings:
			if building.action == kind:
				anchor = building.get_node("PopupAnchor")
				break
	popup_anchor = settlement.to_local(anchor.global_position).x if anchor != null else scroll_offset + 240.0
	popup.position = Vector2(clampf(popup_anchor - scroll_offset - popup.size.x / 2, 8, maxf(8, view_width - popup.size.x - 8)), 12)
	popup.show()
	set_height(EXPANDED_HEIGHT)
	rebuild_panel()
func close_panel() -> void:
	popup.hide()
	popup_kind = ""
	selected_spot = null
	set_height(COMPACT_HEIGHT)
func rebuild_panel() -> void:
	for child in $Popup/Content/Actions.get_children():
		$Popup/Content/Actions.remove_child(child)
		child.queue_free()
	panel_buttons.clear()
	$Popup/Title.text = selected_spot.display_name if selected_spot != null else popup_kind.capitalize()
	$Popup/Content/Picker.visible = selected_spot != null
	if selected_spot != null: rebuild_picker()
	var busy: bool = not game.s.battle.is_empty()
	match popup_kind:
		"home": add_action("Develop  •  %d gold" % game.balance.development_cost,"develop")
		"barracks":
			var p: Dictionary = game.project("warriors")
			add_action("+%d warriors  •  %d gold  •  %s" % [game.balance.warrior_reward,p.cost,timer(p.duration)],"warriors")
		"academy":
			if not game.s.academy: add_action("Build  •  %d gold + %d plots" % [game.balance.academy_cost,game.balance.academy_plots],"build")
			elif game.s.mages == 0: add_action("First mage  •  %d gold  •  %s" % [game.balance.mage_cost,timer(game.balance.mage_duration)],"mage")
			else:
				if not game.s.healing: add_action("Learn Healing  •  %d gold  •  %s" % [game.balance.healing_cost,timer(game.balance.healing_duration)],"healing")
				add_action("Fireball","equip_fireball")
				if game.s.healing: add_action("Healing","equip_healing")
		"army":
			if game.s.mages>0:
				add_action("Fireball","equip_fireball")
				if game.s.healing: add_action("Healing","equip_healing")
		"frontier": add_action("Skip presentation" if busy else "Deploy","deploy")
		"ledger": pass
	update_panel()
func add_action(text: String, key: String) -> void:
	var b: Button = ACTION_SCENE.instantiate()
	b.text = text
	b.pressed.connect(func(): perform(key))
	$Popup/Content/Actions.add_child(b)
	b.set_meta("action",key)
	panel_buttons.append(b)
func perform(key: String) -> void:
	var ok := false
	match key:
		"develop": ok = game.develop()
		"build": ok = game.build_academy()
		"warriors","mage","healing": ok = game.start(key)
		"equip_fireball","equip_healing": ok = game.equip(key.trim_prefix("equip_"))
		"deploy":
			if not game.s.battle.is_empty(): game.finish_battle(); ok = true
			else: ok = game.deploy()
	if ok:
		persist()
		show_toast("Spell equipped" if key.begins_with("equip_") else ("Expedition underway" if key=="deploy" and not game.s.battle.is_empty() else "Saved"))
		if key=="deploy": close_panel()
		else: rebuild_panel()
	else: show_toast("Not ready • check gold or current project")
	refresh()
func update_panel() -> void:
	if not popup.visible: return
	var in_battle: bool = not game.s.battle.is_empty()
	var text := ""
	match popup_kind:
		"home": text = "+%.1f gold/min permanently\n%d gold • instant • no plot needed\nCurrent income: %.1f/min" % [game.balance.development_income,game.balance.development_cost,game.income()]
		"barracks": text = "%d warriors ready\nOne project at a time. Troops join automatically." % game.s.warriors
		"academy": text = "%d gold + %d conquered plots\nUnlocks your mage and spells.\nFree plots: %d" % [game.balance.academy_cost,game.balance.academy_plots,game.s.plots] if not game.s.academy else ("Train a mage to unlock Fireball." if game.s.mages==0 else "Equipped: %s\nFireball: damages the whole enemy group\nHealing: restores frontline health\nSpells cast automatically." % str(game.s.spell).capitalize())
		"army": text = "%d warriors • %d mage\nFrontline: %d HP\nSpell: %s\nLearned spells equip instantly, free." % [game.s.warriors,game.s.mages,game.s.warriors*game.balance.warrior_hp,str(game.s.spell).capitalize() if game.s.mages>0 else "none"]
		"frontier":
			if in_battle: text = "Expedition in progress\n%s\nTraining paused • income continues\nYour army and land are safe." % str(game.s.battle.get("land_name", "Expedition"))
			elif game.s.owned<game.balance.encounters.size():
				var land: ConquestEncounter = game.balance.encounters[int(game.s.owned)]
				text = "%s\nREWARD  +%d gold/min • %d plots\n%s\n%s" % [land.name,land.income,land.plots,land.hint,"Ready to march" if game.s.recovery<=0 else "Recovery: "+timer(game.s.recovery)]
			else: text = "Valley conquered\nAll lands are yours.\nDevelop your estate or grow your army."
		"ledger": text = "%d gold • +%.1f/min passive • %d free plots\n%d wood • %d food (stockpiled)\nGathering continues during battles.\n%s" % [game.s.gold,game.income(),game.s.plots,game.s.wood,game.s.food,summary]
		"gathering":
			if selected_spot != null and selected_spot.gathering != null:
				text = "%d %s every %.1f seconds per worker.\nSelect a villager. Free occupied spots first." % [selected_spot.gathering.yield_amount,selected_spot.gathering.resource_type,selected_spot.gathering.cycle_seconds]
	if game.s.projects.has(popup_kind):
		var p: Dictionary = game.s.projects[popup_kind]
		text = "%s\n%d gold paid • %d%% • %s left\n%s\n%s" % [game.project(p.key).name,p.cost,100*(1-float(p.remaining)/p.duration),timer(p.remaining),game.project(p.key).reward,"Paused while deployed" if in_battle else "Finishes automatically"]
	popup_body.text = text
	for b in panel_buttons:
		var key: String = b.get_meta("action")
		b.disabled = in_battle
		match key:
			"develop": b.disabled = in_battle or game.s.gold<game.balance.development_cost
			"build": b.disabled = in_battle or game.s.gold<game.balance.academy_cost or game.s.plots<game.balance.academy_plots
			"warriors","mage","healing":
				var p: Dictionary = game.project(key)
				b.disabled = in_battle or game.s.projects.has(p.building) or game.s.gold<p.cost
			"deploy":
				b.disabled = not in_battle and (game.s.recovery>0 or game.s.owned>=game.balance.encounters.size())
				b.text = "Skip presentation" if in_battle else ("Recovery • "+timer(game.s.recovery) if game.s.recovery>0 else "Deploy")
			"equip_fireball","equip_healing":
				b.text = ("[ " if game.s.spell==key.trim_prefix("equip_") else "") + key.trim_prefix("equip_").capitalize() + (" ]" if game.s.spell==key.trim_prefix("equip_") else "")
func timer(value: float) -> String:
	return "%d:%02d" % [int(ceil(value))/60,int(ceil(value))%60]
func show_toast(text: String, duration := 5.0) -> void:
	toast.text = text
	toast_until = clock+duration
	toast.show()
	update_mouse_region()
func persist() -> void:
	if not game.save_game(save_path): summary = "Save failed. Check disk space."; if is_instance_valid(toast): show_toast(summary,20)
func refresh() -> void:
	gold.text = "%d gold" % game.s.gold
	$HUD/Resources.text = "Wood %d   Food %d" % [game.s.wood,game.s.food]
	gold.tooltip_text = "+%d gold/min • click for return summary" % game.income()
	for building in buildings:
		var message := ""
		if game.s.projects.has(building.action): message = ("II " if not game.s.battle.is_empty() else ">> ") + timer(game.s.projects[building.action].remaining)
		elif flash.has(building.action): message = "+"
		if building.action == "frontier": message = (">> " + timer(game.s.battle.remaining)) if not game.s.battle.is_empty() else ("II " + timer(game.s.recovery) if game.s.recovery > 0 else "")
		building.refresh(game.s, message)
	var next := "%s/%s/%s/%s/%s" % [game.s.warriors,game.s.mages,game.s.academy,not game.s.battle.is_empty(),game.s.owned]
	if next!=stamp: stamp=next; rebuild_formation()
	update_training_drill()
	update_panel()
func spawn_unit(scene: PackedScene, at: Vector2, battling: bool) -> Sprite2D:
	var actor: Sprite2D = scene.instantiate()
	actor.position = at
	actor.set_battling(battling)
	formation.add_child(actor)
	animations.append(actor)
	return actor

func anchor_position(name: String) -> Vector2:
	return district.to_local(district.get_node("Anchors/" + name).global_position)

func rebuild_formation() -> void:
	for child in formation.get_children(): child.queue_free()
	var battling: bool = not game.s.battle.is_empty()
	# ponytail: presentation caps allies at 30; all troops participate in combat.
	for i in mini(int(game.s.warriors),30):
		var p := spawn_unit(warrior_scene, anchor_position("Allies") + Vector2(i % ally_columns, i / ally_columns) * ally_spacing, battling)
		p.set_meta("ally",i)
	if game.s.mages > 0:
		var caster := spawn_unit(mage_scene, anchor_position("Mage"), battling)
		caster.set_meta("caster", true)
	if battling:
		for i in int(game.s.battle.get("enemy_count", game.s.battle.timeline[0].alive)):
			var p := spawn_unit(enemy_scene, anchor_position("Enemies") + Vector2(i % enemy_columns, i / enemy_columns) * enemy_spacing, true)
			p.set_meta("enemy",i)
		fire = preload("res://conquest/units/combat_effect.tscn").instantiate()
		fire.position = anchor_position("Fire")
		formation.add_child(fire)
	else: fire = null

func show_combat_number(amount: float, at: Vector2, tint: Color, healing := false) -> void:
	if amount <= 0 or taskbar_mode: return
	var number: Label = preload("res://conquest/ui/combat_number.tscn").instantiate()
	number.text = ("+" if healing else "-") + str(roundi(amount))
	number.position = at
	number.add_theme_color_override("font_color", tint)
	number.set_meta("amount", amount)
	damage_numbers.add_child(number)
	var tween := number.create_tween().set_parallel(true)
	tween.tween_property(number, "position", at + Vector2(8, -25), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.25).set_delay(0.25)
	tween.chain().tween_callback(number.queue_free)

func emit_damage_packets(amount: int, at: Vector2, tint: Color, healing := false) -> void:
	var left := amount
	var packet := 0
	while left > 0:
		var hit := mini(2, left)
		show_combat_number(hit, at + Vector2((packet % 6) * 14 - 35, -(packet / 6) * 16), tint, healing)
		left -= hit
		packet += 1

func update_combat_presentation(battle: Dictionary, index: int, phase: float) -> void:
	var elapsed: float = (index + phase) * float(battle.get("duration", game.balance.presentation_duration)) / battle.timeline.size()
	var totals := Vector3.ZERO
	var previous_hp: float = battle.max_hp
	var previous_enemy: float = battle.enemy_max
	for entry in battle.timeline:
		totals.x += entry.get("enemy_damage", maxf(0, previous_enemy-entry.enemy_hp))
		totals.y += entry.get("ally_damage", maxf(0, previous_hp-entry.hp))
		totals.z += entry.get("healing", maxf(0, entry.hp-previous_hp))
		previous_hp = entry.hp
		previous_enemy = entry.enemy_hp
	# Four-frame swings always play at 10 FPS, independent of simulation tick count.
	var attack_beat := floori((elapsed - 0.2) / 0.4)
	var counter_beat := floori((elapsed - 0.3) / 0.4)
	var beats := float(battle.get("duration", game.balance.presentation_duration)) / 0.4
	if attack_beat > last_damage_step:
		var before := maxf(0, last_damage_step + 1) / beats
		var after := minf(1, (attack_beat + 1) / beats)
		emit_damage_packets(roundi(totals.x*after)-roundi(totals.x*before), anchor_position("EnemyDamage"), Color("ffdc70"))
		emit_damage_packets(roundi(totals.z*after)-roundi(totals.z*before), anchor_position("Healing"), Color("89f4aa"), true)
		last_damage_step = attack_beat
	if counter_beat > last_counter_step:
		var before := maxf(0, last_counter_step + 1) / beats
		var after := minf(1, (counter_beat + 1) / beats)
		emit_damage_packets(roundi(totals.y*after)-roundi(totals.y*before), anchor_position("AllyDamage"), Color("ff8a7c"))
		last_counter_step = counter_beat
	var step: Dictionary = battle.timeline[index]
	for actor in formation.get_children():
		if actor.has_meta("ally"):
			actor.frame = int(elapsed * 10) % actor.hframes
			actor.modulate.a = 1.0 if actor.get_meta("ally") < ceilf(float(step.hp)/game.balance.warrior_hp) else 0.15
		elif actor.has_meta("enemy"):
			actor.frame = int(maxf(0, elapsed-0.1) * 10) % actor.hframes
			actor.modulate.a = 1.0 if actor.get_meta("enemy") < step.alive else 0.15
		elif actor.has_meta("caster"):
			actor.frame = int(elapsed * 10) % actor.hframes
	if is_instance_valid(fire):
		var pulse := fposmod(elapsed - 0.2, 0.4)
		fire.visible = step.effect != "" and elapsed >= 0.2 and pulse < 0.22
		fire.frame = 0
		fire.set_battling(step.effect != "healing")
		fire.hframes = 11 if step.effect == "healing" else 8
		fire.frame = mini(fire.hframes-1, floori(pulse / 0.22 * fire.hframes))
		fire.position = anchor_position("Heal" if step.effect == "healing" else "Fire")

func _process(delta: float) -> void:
	if not popup.visible and not taskbar_mode:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0: scroll_town(scroll_offset + direction * 420.0 * delta)
	clock += delta
	save_clock += delta
	if dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): get_window().position = DisplayServer.mouse_get_position()-drag_offset
		else: dragging = false; clamp_to_work_area()
	var battling: bool = not game.s.battle.is_empty()
	game.advance(Time.get_unix_time_from_system())
	if battling and game.s.battle.is_empty():
		summary = game.s.result
		show_toast(summary.get_slice("\n",0)+" • click gold for report",8)
		persist()
	for building in game.completed:
		flash[building]=clock+4
		show_toast("%d warriors trained • joined your army" % game.balance.warrior_reward if building == "barracks" else "Project complete • army updated")
		if popup.visible: rebuild_panel()
	game.completed.clear()
	for key in flash.keys():
		if clock>flash[key]: flash.erase(key)
	if toast.visible and clock>toast_until: toast.hide(); update_mouse_region()
	for p in animations:
		if is_instance_valid(p):
			if not game.s.battle.is_empty() and (p.has_meta("ally") or p.has_meta("enemy") or p.has_meta("caster") or p == fire): continue
			p.frame=int(clock*8)%p.hframes
	if animations.size()>100: animations=animations.filter(func(p): return is_instance_valid(p))
	if not game.s.battle.is_empty():
		var b: Dictionary = game.s.battle
		var progress: float = (1-float(b.remaining)/float(b.get("duration", game.balance.presentation_duration)))*b.timeline.size()
		var step_index := mini(int(progress), b.timeline.size()-1)
		update_combat_presentation(b, step_index, progress-step_index)
	else:
		last_damage_step = -1
		last_counter_step = -1
	refresh()
	if save_clock>5: save_clock=0; persist()
	if get_window().position!=previous_position and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clamp_to_work_area()
		previous_position=get_window().position
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
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		game.advance(Time.get_unix_time_from_system())
		persist()
