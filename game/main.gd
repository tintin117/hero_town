extends Control

const FightRules := preload("res://game/fight.gd")
const ART := preload("res://resources/art/unit_library.tres")
const GOLD := Color("f2c771")
const MUTED := Color("a5b2c3")
const HIT_INTERVAL := 0.75
const INTERMISSION := 3.0

var fight := FightRules.new()
var selected: Array[int] = [0, 1, 2]
var auto_fight := false
var cards: Array[Button] = []
var card_records: Array[Label] = []
var fighters: Dictionary = {}
var coin_pulse: Tween


func _ready() -> void:
	_apply_theme()
	_build_roster()
	%Start.pressed.connect(_toggle_running)
	%Tick.timeout.connect(_tick)
	%Stage.draw.connect(_draw_ring)
	%Stage.resized.connect(_layout_fighters)
	_show_fighters(selected)
	_refresh()


func _panel(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _apply_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", MUTED)
	theme.set_color("font_color", "Button", Color("edf1f7"))
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _panel(Color("18222f"), Color("344355")))
	theme.set_stylebox("hover", "Button", _panel(Color("253344"), GOLD))
	theme.set_stylebox("pressed", "Button", _panel(Color("30352f"), GOLD, 2))
	theme.set_stylebox("disabled", "Button", _panel(Color("131b25"), Color("293444")))
	var focus := _panel(Color.TRANSPARENT, Color("ffffff"), 2)
	theme.set_stylebox("focus", "Button", focus)
	%Arena.add_theme_stylebox_override("panel", _panel(Color("121d29"), Color("344355")))
	%Start.add_theme_color_override("font_color", Color("171e29"))
	%Start.add_theme_stylebox_override("normal", _panel(GOLD, GOLD))
	%Start.add_theme_stylebox_override("hover", _panel(Color("ffda93"), GOLD))
	%Start.add_theme_stylebox_override("pressed", _panel(Color("d8ab55"), GOLD))


func _label(text: String, font_size: int, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_roster() -> void:
	for id in range(fight.heroes.size()):
		var hero := fight.heroes[id]
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.tooltip_text = "%s: %d stars, %d HP, %d ATK\nTargets: %s\n%s: %s\nMana: +25 on normal hits, +15 when surviving a normal hit.\nAt 100 mana: cast immediately, reset to 0, earn 10 coins.\nSkills generate no mana. Career victories add 5 coins per fight." % [hero.name, hero.stars, hero.health, hero.attack, FightRules.TARGET_LABELS[hero.target], hero.skill.name, hero.skill.description]
		card.pressed.connect(_select_hero.bind(id))
		%Roster.add_child(card)
		cards.append(card)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 8
		content.offset_bottom = -8
		content.add_theme_constant_override("separation", 1)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content)
		var portrait := TextureRect.new()
		var crop := AtlasTexture.new()
		crop.atlas = ART.frames(hero.unit, hero.red).get_frame_texture("idle", 0)
		crop.region = Rect2(crop.atlas.get_size() * 0.5 - Vector2(48, 48), Vector2(96, 96))
		portrait.texture = crop
		portrait.custom_minimum_size.y = 44
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		content.add_child(_label(hero.name, 21, Color("edf1f7")))
		content.add_child(_label("%d STAR  /  %s" % [hero.stars, hero.unit.to_upper()], 12, GOLD))
		content.add_child(_label("%d HP   /   %d ATK" % [hero.health, hero.attack], 14))
		content.add_child(_label(hero.skill.name, 14, Color("a7bfff")))
		var record := _label("", 15, Color("a5ddc4"))
		content.add_child(record)
		card_records.append(record)


func _select_hero(id: int) -> void:
	if auto_fight or fight.active:
		return
	if id in selected:
		selected.erase(id)
	elif selected.size() < 3:
		selected.append(id)
	_show_fighters(selected)
	%Status.text = "The arena is ready" if selected.size() == 3 else "Choose three heroes"
	%Commentary.text = "Book your trio below, then open the arena."
	_refresh()


func _refresh() -> void:
	var locked := auto_fight or fight.active
	for id in range(cards.size()):
		cards[id].set_pressed_no_signal(id in selected)
		cards[id].disabled = locked or (selected.size() == 3 and id not in selected)
		cards[id].add_theme_stylebox_override("disabled", _panel(Color("30352f"), GOLD, 2) if id in selected else _panel(Color("131b25"), Color("293444")))
		cards[id].modulate = Color.WHITE if id in selected else Color("9aa8ba")
		card_records[id].text = "%d wins  /  +%d coins" % [fight.heroes[id].wins, fight.heroes[id].wins * FightRules.COINS_PER_VICTORY]
	_refresh_money()
	%Record.text = "%d fights completed" % fight.completed
	%Selection.text = "YOUR FIGHT CARD  /  %d OF 3 BOOKED" % selected.size()
	%Hint.text = "Stop after this fight to change your trio." if locked else "Click a booked hero to make room for another."
	%Income.text = "Guaranteed: %d coins + skill tips" % fight.income_for(selected) if selected.size() == 3 else "Select 3 heroes to see income"
	%Formula.text = "100 base + 5 per victory  /  +10 instantly per skill  /  Session-only"
	%Start.disabled = selected.size() != 3 or (fight.active and not auto_fight)
	%Start.text = "Stop after this fight" if auto_fight else "Open arena"
	if fight.active and not auto_fight:
		%Start.text = "Finishing current fight..."


func _refresh_money() -> void:
	%Coins.text = "%d coins" % fight.coins
	%Tips.text = "CROWD TIPS  +%d" % fight.crowd_tips


func _toggle_running() -> void:
	if auto_fight:
		auto_fight = false
		if not fight.active:
			%Tick.stop()
			%Status.text = "Arena closed / change your trio"
	elif not fight.active and fight.valid_lineup(selected):
		auto_fight = true
		_begin_fight()
	_refresh()


func _begin_fight() -> void:
	if not fight.start(selected):
		return
	_show_fighters(fight.participants)
	%Status.text = "Fight %02d  /  %d guaranteed coins" % [fight.completed + 1, fight.payout]
	%Commentary.text = "Mana: +25 on a hit, +15 when hit. Full mana casts a skill and earns 10 coins."
	%Tick.start(HIT_INTERVAL)
	_refresh()


func _tick() -> void:
	if not fight.active:
		if auto_fight:
			_begin_fight()
		return
	var event := fight.step()
	_animate_action(event)
	var attacker: Dictionary = fight.heroes[event.attacker]
	if event.kind == "skill":
		%Commentary.text = "%s casts %s / +%d crowd tip%s" % [attacker.name, attacker.skill.name, event.tip, " / heals %d HP" % event.healing if event.healing > 0 else ""]
	else:
		var hit: Dictionary = event.hits[0]
		%Commentary.text = "%s hits %s for %d%s" % [attacker.name, fight.heroes[hit.target].name, hit.damage, " / knocked out!" if fight.health[hit.target] == 0 else ""]
	if event.winner >= 0:
		var winner: Dictionary = fight.heroes[event.winner]
		%Status.text = "%s wins!  /  +1 career victory" % winner.name
		%Commentary.text = "%d guaranteed + %d crowd tips = %d earned / Tips already paid" % [fight.payout, fight.crowd_tips, fight.payout + fight.crowd_tips]
		_refresh()
		if auto_fight:
			%Tick.start(INTERMISSION)
	else:
		%Tick.start(HIT_INTERVAL)


func _show_fighters(lineup: Array[int]) -> void:
	for node in %Stage.get_children():
		%Stage.remove_child(node)
		node.queue_free()
	fighters.clear()
	for id in lineup:
		var hero := fight.heroes[id]
		var body := Node2D.new()
		%Stage.add_child(body)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = ART.frames(hero.unit, hero.red)
		sprite.scale = Vector2.ONE * 0.9
		sprite.play("idle")
		sprite.animation_finished.connect(func():
			if fight.health.get(id, 1) > 0:
				sprite.play("idle")
		)
		body.add_child(sprite)
		var bars := {}
		for stat in ["health", "mana"]:
			var bar := ProgressBar.new()
			bar.position = Vector2(-68, 32 if stat == "health" else 45)
			bar.max_value = hero.health if stat == "health" else FightRules.MANA_MAX
			bar.value = hero.health if stat == "health" else 0
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
			bar.set_deferred("size", Vector2(136, 8))
			bars[stat] = bar
		var nameplate := _label(hero.name, 18, Color("edf1f7"))
		nameplate.position = Vector2(-85, 58)
		nameplate.size.x = 170
		body.add_child(nameplate)
		fighters[id] = {"body": body, "sprite": sprite, "bar": bars.health, "mana": bars.mana, "name": nameplate, "tint": null}
	_layout_fighters()


func _layout_fighters() -> void:
	var index := 0
	for id in fighters:
		fighters[id].body.position = Vector2(%Stage.size.x * (0.25 + index * 0.25), %Stage.size.y * 0.58)
		index += 1
	%Stage.queue_redraw()


func _draw_ring() -> void:
	var center: Vector2 = %Stage.size * Vector2(0.5, 0.46)
	var radius: Vector2 = %Stage.size * Vector2(0.43, 0.4)
	var points := PackedVector2Array()
	for i in range(65):
		var angle := TAU * i / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	%Stage.draw_colored_polygon(points, Color("1b2a36"))
	%Stage.draw_polyline(points, Color("596051"), 3.0, true)
	%Stage.draw_line(center - Vector2(0, radius.y), center + Vector2(0, radius.y), Color("2c3c45"), 2.0)
	for id in fighters:
		var pos: Vector2 = fighters[id].body.position + Vector2(0, 25)
		%Stage.draw_style_box(_panel(Color("111d26"), Color("111d26"), 0), Rect2(pos - Vector2(34, 5), Vector2(68, 10)))


func _animate_action(event: Dictionary) -> void:
	# Update money in the same frame that starts the cast animation, before any tween.
	_refresh_money()
	var source: Dictionary = fighters[event.attacker]
	var sprite: AnimatedSprite2D = source.sprite
	sprite.play("attack")
	if event.hits.size() == 1:
		var distance: Vector2 = fighters[event.hits[0].target].body.position - source.body.position
		sprite.flip_h = distance.x < 0
		var motion := sprite.create_tween()
		motion.tween_property(sprite, "position", distance * 0.65, 0.15).set_trans(Tween.TRANS_QUAD)
		motion.tween_property(sprite, "position", Vector2.ZERO, 0.25).set_delay(0.1)
	if event.kind == "skill":
		_show_tip(event.attacker)
		_tint_fighter(event.attacker, Color("a5ffd0") if event.healing > 0 else GOLD)
	for hit in event.hits:
		_tint_fighter(hit.target, Color("ffbc9e"))
	for id in fighters:
		fighters[id].bar.value = fight.health[id]
		fighters[id].mana.value = fight.mana[id]
		fighters[id].mana.tooltip_text = "%d / 100 mana" % fight.mana[id]
		if fight.health[id] == 0:
			fighters[id].name.text = "%s / OUT" % fight.heroes[id].name
			fighters[id].sprite.stop()
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


func _show_tip(id: int) -> void:
	var popup := Node2D.new()
	popup.name = "SkillTip"
	popup.position = Vector2(0, -70)
	popup.z_index = 5
	fighters[id].body.add_child(popup)
	var skill_name := _label(fight.heroes[id].skill.name, 17, GOLD)
	skill_name.position = Vector2(-120, -20)
	skill_name.size.x = 240
	var tip := _label("+%d" % FightRules.CAST_TIP, 32, GOLD)
	tip.position = Vector2(-120, 2)
	tip.size.x = 240
	for label in [skill_name, tip]:
		label.add_theme_color_override("font_outline_color", Color("11151e"))
		label.add_theme_constant_override("outline_size", 5)
		popup.add_child(label)
	var rise := popup.create_tween()
	rise.tween_property(popup, "position:y", popup.position.y - 34, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(popup, "modulate:a", 0.0, 0.3).set_delay(0.5)
	rise.tween_callback(popup.queue_free)
	if coin_pulse and coin_pulse.is_valid():
		coin_pulse.kill()
	%Coins.pivot_offset = %Coins.size * Vector2(1, 0.5)
	%Coins.scale = Vector2.ONE * 1.12
	%Coins.modulate = Color(1.5, 1.3, 1.0)
	coin_pulse = %Coins.create_tween().set_parallel(true)
	coin_pulse.tween_property(%Coins, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_pulse.tween_property(%Coins, "modulate", Color.WHITE, 0.4)
