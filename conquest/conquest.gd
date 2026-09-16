extends Node2D
const Rules = preload("res://conquest/conquest_state.gd")
const PACK := "res://asset/Tiny Swords (Free Pack)/"
@export var save_path: String = Rules.SAVE
@export var balance: ConquestBalance = preload("res://conquest/default_balance.tres")
var game = Rules.new()
var ui: CanvasLayer
var world: Node2D
var army: Node2D
var hud: Label
var status: Label
var detail: Label
var deploy_button: Button
var popup: Panel
var popup_text: Label
var popup_kind := ""
var clock := 0.0
var save_clock := 0.0
var signature := ""
var notice := ""
var flash: Dictionary = {}
var animated: Array[Sprite2D] = []
var indicators: Dictionary = {}
var battle_label: Label
var friendly_bar: ProgressBar
var enemy_bar: ProgressBar
var paper: StyleBoxTexture
var blue: StyleBoxTexture
var effect: Sprite2D
func _ready() -> void:
	if game.balance != balance: game = Rules.new(balance)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	get_viewport().transparent_bg = false
	RenderingServer.set_default_clear_color(Color("244e62"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper = texture_style("UI Elements/UI Elements/Papers/RegularPaper.png", 16)
	blue = texture_style("UI Elements/UI Elements/Buttons/BigBlueButton_Regular.png", 12)
	ui = CanvasLayer.new()
	add_child(ui)
	world = Node2D.new()
	add_child(world)
	army = Node2D.new()
	add_child(army)
	make_world()
	make_ui()
	notice = game.load_game(save_path)
	# Offline completions are already described in the return summary. Highlight
	# their buildings without letting the first process frame replace that summary.
	for building in game.completed: flash[building] = 4.0
	game.completed.clear()
	refresh()
	if "--capture-conquest" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2).timeout
		get_viewport().get_texture().get_image().save_png("res://conquest/preview.png")
	if "--conquest-smoke" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		get_tree().quit()
func texture_style(path: String, edge: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	# Tiny Swords UI sheets have nine separated 64px patches on a 128px grid.
	var sheet: Texture2D = load(PACK + path)
	var joined := Image.create(192,192,false,Image.FORMAT_RGBA8)
	for x in 3:
		for y in 3: joined.blit_rect(sheet.get_image(),Rect2i(x*128,y*128,64,64),Vector2i(x*64,y*64))
	joined.resize(edge*3,edge*3,Image.INTERPOLATE_NEAREST)
	style.texture = ImageTexture.create_from_image(joined)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,edge)
	return style
func label_at(parent: Node, text: String, at: Vector2, width: float, size: int = 20, color: Color = Color("f8edcd")) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.size.x = width
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l
func button(parent: Node, text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = dimensions
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_stylebox_override("normal",blue)
	b.add_theme_stylebox_override("hover",blue)
	b.add_theme_stylebox_override("pressed",texture_style("UI Elements/UI Elements/Buttons/BigBlueButton_Pressed.png",12))
	b.pressed.connect(action)
	if text.begins_with("+2 warriors"): b.set_meta("project","warriors")
	elif text.begins_with("Train first mage"): b.set_meta("project","mage")
	elif text.begins_with("Learn healing"): b.set_meta("project","healing")
	elif text.begins_with("Build academy"): b.set_meta("build",true)
	parent.add_child(b)
	return b
func sprite(parent: Node, path: String, at: Vector2, factor: float = 1, frames: int = 1) -> Sprite2D:
	var p := Sprite2D.new()
	p.texture = load(PACK + path)
	p.hframes = frames
	if path.begins_with("Units/"): p.hframes = p.texture.get_width() / 192
	p.position = at
	p.scale = Vector2.ONE * factor
	parent.add_child(p)
	if frames > 1: animated.append(p)
	return p
func make_world() -> void:
	var map := TileMapLayer.new()
	map.position = Vector2(16,122)
	map.scale = Vector2(0.75,0.75)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64,64)
	var source := TileSetAtlasSource.new()
	source.texture = load(PACK + "Terrain/Tileset/Tilemap_color1.png")
	source.texture_region_size = Vector2i(64,64)
	for x in 3:
		for y in 3: source.create_tile(Vector2i(x,y))
	tiles.add_source(source,0)
	map.tile_set = tiles
	for x in 17:
		for y in 10:
			map.set_cell(Vector2i(x,y),0,Vector2i(0 if x == 0 else (2 if x == 16 else 1),0 if y == 0 else (2 if y == 9 else 1)))
	world.add_child(map)
	for p in [Vector2(60,185),Vector2(110,165),Vector2(790,175),Vector2(750,150),Vector2(65,535),Vector2(790,530)]:
		sprite(world,"Terrain/Resources/Wood/Trees/Tree1.png",p,0.7,8)
	for p in [Vector2(130,555),Vector2(750,560),Vector2(560,215)]: sprite(world,"Terrain/Decorations/Rocks/Rock2.png",p,0.8)
	sprite(world,"Buildings/Blue Buildings/Castle.png",Vector2(190,260),0.68)
	sprite(world,"Buildings/Blue Buildings/Barracks.png",Vector2(420,270),0.85)
	sprite(world,"Buildings/Blue Buildings/House1.png",Vector2(120,425),0.55)
	sprite(world,"Buildings/Blue Buildings/House2.png",Vector2(740,420),0.55)
	sprite(world,"Terrain/Resources/Meat/Sheep/Sheep_Idle.png",Vector2(160,490),0.8,6)
	sprite(world,"Units/Blue Units/Pawn/Pawn_Interact Axe.png",Vector2(88,220),0.7,6)
	sprite(world,"Units/Blue Units/Pawn/Pawn_Interact Pickaxe.png",Vector2(565,240),0.7,6)
func make_ui() -> void:
	for entry in [["home",Vector2(95,195)],["barracks",Vector2(330,210)],["academy",Vector2(590,195)]]:
		var hit := button(ui,"",entry[1],Vector2(190,135),func(): open_building(entry[0]))
		for state in ["normal","hover","pressed"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	label_at(ui,"THE GROWING BANNER",Vector2(28,14),650,32)
	label_at(ui,"Prepare at home. March together. Keep what you conquer.",Vector2(30,55),790,18)
	hud = label_at(ui,"",Vector2(30,86),800,21)
	button(ui,"Home • Develop",Vector2(102,335),Vector2(184,44),func(): open_building("home"))
	button(ui,"Barracks",Vector2(340,335),Vector2(165,44),func(): open_building("barracks"))
	button(ui,"Academy / Plot",Vector2(595,335),Vector2(190,44),func(): open_building("academy"))
	indicators.barracks = label_at(ui,"",Vector2(348,165),180,18)
	indicators.academy = label_at(ui,"",Vector2(596,165),210,18)
	var panel := Panel.new()
	panel.position = Vector2(850,16)
	panel.size = Vector2(410,594)
	panel.add_theme_stylebox_override("panel",paper)
	ui.add_child(panel)
	label_at(panel,"THE FRONTIER",Vector2(28,24),350,26,Color("493f32"))
	detail = label_at(panel,"",Vector2(28,70),354,19,Color("493f32"))
	deploy_button = button(panel,"Launch expedition",Vector2(28,510),Vector2(354,54),deploy)
	status = label_at(ui,"",Vector2(30,617),1210,18)
	battle_label = label_at(ui,"",Vector2(230,390),570,20,Color("183b38"))
	friendly_bar = ProgressBar.new()
	friendly_bar.position = Vector2(270,518)
	friendly_bar.size = Vector2(215,18)
	friendly_bar.show_percentage = false
	ui.add_child(friendly_bar)
	enemy_bar = ProgressBar.new()
	enemy_bar.position = Vector2(515,518)
	enemy_bar.size = Vector2(215,18)
	enemy_bar.show_percentage = false
	ui.add_child(enemy_bar)
	for bar in [friendly_bar,enemy_bar]:
		var background := StyleBoxFlat.new()
		background.bg_color = Color("203c40")
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("4bbeda") if bar == friendly_bar else Color("d56659")
		bar.add_theme_stylebox_override("background",background)
		bar.add_theme_stylebox_override("fill",fill)
	popup = Panel.new()
	popup.position = Vector2(320,120)
	popup.size = Vector2(640,480)
	popup.add_theme_stylebox_override("panel",paper)
	ui.add_child(popup)
	popup.hide()
func open_building(kind: String) -> void:
	popup_kind = kind
	for child in popup.get_children(): child.queue_free()
	popup.show()
	popup_text = label_at(popup,"",Vector2(32,28),576,18,Color("493f32"))
	button(popup,"Close",Vector2(464,410),Vector2(140,46),func(): popup.hide())
	if not game.s.battle.is_empty(): return
	match kind:
		"home": button(popup,"Develop • %d gold" % game.balance.development_cost,Vector2(32,240),Vector2(350,50),func(): act(game.develop()); open_building(kind))
		"barracks":
			var p: Dictionary = game.project("warriors")
			var b := button(popup,"+2 warriors • %d gold / %s" % [p.cost,timer(p.duration)],Vector2(32,240),Vector2(530,50),func(): act(game.start("warriors")); open_building(kind))
			b.disabled = game.s.projects.has(kind) or game.s.gold < p.cost
		"academy":
			if not game.s.academy:
				var b := button(popup,"Build academy • %d gold + 1 plot" % game.balance.academy_cost,Vector2(32,240),Vector2(540,50),func(): act(game.build_academy()); open_building(kind))
				b.disabled = int(game.s.plots) < 1 or game.s.gold < game.balance.academy_cost
			else:
				var key := "mage" if int(game.s.mages) == 0 else "healing"
				if not game.s.healing:
					var p: Dictionary = game.project(key)
					var b := button(popup,"%s • %d gold / %s" % [p.name,p.cost,timer(p.duration)],Vector2(32,270),Vector2(570,50),func(): act(game.start(key)); open_building(kind))
					b.disabled = game.s.projects.has(kind) or game.s.gold < p.cost
				if int(game.s.mages) > 0:
					button(popup,"Equip Fireball",Vector2(32,335),Vector2(250,48),func(): act(game.equip("fireball")))
					if game.s.healing: button(popup,"Equip Healing",Vector2(304,335),Vector2(250,48),func(): act(game.equip("healing")))
	update_popup()
func update_popup() -> void:
	if not popup.visible or not is_instance_valid(popup_text): return
	var text := ""
	match popup_kind:
		"home": text = "HOME\nDevelop your estate: +%.0f gold/min permanently.\nCost: %d gold. Instant. No plot required.\nCurrent income: %.0f gold/min. Free plots: %d." % [game.balance.development_income,game.balance.development_cost,game.income(),game.s.plots]
		"barracks": text = "BARRACKS\nChoose one project. Pay once; troops join automatically.\nCompleted warriors: %d" % game.s.warriors
		"academy": text = "ACADEMY\n" + ("Build on a conquered plot to train your first mage.\nCost: %d gold and 1 plot. Instant.\nFree plots: %d" % [game.balance.academy_cost,game.s.plots] if not game.s.academy else "One mage, two learnable spells. Equipping is instant.\nEquipped: %s" % str(game.s.spell).capitalize())
	if game.s.projects.has(popup_kind):
		var p: Dictionary = game.s.projects[popup_kind]
		text += "\n\n%s • %d gold paid\n%s / %s left • %d%% complete\nReward: %s" % [game.project(p.key).name,p.cost,timer(p.remaining),timer(p.duration),int(100*(1-float(p.remaining)/float(p.duration))),game.project(p.key).reward]
	if not game.s.battle.is_empty(): text += "\n\nDEPLOYED — projects paused; progress preserved."
	popup_text.text = text
	for c in popup.get_children():
		if c is Button and c.has_meta("project"):
			var p: Dictionary = game.project(c.get_meta("project"))
			c.disabled = game.s.projects.has(p.building) or game.s.gold < p.cost or (c.get_meta("project") == "mage" and game.s.mages > 0) or (c.get_meta("project") == "healing" and game.s.healing)
		elif c is Button and c.has_meta("build"): c.disabled = game.s.academy or game.s.plots < 1 or game.s.gold < game.balance.academy_cost
func timer(seconds: float) -> String:
	return "%d:%02d" % [int(ceil(seconds))/60,int(ceil(seconds))%60]
func act(ok: bool) -> void:
	notice = "Saved. Your preparation is underway." if ok else "Unavailable: check gold, plots, or the current project."
	persist()
	refresh()
func persist() -> void:
	if not game.save_game(save_path): notice = "Could not save progress. Please check available disk space."
func deploy() -> void:
	if not game.s.battle.is_empty():
		game.finish_battle()
		notice = game.s.result
	elif game.deploy(): notice = "Expedition underway. Training paused; gold keeps flowing."
	popup.hide()
	persist()
	refresh()
func refresh() -> void:
	hud.text = "%d GOLD   •   +%.0f / min   •   %d warriors + %d mage   •   %d free plots" % [int(game.s.gold),game.income(),game.s.warriors,game.s.mages,game.s.plots]
	var text := ""
	for i in game.lands.size():
		var land: ConquestLand = game.lands[i]
		text += "%s  %s\n+%d gold/min   •   %d %s\n" % ["OWNED" if i < int(game.s.owned) else "%02d" % (i+1),land.name,land.income,land.plots,"plot" if land.plots == 1 else "plots"]
		if i == int(game.s.owned): text += land.hint + "\n"
		text += "\n"
	if int(game.s.owned) >= game.lands.size(): text += "The valley is yours. Develop the estate and grow your army at your own pace."
	else: text += "Next reward is permanent.\nNo troops or land lost on defeat."
	detail.text = text
	var in_battle: bool = not game.s.battle.is_empty()
	deploy_button.disabled = not in_battle and (game.s.recovery > 0 or int(game.s.owned) >= game.lands.size())
	deploy_button.text = "Skip to saved result" if in_battle else ("Recovering • " + timer(game.s.recovery) if game.s.recovery > 0 else ("Valley conquered" if int(game.s.owned) >= game.lands.size() else "Launch expedition"))
	status.text = notice
	for building in indicators:
		indicators[building].text = ""
		if game.s.projects.has(building): indicators[building].text = ("PAUSED • " if in_battle else "WORKING • ") + timer(game.s.projects[building].remaining)
		elif flash.has(building): indicators[building].text = "COMPLETE!"
	friendly_bar.visible = in_battle
	enemy_bar.visible = in_battle
	var sig := "%s/%s/%s/%s/%s" % [game.s.warriors,game.s.mages,game.s.academy,in_battle,game.s.owned]
	if sig != signature:
		signature = sig
		rebuild_army()
	update_popup()
func rebuild_army() -> void:
	for c in army.get_children(): c.queue_free()
	var fighting: bool = not game.s.battle.is_empty()
	for i in mini(int(game.s.owned), game.lands.size()):
		sprite(army,"Buildings/Blue Buildings/House1.png",Vector2(280+i*160,550),0.3)
		label_at(army,"%s +%d/min" % [game.lands[i].name,game.lands[i].income],Vector2(205+i*175,578),180,13,Color("244d40"))
	if game.s.academy: sprite(army,"Buildings/Blue Buildings/Monastery.png",Vector2(680,265),0.8)
	else:
		label_at(army,"+ OPEN PLOT" if int(game.s.plots)>0 else "LOCKED PLOT",Vector2(610,250),190,20,Color("365547"))
	# ponytail: show up to forty troops; the full army always participates in simulation.
	var columns := 5 if game.s.warriors <= 10 else 10
	var spacing := 46 if columns == 5 else 24
	for i in mini(int(game.s.warriors),40):
		var unit := sprite(army,"Units/Blue Units/Warrior/Warrior_Attack1.png" if fighting else "Units/Blue Units/Warrior/Warrior_Idle.png",Vector2(290+(i%columns)*spacing,448+(i/columns)*24),0.77 if columns == 5 else 0.6,6)
		unit.set_meta("frontline",i)
	if int(game.s.mages)>0: sprite(army,"Units/Blue Units/Monk/Heal.png" if fighting else "Units/Blue Units/Monk/Idle.png",Vector2(240,480),0.85,6)
	if fighting:
		for i in int(game.s.battle.enemy_count):
			var p := sprite(army,"Units/Red Units/Warrior/Warrior_Attack1.png",Vector2(575+(i%4)*44,450+(i/4)*44),0.77,6)
			p.flip_h = true
			p.set_meta("enemy",i)
		effect = sprite(army,"Particle FX/Explosion_01.png",Vector2(655,470),1.2,8)
	else:
		effect = null
		battle_label.text = "Your banner grows with every project."
func _process(delta: float) -> void:
	clock += delta
	save_clock += delta
	var was_in_battle: bool = not game.s.battle.is_empty()
	game.advance(Time.get_unix_time_from_system())
	if was_in_battle and game.s.battle.is_empty(): notice = game.s.result
	for building in game.completed:
		flash[building] = clock + 4
		notice = "Project complete! Your army has grown. No collection needed."
	game.completed.clear()
	for building in flash.keys():
		if clock > flash[building]: flash.erase(building)
	for p in animated:
		if is_instance_valid(p): p.frame = int(clock * 8) % p.hframes
	if animated.size() > 150: animated = animated.filter(func(p): return is_instance_valid(p))
	if not game.s.battle.is_empty():
		var b: Dictionary = game.s.battle
		var fraction := 1.0 - float(b.remaining)/float(b.duration)
		var step: Dictionary = b.timeline[mini(int(fraction*b.timeline.size()),b.timeline.size()-1)]
		friendly_bar.max_value = b.max_hp
		friendly_bar.value = step.hp
		enemy_bar.max_value = b.enemy_max
		enemy_bar.value = step.enemy_hp
		for unit in army.get_children():
			if unit.has_meta("enemy"): unit.modulate.a = 1.0 if int(unit.get_meta("enemy")) < int(step.alive) else 0.18
			elif unit.has_meta("frontline"): unit.modulate.a = 1.0 if int(unit.get_meta("frontline")) < int(ceil(float(step.hp)/float(b.warrior_hp))) else 0.18
		battle_label.text = "%d enemies  •  %s" % [step.alive, str(step.effect).to_upper() if step.effect != "" else "FRONTLINE ENGAGED"]
		if is_instance_valid(effect):
			effect.visible = step.effect != ""
			if step.effect == "healing":
				effect.texture = load(PACK + "Units/Blue Units/Monk/Heal_Effect.png")
				effect.hframes = 11
				effect.position = Vector2(375,475)
			else:
				effect.texture = load(PACK + "Particle FX/Explosion_01.png")
				effect.hframes = 8
				effect.position = Vector2(645,475)
	refresh()
	if save_clock > 5:
		save_clock = 0
		persist()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		game.advance(Time.get_unix_time_from_system())
		persist()
