extends Node2D
## A separate desktop presentation of the same conquest rules.
const Rules = preload("res://conquest/conquest_state.gd")
const Presentation = preload("res://scripts/presentation_scale.gd")
const PACK := "res://asset/Tiny Swords (Free Pack)/"
const COMPACT_HEIGHT := 220
const EXPANDED_HEIGHT := 500
@export var save_path := "user://conquest_companion_v1.json"
@export var seed_from_full_window := true
var game = Rules.new()
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
var paper: StyleBoxTexture
var blue: StyleBoxTexture
var fire: Sprite2D
var damage_numbers: Node2D
var last_damage_step := -1
var last_counter_step := -1


var panel_buttons: Array[Button] = []
var trainees: Array[AnimatedSprite2D] = []
var hud: Node2D
var view_width := 960.0
var land_width := 2880.0
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
const DISTRICT_OFFSET := 480.0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper = style("Papers/RegularPaper.png",16)
	blue = style("Buttons/BigBlueButton_Regular.png",10)
	settlement = Node2D.new()
	add_child(settlement)
	district = Node2D.new()
	district.name = "TownDistrict"
	district.position.x = DISTRICT_OFFSET
	settlement.add_child(district)
	formation = Node2D.new()
	district.add_child(formation)
	damage_numbers = Node2D.new()
	damage_numbers.name = "DamageNumbers"
	damage_numbers.z_index = 20
	district.add_child(damage_numbers)
	make_town()
	hud = Node2D.new()
	add_child(hud)
	make_controls()
	make_training_drill()
	sparring = preload("res://conquest/taskbar_sparring.gd").new()
	sparring.hide()
	add_child(sparring)
	sparring.restore_requested.connect(restore_town)
	sparring.drag_started.connect(func(): begin_taskbar_drag(DisplayServer.mouse_get_position()))
	if seed_from_full_window and not FileAccess.file_exists(save_path):
		summary = game.load_game(Rules.SAVE)
		persist()
	else: summary = game.load_game(save_path)
	for building in game.completed: flash[building] = 5.0
	game.completed.clear()
	configure_window()
	show_toast(summary.get_slice("\n",0).replace("While you were away: ","Welcome back: "),9)
	refresh()
func style(path: String, margin: int) -> StyleBoxTexture:
	var sheet: Texture2D = load(PACK + "UI Elements/UI Elements/" + path)
	var joined := Image.create(192,192,false,Image.FORMAT_RGBA8)
	for x in 3:
		for y in 3: joined.blit_rect(sheet.get_image(),Rect2i(x*128,y*128,64,64),Vector2i(x*64,y*64))
	joined.resize(margin*3,margin*3,Image.INTERPOLATE_NEAREST)
	var result := StyleBoxTexture.new()
	result.texture = ImageTexture.create_from_image(joined)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: result.set_texture_margin(side,margin)
	return result
func label(parent: Node, text: String, at: Vector2, width: float, font_size := 16, dark := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.size.x = width
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",Color("423e34") if dark else Color("fff2cc"))
	if not dark:
		l.add_theme_color_override("font_shadow_color",Color("243f3f"))
		l.add_theme_constant_override("shadow_offset_x",1)
		l.add_theme_constant_override("shadow_offset_y",1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
func button(parent: Node, text: String, at: Vector2, dimensions: Vector2, action: Callable, tooltip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = dimensions
	b.tooltip_text = tooltip
	b.add_theme_stylebox_override("normal",blue)
	b.add_theme_stylebox_override("hover",blue)
	b.add_theme_stylebox_override("pressed",blue)
	b.add_theme_font_size_override("font_size",16)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
func sprite(parent: Node, path: String, at: Vector2, factor: float, frames := 1) -> Sprite2D:
	var p := Sprite2D.new()
	p.texture = load(PACK+path)
	p.position = at
	p.scale = Vector2.ONE*factor
	p.hframes = p.texture.get_width()/192 if path.begins_with("Units/") else frames
	parent.add_child(p)
	if p.hframes>1: animations.append(p)
	return p
func make_town() -> void:
	# Authored TileMap layers stay paintable in the editor and move with popups.
	$Terrain.reparent(settlement)
	for terrace in ["CastleTerrace", "VillageTerrace", "FrontierTerrace"]:
		settlement.get_node("Terrain/" + terrace).position.x += DISTRICT_OFFSET
	workers = preload("res://conquest/town_workers.gd").new()
	workers.name = "WorkingHamlet"
	settlement.add_child(workers)
	# Extend the paintable terrain into a continuous district for future buildings.
	for layer_name in ["Ground", "Cliff"]:
		var layer: TileMapLayer = settlement.get_node("Terrain/" + layer_name)
		var cells: Array[Vector2i] = []
		for x in ceili(land_width / 24.0):
			for y in (2 if layer_name == "Ground" else 1): cells.append(Vector2i(x, y))
		layer.set_cells_terrain_connect(cells, 0, 0 if layer_name == "Ground" else 1, false)
	for x in [1540, 1820, 2200, 2670]:
		sprite(settlement,"Terrain/Resources/Wood/Trees/Tree1.png",Vector2(x,132),0.45,8)
		sprite(settlement,"Terrain/Decorations/Rocks/Rock2.png",Vector2(x+64,171),0.48)
	for at in [Vector2(28,130),Vector2(200,133),Vector2(461,132),Vector2(923,128)]: sprite(district,"Terrain/Resources/Wood/Trees/Tree1.png",at,0.45,8)
	sprite(district,"Buildings/Blue Buildings/Castle.png",Vector2(120,109),0.44)
	sprite(district,"Buildings/Blue Buildings/Barracks.png",Vector2(284,124),0.5)
	sprite(district,"Buildings/Red Buildings/Tower.png",Vector2(874,126),0.45)
	sprite(district,"Buildings/Blue Buildings/House1.png",Vector2(52,168),0.23)
	sprite(district,"Units/Blue Units/Pawn/Pawn_Interact Axe.png",Vector2(37,159),0.55,6)
	sprite(district,"Units/Blue Units/Pawn/Pawn_Interact Pickaxe.png",Vector2(448,164),0.5,6)
	sprite(district,"Terrain/Decorations/Rocks/Rock2.png",Vector2(467,171),0.48)
	sprite(district,"Terrain/Resources/Meat/Sheep/Sheep_Idle.png",Vector2(199,179),0.5,6)
func make_controls() -> void:
	for entry in [["home",80,40,110,134],["barracks",230,70,110,105],["academy",350,56,108,124],["army",500,85,305,97],["frontier",828,63,90,121]]:
		var kind: String = entry[0]
		var hit := button(district,"",Vector2(entry[1],entry[2]),Vector2(entry[3],entry[4]),func(): open_panel(kind),kind.capitalize())
		for state in ["normal","hover","pressed"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	activity.barracks = label(district,"",Vector2(246,51),120)
	activity.academy = label(district,"",Vector2(364,37),125)
	activity.frontier = label(district,"",Vector2(832,38),120)
	gold = button(settlement,"",Vector2(16,184),Vector2(151,30),func(): open_panel("ledger"),"Gold • income • return summary")
	frontier = button(settlement,">",Vector2(778,184),Vector2(34,30),func(): open_panel("frontier"),"Frontier • preview reward and deploy")
	var grip := button(settlement,"::",Vector2(818,184),Vector2(30,30),func(): pass,"Drag settlement")
	grip.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: drag_offset = Vector2i(event.global_position*scale_factor))
	button(settlement,"v",Vector2(852,184),Vector2(30,30),dock,"Dock above taskbar")
	button(settlement,"-",Vector2(886,184),Vector2(30,30),minimize_to_sparring,"Minimize town • watch taskbar sparring")
	button(settlement,"x",Vector2(920,184),Vector2(30,30),func(): persist(); get_tree().quit(),"Save and close")
	toast = label(settlement,"",Vector2(480,12),456,15)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	popup = Panel.new()
	popup.size = Vector2(430,260)
	popup.add_theme_stylebox_override("panel",paper)
	add_child(popup)
	popup.hide()
	# Keep navigation and window controls reachable while the town scrolls.
	for control in [gold, frontier, toast]: control.reparent(hud)
	for control in settlement.get_children():
		if control is Button and control.text in ["::", "v", "-", "x"]:
			control.reparent(hud)
			right_controls.append(control)
	right_controls.push_front(frontier)

func scroll_town(value: float) -> void:
	scroll_offset = clampf(value, 0.0, maxf(0.0, land_width - view_width))
	settlement.position.x = -scroll_offset

func layout_navigation() -> void:
	for i in right_controls.size(): right_controls[i].position.x = view_width - 182 + i * 35
	toast.position.x = maxf(0, view_width - 480)
	scroll_town(scroll_offset)
func make_training_drill() -> void:
	var clips := SpriteFrames.new()
	clips.add_animation("practice")
	clips.set_animation_speed("practice", 8.0)
	for clip in ["Attack1", "Guard", "Attack2", "Idle"]:
		var sheet: Texture2D = load(PACK + "Units/Blue Units/Warrior/Warrior_" + clip + ".png")
		for frame_index in int(sheet.get_width() / 192):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(frame_index * 192, 0, 192, 192)
			clips.add_frame("practice", frame)
	for i in 2:
		var trainee := AnimatedSprite2D.new()
		trainee.sprite_frames = clips
		trainee.position = Vector2(224 + i * 44, 166)
		trainee.scale = Vector2.ONE * 0.45
		trainee.flip_h = i == 1
		trainee.animation = "practice"
		trainee.frame = i * 8
		district.add_child(trainee)
		trainees.append(trainee)
	update_training_drill()

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
	land_width = maxf(2880, view_width + 960)
	for layer_name in ["Ground", "Cliff"]:
		var layer: TileMapLayer = settlement.get_node("Terrain/" + layer_name)
		var cells: Array[Vector2i] = []
		for x in range(120, ceili(land_width / 24.0)):
			for y in (2 if layer_name == "Ground" else 1): cells.append(Vector2i(x, y))
		if not cells.is_empty(): layer.set_cells_terrain_connect(cells, 0, 0 if layer_name == "Ground" else 1, false)
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
func open_panel(kind: String) -> void:
	popup_kind = kind
	popup_anchor = {"home":130,"barracks":285,"academy":400,"army":610,"frontier":760,"ledger":240}.get(kind,480)
	if kind != "ledger": popup_anchor += DISTRICT_OFFSET
	popup.position = Vector2(clampf(popup_anchor-scroll_offset-215,8,view_width-438),12)
	popup.show()
	set_height(EXPANDED_HEIGHT)
	rebuild_panel()
func close_panel() -> void:
	popup.hide()
	popup_kind = ""
	set_height(COMPACT_HEIGHT)
func rebuild_panel() -> void:
	for child in popup.get_children(): child.queue_free()
	panel_buttons.clear()
	label(popup,popup_kind.capitalize(),Vector2(18,14),350,20,true)
	button(popup,"x",Vector2(380,10),Vector2(32,30),close_panel,"Close • Escape")
	popup_body = label(popup,"",Vector2(18,47),394,16,true)
	var busy: bool = not game.s.battle.is_empty()
	match popup_kind:
		"home": add_action("Develop  •  60 gold",Vector2(18,191),Vector2(394,42),"develop")
		"barracks":
			var p: Dictionary = game.project("warriors")
			add_action("+2 warriors  •  %d gold  •  %s" % [p.cost,timer(p.duration)],Vector2(18,191),Vector2(394,42),"warriors")
		"academy":
			if not game.s.academy: add_action("Build  •  60 gold + 1 plot",Vector2(18,191),Vector2(394,42),"build")
			elif game.s.mages == 0: add_action("First mage  •  30 gold  •  1:00",Vector2(18,191),Vector2(394,42),"mage")
			else:
				if not game.s.healing: add_action("Learn Healing  •  60 gold  •  5:00",Vector2(18,145),Vector2(394,38),"healing")
				add_action("Fireball",Vector2(18,199),Vector2(190,38),"equip_fireball")
				if game.s.healing: add_action("Healing",Vector2(220,199),Vector2(190,38),"equip_healing")
		"army":
			if game.s.mages>0:
				add_action("Fireball",Vector2(18,199),Vector2(190,38),"equip_fireball")
				if game.s.healing: add_action("Healing",Vector2(220,199),Vector2(190,38),"equip_healing")
		"frontier": add_action("Skip presentation" if busy else "Deploy",Vector2(18,199),Vector2(394,38),"deploy")
		"ledger": pass
	update_panel()
func add_action(text: String, at: Vector2, dimensions: Vector2, key: String) -> void:
	var b := button(popup,text,at,dimensions,func(): perform(key))
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
		"home": text = "+5 gold/min permanently\n60 gold • instant • no plot needed\nCurrent income: %d/min" % game.income()
		"barracks": text = "%d warriors ready\nOne project at a time. Troops join automatically." % game.s.warriors
		"academy": text = "60 gold + 1 conquered plot\nUnlocks your mage and spells.\nFree plots: %d" % game.s.plots if not game.s.academy else ("Train a mage to unlock Fireball." if game.s.mages==0 else "Equipped: %s\nFireball: damages the whole enemy group\nHealing: restores frontline health\nSpells cast automatically." % str(game.s.spell).capitalize())
		"army": text = "%d warriors • %d mage\nFrontline: %d HP\nSpell: %s\nLearned spells equip instantly, free." % [game.s.warriors,game.s.mages,game.s.warriors*40,str(game.s.spell).capitalize() if game.s.mages>0 else "none"]
		"frontier":
			if in_battle: text = "Expedition in progress\n%s\nTraining paused • income continues\nYour army and land are safe." % Rules.LANDS[int(game.s.battle.index)].name
			elif game.s.owned<3:
				var land: Dictionary = Rules.LANDS[int(game.s.owned)]
				text = "%s\nREWARD  +%d gold/min • %d plots\n%s\n%s" % [land.name,land.income,land.plots,land.hint,"Ready to march" if game.s.recovery<=0 else "Recovery: "+timer(game.s.recovery)]
			else: text = "Valley conquered\nAll three lands are yours.\nDevelop your estate or grow your army."
		"ledger": text = "%d gold • +%d/min • %d free plots\n%s" % [game.s.gold,game.income(),game.s.plots,summary]
	if game.s.projects.has(popup_kind):
		var p: Dictionary = game.s.projects[popup_kind]
		text = "%s\n%d gold paid • %d%% • %s left\n%s\n%s" % [game.project(p.key).name,p.cost,100*(1-float(p.remaining)/p.duration),timer(p.remaining),game.project(p.key).reward,"Paused while deployed" if in_battle else "Finishes automatically"]
	popup_body.text = text
	for b in panel_buttons:
		var key: String = b.get_meta("action")
		b.disabled = in_battle
		match key:
			"develop": b.disabled = in_battle or game.s.gold<60
			"build": b.disabled = in_battle or game.s.gold<60 or game.s.plots<1
			"warriors","mage","healing":
				var p: Dictionary = game.project(key)
				b.disabled = in_battle or game.s.projects.has(p.building) or game.s.gold<p.cost
			"deploy":
				b.disabled = not in_battle and (game.s.recovery>0 or game.s.owned>=3)
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
	gold.tooltip_text = "+%d gold/min • click for return summary" % game.income()
	for building in ["barracks","academy"]:
		activity[building].text = ""
		if game.s.projects.has(building): activity[building].text = ("II " if not game.s.battle.is_empty() else ">> ")+timer(game.s.projects[building].remaining)
		elif flash.has(building): activity[building].text = "+"
	activity.frontier.text = (">> "+timer(game.s.battle.remaining)) if not game.s.battle.is_empty() else ("II "+timer(game.s.recovery) if game.s.recovery>0 else "")
	var next := "%s/%s/%s/%s/%s" % [game.s.warriors,game.s.mages,game.s.academy,not game.s.battle.is_empty(),game.s.owned]
	if next!=stamp: stamp=next; rebuild_formation()
	update_training_drill()
	update_panel()
func rebuild_formation() -> void:
	for child in formation.get_children(): child.queue_free()
	var battling: bool = not game.s.battle.is_empty()
	if game.s.academy: sprite(formation,"Buildings/Blue Buildings/Monastery.png",Vector2(399,113),0.48)
	else:
		var plot := sprite(formation,"Buildings/Black Buildings/Monastery.png",Vector2(399,113),0.48)
		plot.modulate = Color(1,1,1,0.3)
	for i in mini(int(game.s.warriors),30):
		var p := sprite(formation,"Units/Blue Units/Warrior/Warrior_Attack1.png" if battling else "Units/Blue Units/Warrior/Warrior_Idle.png",Vector2(543+(i%5)*27,143+(i/5)*14),0.55,1)
		p.set_meta("ally",i)
	if game.s.mages>0:
		var caster := sprite(formation,"Units/Blue Units/Monk/Heal.png" if battling else "Units/Blue Units/Monk/Idle.png",Vector2(499,157),0.57,1)
		caster.set_meta("caster", true)
	if battling:
		for i in Rules.LANDS[int(game.s.battle.index)].count:
			var p := sprite(formation,"Units/Red Units/Warrior/Warrior_Attack1.png",Vector2(707+(i%4)*25,143+(i/4)*20),0.55,1)
			p.flip_h = true
			p.set_meta("enemy",i)
		fire = sprite(formation,"Particle FX/Explosion_01.png",Vector2(745,151),0.8,8)
	else: fire = null

func show_combat_number(amount: float, at: Vector2, tint: Color, healing := false) -> void:
	if amount <= 0 or taskbar_mode: return
	var number := Label.new()
	number.text = ("+" if healing else "-") + str(roundi(amount))
	number.position = at
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_font_size_override("font_size", 18)
	number.add_theme_color_override("font_color", tint)
	number.add_theme_color_override("font_outline_color", Color("18282e"))
	number.add_theme_constant_override("outline_size", 5)
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
	var elapsed: float = (index + phase) * Rules.PRESENTATION / battle.timeline.size()
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
	var beats := 35.0
	if attack_beat > last_damage_step:
		var before := maxf(0, last_damage_step + 1) / beats
		var after := minf(1, (attack_beat + 1) / beats)
		emit_damage_packets(roundi(totals.x*after)-roundi(totals.x*before), Vector2(731,105), Color("ffdc70"))
		emit_damage_packets(roundi(totals.z*after)-roundi(totals.z*before), Vector2(515,82), Color("89f4aa"), true)
		last_damage_step = attack_beat
	if counter_beat > last_counter_step:
		var before := maxf(0, last_counter_step + 1) / beats
		var after := minf(1, (counter_beat + 1) / beats)
		emit_damage_packets(roundi(totals.y*after)-roundi(totals.y*before), Vector2(555,103), Color("ff8a7c"))
		last_counter_step = counter_beat
	var step: Dictionary = battle.timeline[index]
	for actor in formation.get_children():
		if actor.has_meta("ally"):
			actor.frame = int(elapsed * 10) % actor.hframes
			actor.modulate.a = 1.0 if actor.get_meta("ally") < ceilf(float(step.hp)/40) else 0.15
		elif actor.has_meta("enemy"):
			actor.frame = int(maxf(0, elapsed-0.1) * 10) % actor.hframes
			actor.modulate.a = 1.0 if actor.get_meta("enemy") < step.alive else 0.15
		elif actor.has_meta("caster"):
			actor.frame = int(elapsed * 10) % actor.hframes
	if is_instance_valid(fire):
		var pulse := fposmod(elapsed - 0.2, 0.4)
		fire.visible = step.effect != "" and elapsed >= 0.2 and pulse < 0.22
		fire.frame = 0
		fire.texture = load(PACK + ("Units/Blue Units/Monk/Heal_Effect.png" if step.effect == "healing" else "Particle FX/Explosion_01.png"))
		fire.hframes = 11 if step.effect == "healing" else 8
		fire.frame = mini(fire.hframes-1, floori(pulse / 0.22 * fire.hframes))
		fire.position.x = 578 if step.effect == "healing" else 746

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
		show_toast("Two warriors trained • joined your army" if building == "barracks" else "Project complete • army updated")
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
		var progress: float = (1-float(b.remaining)/Rules.PRESENTATION)*b.timeline.size()
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
