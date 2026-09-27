extends Control

const FightRules := preload("res://game/fight.gd")
const CombatFeedback := preload("res://game/combat_feedback.gd")
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
var town_view_width := 0.0


func _ready() -> void:
	# Runtime-only window layout; leave the user's project/editor settings intact.
	if get_tree().current_scene == self:
		get_window().content_scale_size = Vector2i.ZERO
		get_window().min_size = Vector2i(960, 420)
		get_window().size = Vector2i(1280, 420)
	%World.move_child(%Stage, -1)
	%TownScroll.value_changed.connect(_scroll_world)
	%CenterArena.pressed.connect(_center_arena)
	%Arrange.toggled.connect(_set_arranging)
	resized.connect(_layout_town)
	_layout_town()
	_center_arena()
	_apply_theme()
	add_child(feedback)
	feedback.setup(self)
	_build_roster()
	%HeroesButton.pressed.connect(_toggle_drawer.bind(%HeroesDrawer))
	%ArenaButton.pressed.connect(_toggle_drawer.bind(%ArenaDrawer))
	for button in [%CloseHeroes, %CloseArena, %Dismiss]:
		button.pressed.connect(_close_drawers)
	%Start.pressed.connect(_toggle_running)
	%Expand.pressed.connect(_expand_arena)
	%Tick.timeout.connect(_intermission_finished)
	%Stage.draw.connect(_draw_ring)
	%Stage.resized.connect(_layout_fighters)
	%Excitement.draw.connect(_draw_excitement_markers)
	_show_fighters(selected)
	_refresh()


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


func _center_arena() -> void:
	%TownScroll.value = 1152.0 - size.x * 0.5


func _set_arranging(enabled: bool) -> void:
	if enabled:
		_close_drawers()
	%World.set_arranging(enabled)
	%ArrangeHint.visible = enabled
	%Arrange.set_pressed_no_signal(enabled)


func _world_input_allowed(point: Vector2) -> bool:
	if %Dismiss.visible or not Rect2(Vector2.ZERO, Vector2(size.x, size.y - 88.0)).has_point(point):
		return false
	for panel in [%Bank, %ExcitementMeter, %Earnings]:
		if panel.get_global_rect().has_point(point):
			return false
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if not event.pressed:
				panning = false
			elif _world_input_allowed(event.position):
				panning = true
				get_viewport().set_input_as_handled()
		elif event.pressed and event.shift_pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _world_input_allowed(event.position):
			%TownScroll.value += -96.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 96.0
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and panning:
		%TownScroll.value -= event.relative.x
		get_viewport().set_input_as_handled()


func _toggle_drawer(drawer: Control) -> void:
	var opening := not drawer.visible
	_close_drawers()
	drawer.visible = opening
	%Dismiss.visible = opening
	%HeroesButton.set_pressed_no_signal(%HeroesDrawer.visible)
	%ArenaButton.set_pressed_no_signal(%ArenaDrawer.visible)
	if opening:
		(%CloseHeroes if drawer == %HeroesDrawer else %CloseArena).grab_focus()


func _close_drawers() -> void:
	var button: Button = %HeroesButton if %HeroesDrawer.visible else %ArenaButton
	var was_open: bool = %HeroesDrawer.visible or %ArenaDrawer.visible
	%HeroesDrawer.hide()
	%ArenaDrawer.hide()
	%Dismiss.hide()
	%HeroesButton.set_pressed_no_signal(false)
	%ArenaButton.set_pressed_no_signal(false)
	if was_open:
		button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if %Dismiss.visible:
		_close_drawers()
	elif not %World.selected_building.is_empty():
		%World.cancel_placement()
	elif %World.arranging:
		_set_arranging(false)
	else:
		return
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
	for panel in [%Bank, %Earnings, %ExcitementMeter, %Footer, %HeroesDrawer, %ArenaDrawer]:
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
	if auto_fight or fight.active:
		return
	if id in selected:
		selected.erase(id)
	elif selected.size() < 3:
		selected.append(id)
	_show_fighters(selected)
	%Status.text = "The arena is ready" if selected.size() == 3 else "Choose three heroes"
	%Commentary.text = "Book three heroes, then open the arena."
	%Commentary.tooltip_text = %Commentary.text
	_refresh()


func _refresh() -> void:
	var locked := auto_fight or fight.active
	for id in range(cards.size()):
		cards[id].set_pressed_no_signal(id in selected)
		cards[id].disabled = locked or (selected.size() == 3 and id not in selected)
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
		details.skill.text = "%s / %d coins" % [hero.skill.name, FightRules.CAST_TIP]
		cards[id].tooltip_text = "%s / Level %d / %s\n%d HP, %d ATK / %d coins instantly per skill\nTargets the nearest opponent. %s\n%s: %s\nMana: +25 on normal hits, +15 when surviving a normal hit; cast at 100. Skills generate no mana.\n10 XP per completed fight, +10 bonus for winning. Each level: +5%% base HP/ATK and +5 base coins above level 1.\nEach career victory adds 5 base coins. Arena capacity multiplies base income. Each cast adds 8 excitement; final excitement boosts fight income, not tips. Progress is session-only." % [hero.name, hero.level, hero.unit.capitalize(), stats.health, stats.attack, FightRules.CAST_TIP, "Keeps 110-160 units of distance." if hero.ranged else "Chases into melee range (45 units).", hero.skill.name, hero.skill.description]
	_refresh_money()
	_refresh_excitement(fight.excitement)
	%Record.text = "%d fights completed / Progress lasts for this session" % fight.completed
	%Selection.text = "HEROES / %d OF 3 BOOKED" % selected.size()
	%HeroesButton.text = "Heroes  %d/3" % selected.size()
	%Hint.text = "Stop after this fight to change your trio." if locked else "Click a booked hero to make room for another."
	%Hint.tooltip_text = %Hint.text
	var quote := fight.income_breakdown(selected)
	%Income.text = "%d coins" % quote.guaranteed if not quote.is_empty() else "Choose 3 heroes"
	%Formula.text = "%d base\n+%d hero levels\n+%d career victories\nx%.1f arena capacity" % [quote.base, quote.levels, quote.victories, quote.multiplier] if not quote.is_empty() else "Book a full trio to see\nthe income breakdown."
	%Formula.tooltip_text = "Base income = round((100 + 5 x sum(level - 1) + 5 x total wins) x seats / 100).\nBase locked at fight start; later upgrades and level-ups affect the next booking.\nFinal fight income = round(base income x excitement multiplier). Tips are paid separately."
	%Start.disabled = selected.size() != 3 or (fight.active and not auto_fight)
	%Start.text = ("Stop after this fight" if fight.active else "Cancel next fight") if auto_fight else "Open arena"
	if fight.active and not auto_fight:
		%Start.text = "Finishing fight..."
	_refresh_recovery()


func _refresh_recovery() -> void:
	for id in range(card_details.size()):
		var remaining: float = fight.rest_remaining[id]
		card_details[id].rest.text = "Resting · %ds  " % ceili(remaining) if remaining > 0.0 else "Ready  "
		card_details[id].rest.add_theme_color_override("font_color", GOLD if remaining > 0.0 else Color("a5ddc4"))
	if auto_fight and not fight.active:
		var remaining := maxf(fight.lineup_rest(selected), %Tick.time_left)
		%Start.text = "Cancel / next in %ds" % ceili(remaining)
		%Start.tooltip_text = "Each participant rests for 8 seconds after a fight. The 3-second intermission overlaps recovery."


func _refresh_money() -> void:
	%Coins.text = "%d coins" % fight.coins
	%Tips.text = "%d tips paid" % fight.crowd_tips
	_refresh_venue()


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
	elif fight.completed > 0:
		%FightIncome.text = "%d paid / last fight" % fight.settled_income
	else:
		%FightIncome.text = "%d base / next fight" % fight.income_for(selected) if fight.valid_lineup(selected) else "Book three heroes"
	%FightIncome.tooltip_text = "Fight payout excludes tips already in your bank. Base income is locked at fight start; excitement multiplies it. Open Arena for the next booking's breakdown."
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
	%Expand.text = "Expand / %d coins" % cost if cost > 0 else "Fully expanded"
	%NextCapacity.text = "Next: %d seats / x%.1f" % [capacity + 50, float(capacity + 50) / FightRules.ARENA_CAPACITIES[0]] if cost > 0 else "Maximum capacity reached"
	%UpgradeHint.text = "Applies to your next booking" if cost > 0 else "200 seats / all upgrades owned"
	%Expand.tooltip_text = "Spend coins to expand seating. Your current fight keeps its quoted payout; the next booking earns more."


func _expand_arena() -> void:
	if fight.upgrade_arena():
		_refresh()
		%Stage.queue_redraw()


func _toggle_running() -> void:
	if auto_fight:
		auto_fight = false
		if not fight.active:
			%Tick.stop()
			%Status.text = "Arena closed / change your trio"
	elif not fight.active and fight.valid_lineup(selected):
		auto_fight = true
		_try_begin_fight()
	_refresh()


func _begin_fight() -> void:
	if not fight.start(selected):
		return
	_show_fighters(fight.participants)
	_close_drawers()
	cheer = 0.0
	if excitement_pulse and excitement_pulse.is_valid():
		excitement_pulse.kill()
	%ExcitementMeter.modulate = Color.WHITE
	displayed_tier = 0
	%Status.text = "Fight %02d  /  %d base coins" % [fight.completed + 1, fight.payout]
	%Commentary.text = "Nearest opponent / Melee heroes chase / Nia keeps her distance"
	%Commentary.tooltip_text = %Commentary.text
	%Status.tooltip_text = %Status.text
	%Tick.stop()
	_refresh()


func _try_begin_fight() -> void:
	if auto_fight and not fight.active and %Tick.is_stopped() and fight.lineup_rest(selected) <= 0.0:
		_begin_fight()


func _intermission_finished() -> void:
	%Tick.stop()
	_try_begin_fight()


func _physics_process(delta: float) -> void:
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
	crowd_clock += delta
	crowd_tick += delta
	cheer = maxf(0.0, cheer - delta * 0.5)
	if crowd_tick >= 1.0 / 12.0:
		%Stage.queue_redraw()
		crowd_tick = 0.0


func _present_action(event: Dictionary) -> void:
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
		%Commentary.text = "%d fight income + %d tips paid = %d earned" % [fight.settled_income, fight.crowd_tips, fight.settled_income + fight.crowd_tips]
		%Commentary.tooltip_text = "%d base x%.2f = %d fight income. Tips already paid: %d. Total: %d." % [fight.payout, multiplier, fight.settled_income, fight.crowd_tips, fight.settled_income + fight.crowd_tips]
		_refresh()
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
		var ground := Vector2.from_angle(-PI / 2.0 + TAU * index / 3.0) * FightRules.ARENA_RADIUS * 0.72
		if fight.active or (fight.completed > 0 and fight.participants == selected):
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
		var moving: bool = fight.velocities[id].length() > 1.0
		var direction: Vector2 = fight.velocities[id]
		if not moving and fight.targets[id] >= 0:
			direction = fight.positions[fight.targets[id]] - fight.positions[id]
		if absf(direction.x) > 0.1:
			fighter.sprite.flip_h = direction.x < 0.0
		if not (fighter.sprite.animation == "attack" and fighter.sprite.is_playing()) and (not fight.active or fight.pauses[id] <= 0.0):
			fighter.sprite.play("run" if moving and fight.active else "idle")


func _animate_action(event: Dictionary) -> void:
	# Update money in the same frame that starts the cast animation, before any tween.
	%Coins.text = "%d coins" % event.coins
	%Tips.text = "%d tips paid" % event.crowd_tips
	_refresh_venue()
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
