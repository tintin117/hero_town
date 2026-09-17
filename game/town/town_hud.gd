extends Control

const INK := Color("f7edcf")
const MUTED := Color("bdc7b3")
const GOLD := Color("f3cf7b")
@export var town: Node2D
@export_group("Responsive Layout")
## Disable to arrange the native controls directly with anchors and offsets.
@export var responsive_layout := true
@export var toolbar_width := 1100.0
@export var compact_toolbar_width := 820.0
@export var toolbar_bottom_offset := 50.0
@export var hint_bottom_offset := 80.0
@export var toolbar_height := 44.0
@export var hint_height := 28.0
@export var screen_margin := 8.0
@export var panel_maximum_size := Vector2(940, 680)
@export var panel_margin := 12.0
@export var responsive_typography := true
@export var wide_breakpoint := 1000.0
@export var text_sizes := Vector2i(17, 14)
@export var gold_text_sizes := Vector2i(20, 17)
@export var phase_text_sizes := Vector2i(16, 14)
@export var gold_minimum_widths := Vector2(135, 100)
@export var phase_minimum_widths := Vector2(260, 160)
@export var button_separation := Vector2i(8, 4)

@onready var top: PanelContainer = $Toolbar
@onready var bottom: PanelContainer = $HintStrip
@onready var gold_label: Label = $Toolbar/Buttons/Gold
@onready var phase_label: Label = $Toolbar/Buttons/Phase
@onready var hint_label: Label = $HintStrip/Row/Hint
@onready var start_button: Button = $Toolbar/Buttons/Start
@onready var mode_button: Button = $Toolbar/Buttons/Mode
@onready var expand_button: Button = $Toolbar/Buttons/Arrange
@onready var boss_bar: ProgressBar = $BossHUD/Health
@onready var boss_name: Label = $BossHUD/Name
@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Overlay/Panel
@onready var content: VBoxContainer = $Overlay/Panel/Layout/Content
@onready var panel_title: Label = $Overlay/Panel/Layout/Header/Title
var active_panel: String = ""
var selected_army: String = ""
var selected_node: String = "damage_1"
var toast_remaining: float = 0.0
var toast_text: String = ""
var last_report: Dictionary = {}
var _tree_scroll_positions: Dictionary = {}
var _displayed_army: String = ""

func _ready() -> void:
	# Standalone scene preview can run without a town controller.
	if town == null:
		set_process(false)
		return
	$Toolbar/Buttons/Build.pressed.connect(open_build)
	$Toolbar/Buttons/Buildings.pressed.connect(func(): open_research(selected_army))
	start_button.pressed.connect(func(): town.director.start_now())
	mode_button.pressed.connect(func(): GameState.set_advancing(not GameState.advancing))
	expand_button.pressed.connect(_toggle_arrange)
	$Toolbar/Buttons/Options.pressed.connect(open_options)
	$Overlay/Panel/Layout/Header/Close.pressed.connect(close_panel)
	for button in [$Toolbar/Buttons/Build, $Toolbar/Buttons/Buildings, start_button, mode_button, expand_button, $Toolbar/Buttons/Options, $Overlay/Panel/Layout/Header/Close]:
		button.pressed.connect(func(): sfx.play("click"))
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close_panel())
	GameState.currency_changed.connect(func(_gold, _shard): refresh_panel())
	GameState.buildings_changed.connect(refresh_panel)
	GameState.research_changed.connect(func(_id): refresh_panel())
	GameState.progression_changed.connect(refresh_panel)
	GameState.save_failed.connect(func(message): toast(message + " Progress is currently unsaved."))
	town.director.phase_changed.connect(refresh_panel)
	town.director.battle_finished.connect(_on_result)
	get_viewport().size_changed.connect(_layout)
	GameState.settings_changed.connect(_layout)
	_layout()

func _label(text: String, size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _paragraph(text: String, color: Color = MUTED) -> Label:
	var label := _label(text, 17, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(func():
		sfx.play("click")
		callback.call())
	return button

func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _layout() -> void:
	if not responsive_layout or town == null: return
	var size_now := get_viewport_rect().size
	start_button.visible = false
	mode_button.visible = not GameState.settings.compact
	var strip_width := minf(compact_toolbar_width if GameState.settings.compact else toolbar_width, size_now.x - screen_margin * 2)
	top.position = Vector2((size_now.x - strip_width) * 0.5, size_now.y - toolbar_bottom_offset)
	top.size = Vector2(strip_width, toolbar_height)
	bottom.position = Vector2((size_now.x - strip_width) * 0.5, size_now.y - hint_bottom_offset)
	bottom.size = Vector2(strip_width, hint_height)
	panel.size = panel_maximum_size.min(size_now - Vector2.ONE * panel_margin * 2)
	panel.position = (size_now - panel.size) * 0.5
	if responsive_typography:
		var index := 0 if size_now.x >= wide_breakpoint else 1
		phase_label.custom_minimum_size.x = phase_minimum_widths[index]
		gold_label.custom_minimum_size.x = gold_minimum_widths[index]
		phase_label.add_theme_font_size_override("font_size", phase_text_sizes[index])
		(top.get_child(0) as HBoxContainer).add_theme_constant_override("separation", button_separation[index])
		theme.default_font_size = text_sizes[index]
		gold_label.add_theme_font_size_override("font_size", gold_text_sizes[index])
	# Theme/minimum-size changes settle after this resize notification.
	top.set_deferred("size", Vector2(strip_width, toolbar_height))
	town.desktop.update_mouse_region.call_deferred()

func _process(delta: float) -> void:
	toast_remaining = maxf(0, toast_remaining - delta)
	gold_label.text = "%sg · S%d" % [_number(GameState.gold), town.director.stage_number]
	var director: BattleDirector = town.director
	var stage: StageData = GameData.STAGES[director.stage_number]
	phase_label.text = GameState.objective_text()
	phase_label.tooltip_text = phase_label.text
	start_button.disabled = director.phase != "PREPARE" or GameState.buildings.is_empty()
	mode_button.text = "Farm" if GameState.advancing else "Challenge"
	mode_button.disabled = GameState.cleared_stage >= 20
	expand_button.text = "Resume" if GameState.reorganizing else "Arrange"
	expand_button.tooltip_text = "Hold after this battle to reorganize and refund safely"
	hint_label.text = toast_text if toast_remaining > 0 else _hint()
	var hint_was_visible := bottom.visible
	bottom.visible = not GameState.settings.compact or toast_remaining > 0 or GameState.tutorial < 1 or GameState.reorganizing or not GameState.save_error.is_empty()
	if bottom.visible != hint_was_visible: town.desktop.update_mouse_region.call_deferred()
	start_button.visible = false
	mode_button.visible = not GameState.settings.compact
	$BossHUD.visible = director.phase == "BATTLE" and not stage.boss.is_empty() and not GameState.settings.compact
	if $BossHUD.visible and director.simulation != null:
		for unit in director.simulation.units:
			if not unit.get("boss", "").is_empty():
				boss_name.text = stage.title
				boss_bar.value = 100.0 * maxf(0, unit.hp) / unit.max_hp
				break

func _hint() -> String:
	if GameState.reorganizing: return "Regrouping after this battle…" if town.director.phase == "BATTLE" else "Reorganizing · refunds available · Resume when ready"
	if not GameState.save_error.is_empty(): return "Unsaved progress: " + GameState.save_error
	if not town.placement_type.is_empty() or not town.move_id.is_empty(): return "Choose a free town tile · Right-click / Escape cancels"
	match GameState.tutorial:
		0: return "Welcome to Hero Town. Build your first Barracks to recruit three Warriors."
		1: return "Your recruits fight automatically. Click their building to improve the army."
		2: return "Victory! Open Research and choose a Crew, Rarity, or Training node."
	if GameState.cleared_stage >= 20: return "The frontier is safe! Demo complete · Your armies continue farming gold."
	if GameState.buildings.size() == 1 and GameState.cleared_stage >= 2: return "Rangers unlocked! Place a Range behind your Warriors to add ranged support."
	return "%d/%d armies · %s · Away earnings %s gold/hour (8h cap)" % [GameState.buildings.size(), TownRules.capacity(GameState.cleared_stage), "Advancing" if GameState.advancing else "Farming cleared battles", _number(roundi(GameState.offline_rate() * 3600))]

func _number(value: int) -> String:
	if value >= 1000000: return "%.1fm" % (value / 1000000.0)
	if value >= 10000: return "%.1fk" % (value / 1000.0)
	return str(value)

func toast(text: String) -> void:
	toast_text = text
	toast_remaining = 6.0

func _open(kind: String, title: String) -> void:
	active_panel = kind
	panel_title.text = title
	town.desktop.open_overlay()
	overlay.show()
	_clear_content()
	_layout()

func _clear_content() -> void:
	var previous := content.find_child("ResearchScroll", true, false) as ScrollContainer
	if previous != null: _tree_scroll_positions[_displayed_army] = previous.scroll_vertical
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func close_panel(restore: bool = true) -> void:
	active_panel = ""
	overlay.hide()
	if restore: town.desktop.close_overlay()

func refresh_panel() -> void:
	if active_panel == "build": open_build()
	elif active_panel == "research": open_research(selected_army)

func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return body

func open_build() -> void:
	_open("build", "Raise an army")
	content.add_child(_paragraph("Each building owns its own soldiers and research. Place frontline armies toward the right; protect Rangers and Clerics behind them."))
	var body := _scroll(content)
	for type: String in TownRules.ARMY_TYPES:
		var data: BuildingData = GameData.BUILDINGS[type]
		var card := PanelContainer.new()
		body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		card.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = data.thumbnail
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(86, 90)
		row.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(_label(data.display_name, 21, GOLD))
		details.add_child(_paragraph("%d soldiers · %s" % [data.starting_crew, data.specialty]))
		var locked: bool = GameState.cleared_stage < data.unlock_stage
		details.add_child(_label("Unlock: clear stage %d" % data.unlock_stage if locked else "An independent army · Maximum crew 6", 15, MUTED))
		var button := _button("%d gold · Place" % data.build_cost, func(): town.begin_placement(type))
		button.disabled = locked or GameState.gold < data.build_cost or GameState.buildings.size() >= TownRules.capacity(GameState.cleared_stage)
		row.add_child(button)
	content.add_child(_label("Army slots: %d / %d. Captains at stages 5, 10, and 15 expand your town." % [GameState.buildings.size(), TownRules.capacity(GameState.cleared_stage)], 16, MUTED))

func open_research(instance_id: String = "") -> void:
	if GameState.buildings.is_empty():
		open_build()
		return
	selected_army = instance_id if not GameState.get_building(instance_id).is_empty() else str(GameState.buildings[0].id)
	town.selected_id = selected_army
	for view: ArmyBuildingView in town.building_views.values():
		view.selected = view.record.id == selected_army
		view.queue_redraw()
	_open("research", "Building workshop")
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 36
	for record in GameState.buildings:
		var data: BuildingData = GameData.BUILDINGS[record.type]
		selector.add_item("%s #%s · %s · %d soldiers" % [data.display_name, record.id.trim_prefix("army_"), TownRules.RARITIES[TownRules.rarity(record)], TownRules.crew(record, data)])
		selector.set_item_metadata(selector.item_count - 1, record.id)
		if record.id == selected_army: selector.select(selector.item_count - 1)
	selector.item_selected.connect(func(index): open_research(selector.get_item_metadata(index)))
	content.add_child(selector)
	var record := GameState.get_building(selected_army)
	var building: BuildingData = GameData.BUILDINGS[record.type]
	var hero: HeroData = GameData.hero_for(record.type, TownRules.rarity(record))
	var stats := TownRules.stats(hero, record)
	content.add_child(_paragraph(_role_text(record.type)))
	content.add_child(_label("Per soldier: %d HP · %.0f damage · %.2fs attack interval" % [stats.hp, stats.damage, stats.interval], 17, MUTED))
	var tree_body := _scroll(content)
	if record.type == "barracks":
		var spec := OptionButton.new()
		for title in ["Balanced · standard Warrior", "Bulwark · stronger protection", "Vanguard · stronger damage"]: spec.add_item(title)
		spec.select(["balanced","bulwark","vanguard"].find(record.get("specialization","balanced")))
		spec.item_selected.connect(func(index):
			GameState.set_specialization(selected_army,["balanced","bulwark","vanguard"][index])
			toast("Specialization changed free · takes effect next battle."))
		tree_body.add_child(spec)
		tree_body.add_child(_paragraph("Bulwark: +30% HP, -10% damage, 40% nearby guard. Vanguard: +30% damage, -10% HP, 15% guard. Balanced guard: 25%. Free to switch; training improves guard further."))
	var research_scroll := tree_body.get_parent() as ScrollContainer
	research_scroll.name = "ResearchScroll"
	research_scroll.set_deferred("scroll_vertical", _tree_scroll_positions.get(selected_army, 0))
	_displayed_army = selected_army
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	tree_body.add_child(columns)
	for branch in ["crew", "rarity", "training"]:
		var group := PanelContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(group)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		group.add_child(column)
		column.add_child(_label(branch.capitalize(), 22, GOLD))
		for node: ResearchNodeData in GameData.research_for(building):
			if (branch == "training" and node.branch in TownRules.TRAINING) or node.branch == branch:
				var owned: bool = record.research.has(node.id)
				var button := _button(("✓ " if owned else "") + node.title + ("" if owned else " · %dg" % node.cost), func():
					selected_node = node.id
					open_research(selected_army))
				button.add_theme_font_size_override("font_size", 15)
				button.tooltip_text = node.description + "\n" + GameState.research_error(selected_army, node.id)
				if owned: button.modulate = Color("9cddad")
				elif not GameState.research_error(selected_army, node.id).is_empty(): button.modulate = Color("b7b6ac")
				if selected_node == node.id: button.add_theme_color_override("font_color", GOLD)
				column.add_child(button)
				if branch != "training": column.add_child(_label("↓", 15, MUTED))
	if not GameData.RESEARCH.has(selected_node): selected_node = "damage_1"
	var node: ResearchNodeData = GameData.RESEARCH[selected_node]
	var detail := PanelContainer.new()
	content.add_child(detail)
	var details := VBoxContainer.new()
	detail.add_child(details)
	details.add_child(_label(node.title + " · " + str(node.cost) + " gold", 20, GOLD))
	details.add_child(_paragraph(node.description + " " + _node_effect(record, building, node)))
	var affordability := ProgressBar.new()
	affordability.max_value = maxi(1,node.cost)
	affordability.value = mini(GameState.gold,node.cost)
	affordability.custom_minimum_size.y = 8
	affordability.show_percentage = false
	details.add_child(affordability)
	var reason: String = GameState.research_error(selected_army, selected_node)
	details.add_child(_label(reason if not reason.is_empty() else "%d/%d gold · Ready. Applies next battle." % [mini(GameState.gold,node.cost),node.cost], 15, MUTED))
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var buy := _button("Improve · %d gold" % node.cost, func():
		var response: Dictionary = GameState.purchase_research(selected_army, selected_node)
		toast("Research complete." if response.ok else response.message)
		if response.ok: sfx.play("upgrade"))
	buy.disabled = not reason.is_empty()
	actions.add_child(buy)
	actions.add_child(_button("Move building", func(): town.begin_move(selected_army)))
	var refund := 0
	for cost in record.research.values(): refund += int(cost)
	var reset := _button("Refund %d gold" % refund, func():
		var response: Dictionary = GameState.refund_research(selected_army)
		toast("Research refunded. Away earning rate resumes after your next victory." if response.ok else response.message))
	reset.disabled = town.director.phase != "PREPARE" or not GameState.reorganizing or refund == 0
	reset.tooltip_text = "Choose Arrange, then wait for this battle to finish. Returns recorded spending; preserves the building."
	actions.add_child(reset)
	actions.add_child(_button("Pin goal", func(): GameState.pin_upgrade(selected_army,selected_node)))

func _node_effect(record: Dictionary, data: BuildingData, node: ResearchNodeData) -> String:
	if node.branch == "crew": return "Crew %d → %d." % [TownRules.crew(record, data), mini(6, data.starting_crew + node.rank)]
	if node.branch == "rarity": return "%s → %s." % [TownRules.RARITIES[TownRules.rarity(record)], TownRules.RARITIES[node.rank]]
	var value: float = 0.15 if node.branch == "haste" else (0.25 if node.branch == "specialty" else 0.2)
	return "Bonus +%d%% → +%d%%." % [TownRules.training_rank(record, node.branch) * value * 100, node.rank * value * 100]

func open_options() -> void:
	_open("options", "Companion settings")
	var body := _scroll(content)
	body.add_child(_button("Return to companion" if not GameState.settings.compact else "Open full window", func():
		close_panel()
		town.cancel_placement()
		town.desktop.toggle()))
	body.add_child(_button("Battle report", open_report))
	body.add_child(_button("Challenge next stage", func(): GameState.set_advancing(true)))
	body.add_child(_label("Landscape", 20, GOLD))
	var landscapes := OptionButton.new()
	for title in ["Waterside village", "Terraced castle town", "Scattered hamlet"]: landscapes.add_item(title)
	landscapes.select(int(GameState.settings.landscape))
	landscapes.item_selected.connect(func(index): GameState.update_setting("landscape", index))
	body.add_child(landscapes)
	body.add_child(_label("Master volume", 20, GOLD))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.01
	volume.value = GameState.settings.volume
	volume.custom_minimum_size.y = 35
	volume.value_changed.connect(func(value): GameState.update_setting("volume", value))
	body.add_child(volume)
	for entry in [["always_on_top", "Keep the game above other windows"], ["reduced_effects", "Reduce ambient animation and effects"]]:
		var button := CheckButton.new()
		button.text = entry[1]
		button.button_pressed = GameState.settings[entry[0]]
		button.toggled.connect(func(value): GameState.update_setting(entry[0], value))
		body.add_child(button)
	body.add_child(_label("Companion height", 20, GOLD))
	var height := HSlider.new()
	height.min_value = 220
	height.max_value = 400
	height.step = 10
	height.value = town.desktop.compact_size.y
	height.value_changed.connect(func(value): town.desktop.resize_compact(int(value)))
	body.add_child(height)
	body.add_child(_paragraph("Compact mode keeps combat automatic while you work. Management expands this same window. Camera shake and hit-stop are disabled in the companion."))
	body.add_child(_label("Choose a cleared stage to farm", 20, GOLD))
	var stages := OptionButton.new()
	for number in range(1, GameState.cleared_stage + 1):
		if number % 5 != 0:
			stages.add_item("Stage %d · %d gold per victory" % [number, GameData.STAGES[number].gold], number)
			if number == GameState.farm_stage: stages.select(stages.item_count - 1)
	stages.disabled = stages.item_count == 0
	stages.item_selected.connect(func(index): GameState.select_farm(stages.get_item_id(index)))
	body.add_child(stages)
	body.add_child(_paragraph("Away earnings use half your measured ordinary-battle rate, including the short recovery transition, for up to eight hours. Bosses and new stages need the game running."))
	body.add_child(_button("Save and quit", func():
		GameState.request_quit()))

func _on_result(report: Dictionary) -> void:
	last_report = report
	var stage: StageData = GameData.STAGES[report.stage]
	if report.won:
		var unlock := ""
		if report.first_clear:
			unlock = {2: " · Rangers unlocked!", 4: " · Clerics unlocked!", 7: " · Lancers unlocked!", 5: " · East Commons opened — fourth army plot!", 10: " · Six army slots!", 15: " · Eight army slots!", 20: " · Demo complete!"}.get(report.stage, "")
		toast("%s cleared · +%d gold%s" % [stage.title, report.gold, unlock])
		sfx.play("coin")
		if not GameState.settings.reduced_effects:
			fx.popup("+%d" % report.gold, gold_label.global_position + Vector2(15, 42), {"parent": self, "font_size": 18, "color": GOLD})
	else:
		toast("Army recovering · Farming stage %d. Improve an army to challenge again." % GameState.farm_stage)

func open_report() -> void:
	_open("report", "Battle report")
	if last_report.is_empty():
		content.add_child(_paragraph("Your first battle report will appear here. Damage, healing, and casualties are tracked separately for each army."))
		return
	content.add_child(_label("%s · Stage %d · %.1fs · +%d gold" % ["Victory" if last_report.won else "Defeat", last_report.stage, last_report.duration, last_report.gold], 22, GOLD))
	var body := _scroll(content)
	for instance_id in last_report.reports:
		var record := GameState.get_building(instance_id)
		var report: Dictionary = last_report.reports[instance_id]
		body.add_child(_label("%s #%s" % [GameData.BUILDINGS[record.type].display_name, instance_id.trim_prefix("army_")], 20))
		body.add_child(_label("Damage %d    Healing %d    Downed %d" % [report.damage, report.healing, report.casualties], 17, MUTED))
	if GameState.cleared_stage >= 20:
		body.add_child(_paragraph("The Warlord has fallen. You completed the Hero Town demo! Your armies will keep farming while you refine their research and formations.", GOLD))

func show_offline(summary: Dictionary) -> void:
	_open("offline", "Welcome back")
	content.add_child(_label("Your armies earned %s gold" % _number(int(summary.gold)), 30, GOLD))
	content.add_child(_paragraph("%d minutes away, capped at eight hours. This gold is already saved and ready to spend. New stages and bosses await your return." % (summary.seconds / 60)))
	content.add_child(_button("Return to town", close_panel))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_ESCAPE and overlay.visible:
		close_panel()
		get_viewport().set_input_as_handled()

func _toggle_arrange() -> void:
	GameState.set_reorganizing(not GameState.reorganizing)
	toast("Regroup after this battle; then move buildings or refund research." if GameState.reorganizing else "Army resumed · battles start automatically.")

func _role_text(type: String) -> String:
	var role: String = {"barracks":"Warriors · frontline protection and close combat", "mage_tower":"Rangers · rear-line ranged damage and three-target volley", "cleric_hall":"Clerics · keep injured allies fighting with healing", "rogue_den":"Lancers · reach through clustered enemies with piercing attacks"}.get(type,"Army")
	return role + ". Building position sets deployment; changes and recruits join next battle."
