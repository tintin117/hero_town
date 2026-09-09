extends Node2D
## A separate desktop presentation of the same conquest rules.
const Rules = preload("res://conquest/conquest_state.gd")
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
var bars: Array[ProgressBar] = []
var panel_buttons: Array[Button] = []
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper = style("Papers/RegularPaper.png",16)
	blue = style("Buttons/BigBlueButton_Regular.png",10)
	settlement = Node2D.new()
	add_child(settlement)
	formation = Node2D.new()
	settlement.add_child(formation)
	make_town()
	make_controls()
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
	for at in [Vector2(28,130),Vector2(200,133),Vector2(461,132),Vector2(923,128)]: sprite(settlement,"Terrain/Resources/Wood/Trees/Tree1.png",at,0.45,8)
	sprite(settlement,"Buildings/Blue Buildings/Castle.png",Vector2(120,109),0.44)
	sprite(settlement,"Buildings/Blue Buildings/Barracks.png",Vector2(284,124),0.5)
	sprite(settlement,"Buildings/Red Buildings/Tower.png",Vector2(874,126),0.45)
	sprite(settlement,"Buildings/Blue Buildings/House1.png",Vector2(52,168),0.23)
	sprite(settlement,"Units/Blue Units/Pawn/Pawn_Interact Axe.png",Vector2(37,159),0.55,6)
	sprite(settlement,"Units/Blue Units/Pawn/Pawn_Interact Pickaxe.png",Vector2(448,164),0.5,6)
	sprite(settlement,"Terrain/Decorations/Rocks/Rock2.png",Vector2(467,171),0.48)
	sprite(settlement,"Terrain/Resources/Meat/Sheep/Sheep_Idle.png",Vector2(199,179),0.5,6)
func make_controls() -> void:
	for entry in [["home",80,40,110,134],["barracks",230,70,110,105],["academy",350,56,108,124],["army",500,85,305,97],["frontier",828,63,90,121]]:
		var kind: String = entry[0]
		var hit := button(settlement,"",Vector2(entry[1],entry[2]),Vector2(entry[3],entry[4]),func(): open_panel(kind),kind.capitalize())
		for state in ["normal","hover","pressed"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	activity.barracks = label(settlement,"",Vector2(246,51),120)
	activity.academy = label(settlement,"",Vector2(364,37),125)
	activity.frontier = label(settlement,"",Vector2(832,38),120)
	gold = button(settlement,"",Vector2(16,184),Vector2(151,30),func(): open_panel("ledger"),"Gold • income • return summary")
	frontier = button(settlement,">",Vector2(778,184),Vector2(34,30),func(): open_panel("frontier"),"Frontier • preview reward and deploy")
	var grip := button(settlement,"::",Vector2(818,184),Vector2(30,30),func(): pass,"Drag settlement")
	grip.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: drag_offset = Vector2i(event.global_position*scale_factor))
	button(settlement,"v",Vector2(852,184),Vector2(30,30),dock,"Dock above taskbar")
	button(settlement,"-",Vector2(886,184),Vector2(30,30),func(): persist(); get_window().mode = Window.MODE_MINIMIZED,"Hide • restore from Windows taskbar")
	button(settlement,"x",Vector2(920,184),Vector2(30,30),func(): persist(); get_tree().quit(),"Save and close")
	toast = label(settlement,"",Vector2(480,12),456,15)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	popup = Panel.new()
	popup.size = Vector2(430,260)
	popup.add_theme_stylebox_override("panel",paper)
	add_child(popup)
	popup.hide()
	for i in 2:
		var bar := ProgressBar.new()
		bar.position = Vector2(516+i*126,189)
		bar.size = Vector2(112,9)
		bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("243f3f")
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("4db8d1") if i==0 else Color("d46453")
		bar.add_theme_stylebox_override("background",bg)
		bar.add_theme_stylebox_override("fill",fill)
		settlement.add_child(bar)
		bars.append(bar)
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
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
		scale_factor = minf(1.0,usable.size.x/960.0)
	set_height(COMPACT_HEIGHT)
	dock()
	Engine.max_fps = 30
func set_height(height: int) -> void:
	var w := get_window()
	var bottom := w.position.y+w.size.y
	w.content_scale_size = Vector2i(960,height)
	w.size = Vector2i(roundi(960*scale_factor),roundi(height*scale_factor))
	w.position.y = bottom-w.size.y
	settlement.position.y = height-COMPACT_HEIGHT
	clamp_to_work_area()
	update_mouse_region()
func dock() -> void:
	if DisplayServer.get_name()=="headless": return
	var w := get_window()
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.position = Vector2i(usable.position.x+(usable.size.x-w.size.x)/2,usable.end.y-w.size.y)
	previous_position = w.position
func clamp_to_work_area() -> void:
	if DisplayServer.get_name()=="headless" or get_window().mode==Window.MODE_MINIMIZED: return
	var w := get_window()
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.position = Vector2i(clampi(w.position.x,usable.position.x,maxi(usable.position.x,usable.end.x-w.size.x)),clampi(w.position.y,usable.position.y,maxi(usable.position.y,usable.end.y-w.size.y)))
func update_mouse_region() -> void:
	# Native interaction outline excludes empty desktop above the buildings.
	# Like the existing companion, this is a conservative outline, not per-pixel input.
	var outline := PackedVector2Array([Vector2(0,148),Vector2(8,94),Vector2(70,94),Vector2(70,32),Vector2(177,32),Vector2(177,92),Vector2(229,92),Vector2(229,45),Vector2(340,45),Vector2(340,31),Vector2(455,31),Vector2(480,80),Vector2(814,80),Vector2(814,31),Vector2(922,31),Vector2(954,100),Vector2(960,148),Vector2(960,220),Vector2(0,220)])
	for i in outline.size(): outline[i].y += settlement.position.y
	if popup.visible:
		var rect := popup.get_rect()
		var panel_shape := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		# Connect on-demand popup to the town with a narrow interaction bridge.
		var bridge := PackedVector2Array([Vector2(rect.position.x,rect.end.y-2),Vector2(rect.end.x,rect.end.y-2),Vector2(rect.end.x,settlement.position.y+160),Vector2(rect.position.x,settlement.position.y+160)])
		outline = Geometry2D.merge_polygons(outline,bridge)[0]
		outline = Geometry2D.merge_polygons(outline,panel_shape)[0]
	if toast.visible and clock<toast_until:
		var notification := PackedVector2Array([Vector2(478,settlement.position.y+8),Vector2(960,settlement.position.y+8),Vector2(960,settlement.position.y+160),Vector2(478,settlement.position.y+160)])
		outline = Geometry2D.merge_polygons(outline,notification)[0]
	for i in outline.size(): outline[i] *= scale_factor
	get_window().mouse_passthrough_polygon = outline
func open_panel(kind: String) -> void:
	popup_kind = kind
	popup_anchor = {"home":130,"barracks":285,"academy":400,"army":610,"frontier":760,"ledger":240}.get(kind,480)
	popup.position = Vector2(clampf(popup_anchor-215,8,522),12)
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
	if game.s.mages>0: sprite(formation,"Units/Blue Units/Monk/Heal.png" if battling else "Units/Blue Units/Monk/Idle.png",Vector2(499,157),0.57,1)
	if battling:
		for i in Rules.LANDS[int(game.s.battle.index)].count:
			var p := sprite(formation,"Units/Red Units/Warrior/Warrior_Attack1.png",Vector2(707+(i%4)*25,143+(i/4)*20),0.55,1)
			p.flip_h = true
			p.set_meta("enemy",i)
		fire = sprite(formation,"Particle FX/Explosion_01.png",Vector2(745,151),0.8,8)
	else: fire = null
	for bar in bars: bar.visible = battling
func _process(delta: float) -> void:
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
		show_toast("Project complete • army updated")
		if popup.visible: rebuild_panel()
	game.completed.clear()
	for key in flash.keys():
		if clock>flash[key]: flash.erase(key)
	if toast.visible and clock>toast_until: toast.hide(); update_mouse_region()
	for p in animations:
		if is_instance_valid(p): p.frame=int(clock*8)%p.hframes
	if animations.size()>100: animations=animations.filter(func(p): return is_instance_valid(p))
	if not game.s.battle.is_empty():
		var b: Dictionary = game.s.battle
		var step: Dictionary = b.timeline[mini(int((1-float(b.remaining)/Rules.PRESENTATION)*b.timeline.size()),b.timeline.size()-1)]
		bars[0].max_value=b.max_hp
		bars[0].value=step.hp
		bars[1].max_value=b.enemy_max
		bars[1].value=step.enemy_hp
		for p in formation.get_children():
			if p.has_meta("ally"): p.modulate.a=1.0 if p.get_meta("ally")<ceilf(float(step.hp)/40) else 0.15
			if p.has_meta("enemy"): p.modulate.a=1.0 if p.get_meta("enemy")<step.alive else 0.15
		if is_instance_valid(fire):
			fire.visible=step.effect!=""
			fire.texture=load(PACK+("Units/Blue Units/Monk/Heal_Effect.png" if step.effect=="healing" else "Particle FX/Explosion_01.png"))
			fire.hframes=11 if step.effect=="healing" else 8
			fire.position.x=578 if step.effect=="healing" else 746
	refresh()
	if save_clock>5: save_clock=0; persist()
	if get_window().position!=previous_position and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clamp_to_work_area()
		previous_position=get_window().position
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and popup.visible: close_panel()
func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseMotion:
		get_window().position = DisplayServer.mouse_get_position()-drag_offset
	if dragging and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		dragging=false
		clamp_to_work_area()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		game.advance(Time.get_unix_time_from_system())
		persist()
