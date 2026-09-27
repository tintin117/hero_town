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
		card.tooltip_text = "%s: %d stars, %d health, %d attack. Victories add 5 coins per fight." % [hero.name, hero.stars, hero.health, hero.attack]
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
		portrait.custom_minimum_size.y = 62
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)
		content.add_child(_label(hero.name, 21, Color("edf1f7")))
		content.add_child(_label("%d STAR  /  %s" % [hero.stars, hero.unit.to_upper()], 12, GOLD))
		content.add_child(_label("%d HP   /   %d ATK" % [hero.health, hero.attack], 14))
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
	%Coins.text = "%d coins" % fight.coins
	%Record.text = "%d fights completed" % fight.completed
	%Selection.text = "YOUR FIGHT CARD  /  %d OF 3 BOOKED" % selected.size()
	%Hint.text = "Stop after this fight to change your trio." if locked else "Click a booked hero to make room for another."
	%Income.text = "Next fight: %d coins" % fight.income_for(selected) if selected.size() == 3 else "Select 3 heroes to see income"
	%Formula.text = "100 base + 5 per career victory in your trio  /  Session-only prototype"
	%Start.disabled = selected.size() != 3 or (fight.active and not auto_fight)
	%Start.text = "Stop after this fight" if auto_fight else "Open arena"
	if fight.active and not auto_fight:
		%Start.text = "Finishing current fight..."


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
	%Status.text = "Fight %02d  /  %d coins on the card" % [fight.completed + 1, fight.payout]
	%Commentary.text = "Every hero for themselves. Last one standing earns a career victory."
	%Tick.start(HIT_INTERVAL)
	_refresh()


func _tick() -> void:
	if not fight.active:
		if auto_fight:
			_begin_fight()
		return
	var event := fight.step()
	_animate_hit(event)
	var attacker: Dictionary = fight.heroes[event.attacker]
	var target: Dictionary = fight.heroes[event.target]
	%Commentary.text = "%s hits %s for %d%s" % [attacker.name, target.name, event.damage, " / knocked out!" if fight.health[event.target] == 0 else ""]
	if event.winner >= 0:
		var winner: Dictionary = fight.heroes[event.winner]
		%Status.text = "%s wins!  /  +1 career victory" % winner.name
		%Commentary.text = "+%d coins earned  /  %s now has %d career victories" % [fight.payout, winner.name, winner.wins]
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
		sprite.play("idle")
		sprite.animation_finished.connect(func(): sprite.play("idle"))
		body.add_child(sprite)
		var health := ProgressBar.new()
		health.position = Vector2(-68, 40)
		health.max_value = hero.health
		health.value = hero.health
		health.show_percentage = false
		health.add_theme_font_size_override("font_size", 1)
		for part in ["background", "fill"]:
			var color := Color("78c5a4") if part == "fill" else Color("0b1119")
			var style := _panel(color, color, 0)
			style.set_content_margin_all(0)
			style.set_corner_radius_all(3)
			health.add_theme_stylebox_override(part, style)
		body.add_child(health)
		health.set_deferred("size", Vector2(136, 9))
		var nameplate := _label(hero.name, 18, Color("edf1f7"))
		nameplate.position = Vector2(-85, 55)
		nameplate.size.x = 170
		body.add_child(nameplate)
		fighters[id] = {"body": body, "sprite": sprite, "bar": health, "name": nameplate}
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


func _animate_hit(event: Dictionary) -> void:
	var source: Dictionary = fighters[event.attacker]
	var target: Dictionary = fighters[event.target]
	var sprite: AnimatedSprite2D = source.sprite
	var distance: Vector2 = target.body.position - source.body.position
	sprite.flip_h = distance.x < 0
	sprite.play("attack")
	var motion := sprite.create_tween()
	motion.tween_property(sprite, "position", distance * 0.65, 0.15).set_trans(Tween.TRANS_QUAD)
	motion.tween_property(sprite, "position", Vector2.ZERO, 0.25).set_delay(0.1)
	var flash: Tween = target.sprite.create_tween()
	flash.tween_property(target.sprite, "modulate", Color("ffbc9e"), 0.1)
	flash.tween_property(target.sprite, "modulate", Color("515c68") if fight.health[event.target] == 0 else Color.WHITE, 0.3)
	target.bar.value = fight.health[event.target]
	if fight.health[event.target] == 0:
		target.name.text = "%s / OUT" % fight.heroes[event.target].name
		target.sprite.stop()
	if event.winner >= 0:
		fighters[event.winner].name.text = "%s / WINNER" % fight.heroes[event.winner].name
		fighters[event.winner].name.add_theme_color_override("font_color", GOLD)
