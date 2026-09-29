extends Control
## Every UI kit widget in every state on the themed background. Scroll for the sheets under the mock HUD.
## Run this scene directly (F6). `-- drawer` in the user args opens the sample drawer on start.

const C := "res://game/ui/components/"
const ICONS := "res://resources/ui/icons/"

var _drawer: Drawer
var _toasts: Control
var _sliders_label: Label
var _hype_demo: HypeGauge
var _t := 0.0

@onready var _sections: VBoxContainer = $Scroll/Margin/Sections


func _ready() -> void:
	_build_hud()
	_build_buttons()
	_build_labels_and_pills()
	_build_gauges()
	_build_heroes()
	_build_stars_and_badges()
	_build_popups()
	_build_icon_sheet()
	for a in OS.get_cmdline_user_args():
		if a == "drawer":
			_drawer.open()
		elif a.begins_with("scroll="):
			await get_tree().process_frame
			$Scroll.scroll_vertical = int(a.substr(7))


func _process(delta: float) -> void:
	_t += delta
	if _hype_demo:
		_hype_demo.set_value(fmod(_t * 12.0, 100.0))


func _icon(name: String) -> Texture2D:
	return load(ICONS + name + ".png")


func _new(scene: String) -> Node:
	return (load(C + scene + ".tscn") as PackedScene).instantiate()


## Adds a titled row and returns its flow container.
func _section(title: String) -> HFlowContainer:
	var head := Label.new()
	head.theme_type_variation = &"TitleLabel"
	head.text = title
	_sections.add_child(head)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudBar"
	_sections.add_child(panel)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 10)
	panel.add_child(flow)
	return flow


func _caption(parent: Control, text: String, node: Control) -> void:
	var col := VBoxContainer.new()
	var l := Label.new()
	l.theme_type_variation = &"SmallLabel"
	l.text = text
	col.add_child(l)
	col.add_child(node)
	parent.add_child(col)


func _build_hud() -> void:
	var frame := Control.new()  # the first screenful is the mock game screen, scroll down for the sheets
	frame.name = "MockFrame"
	frame.clip_contents = true
	_sections.add_child(frame)
	var fit := func() -> void: frame.custom_minimum_size.y = maxf(size.y - 8.0, 300.0)
	fit.call()
	resized.connect(fit)
	var hud := (load("res://game/ui/mock_hud.tscn") as PackedScene).instantiate()
	frame.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)


func _build_buttons() -> void:
	var f := _section("Buttons, toggles, sliders")
	var b := Button.new()
	b.text = "Button"
	_caption(f, "normal", b)
	var hover := Button.new()
	hover.text = "Hover"
	hover.add_theme_stylebox_override("normal", theme.get_stylebox("hover", "Button"))  # gallery-only: force the hover look
	_caption(f, "hover (forced)", hover)
	var pressed := Button.new()
	pressed.text = "Pressed"
	pressed.add_theme_stylebox_override("normal", theme.get_stylebox("pressed", "Button"))
	_caption(f, "pressed (forced)", pressed)
	var dis := Button.new()
	dis.text = "Disabled"
	dis.disabled = true
	_caption(f, "disabled", dis)
	var red := Button.new()
	red.text = "Stop"
	red.icon = _icon("close")
	red.theme_type_variation = &"RedButton"
	_caption(f, "RedButton", red)
	var ib := _new("icon_button") as IconButton
	ib.icon_texture = _icon("sword")
	ib.tip = "Icon button with tooltip"
	_caption(f, "IconButton", ib)
	var tb := _new("icon_button") as IconButton
	tb.icon_texture = _icon("shield")
	tb.toggle_mode = true
	tb.set_active(true)
	_caption(f, "toggle on", tb)
	var tb2 := _new("icon_button") as IconButton
	tb2.icon_texture = _icon("hammer")
	tb2.toggle_mode = true
	_caption(f, "toggle off", tb2)
	var id := _new("icon_button") as IconButton
	id.icon_texture = _icon("scroll")
	id.disabled = true
	_caption(f, "disabled", id)
	for pair in [["afford", 120, false], ["too dear", 5000, true]]:
		var cb := _new("cost_button") as CostButton
		cb.cost = pair[1]
		cb.label = "Bar" if not pair[2] else "Spotlights"
		cb.unaffordable = pair[2]
		_caption(f, "CostButton " + pair[0], cb)
	var chk := CheckBox.new()
	chk.text = "Music"
	chk.button_pressed = true
	_caption(f, "CheckBox", chk)
	var sw := CheckButton.new()
	sw.text = "Manager"
	sw.button_pressed = true
	_caption(f, "CheckButton", sw)
	var box := VBoxContainer.new()
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(180, 20)
	slider.min_value = 30
	slider.max_value = 100
	slider.value = 70
	_sliders_label = Label.new()
	_sliders_label.theme_type_variation = &"GoldLabel"
	_sliders_label.text = "Book at hype >= 70"
	slider.value_changed.connect(func(v: float) -> void: _sliders_label.text = "Book at hype >= %d" % v)
	box.add_child(slider)
	box.add_child(_sliders_label)
	_caption(f, "HSlider", box)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(240, 96)
	for n in ["Heroes", "Props"]:
		var l := Label.new()
		l.theme_type_variation = &"DarkLabel"
		l.text = n + " tab"
		l.name = n
		tabs.add_child(l)
	_caption(f, "TabContainer", tabs)
	var tip := Label.new()
	tip.text = "Hover me for a tooltip"
	tip.mouse_filter = Control.MOUSE_FILTER_STOP
	tip.tooltip_text = "Cream paper tooltip\nwith two lines"
	_caption(f, "TooltipPanel", tip)


func _build_labels_and_pills() -> void:
	var f := _section("Labels and stat pills")
	for pair in [["Title", &"TitleLabel"], ["Number 1,240", &"NumberLabel"], ["Label text", &"Label"], ["Small text", &"SmallLabel"], ["Gold text", &"GoldLabel"]]:
		var l := Label.new()
		l.theme_type_variation = pair[1]
		l.text = pair[0]
		f.add_child(l)
	var paper := PanelContainer.new()
	var dl := VBoxContainer.new()
	for pair in [["Dark on paper", &"DarkLabel"], ["Dark small", &"DarkSmallLabel"]]:
		var l := Label.new()
		l.theme_type_variation = pair[1]
		l.text = pair[0]
		dl.add_child(l)
	paper.add_child(dl)
	f.add_child(paper)
	var gold := _new("stat_pill") as StatPill
	gold.icon = _icon("coin")
	gold.value = 1240
	_caption(f, "gold", gold)
	var seats := _new("stat_pill") as StatPill
	seats.icon = _icon("crowd")
	seats.value = 100
	_caption(f, "seats", seats)
	var fame := _new("stat_pill") as StatPill
	fame.icon = _icon("laurel")
	fame.text = "Tier 2"
	fame.progress = 0.4
	_caption(f, "fame + progress", fame)
	var live := _new("stat_pill") as StatPill
	live.icon = _icon("coin")
	live.value = 100
	_caption(f, "tweening", live)
	var timer := Timer.new()
	timer.wait_time = 1.6
	timer.autostart = true
	timer.timeout.connect(func() -> void: live.set_value(live.value + randi_range(40, 900)))
	add_child(timer)


func _build_gauges() -> void:
	var f := _section("Hype, excitement, progress")
	var h1 := _new("hype_gauge") as HypeGauge
	h1.value = 35
	h1.threshold = 70
	_caption(f, "hype 35 / marker 70", h1)
	var h2 := _new("hype_gauge") as HypeGauge
	h2.value = 82
	h2.threshold = 70
	_caption(f, "hype >= threshold (pulses)", h2)
	_hype_demo = _new("hype_gauge") as HypeGauge
	_hype_demo.threshold = 60
	_caption(f, "animated", _hype_demo)
	for v in [12, 42, 58, 88]:
		var e := _new("excitement_gauge") as ExcitementGauge
		e.value = v
		e.multiplier_text = "x1" if v < 25 else ("x1.25" if v < 60 else "x2.5")
		_caption(f, "excitement %d" % v, e)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(180, 26)
	pb.value = 60
	pb.show_percentage = false
	_caption(f, "ProgressBar", pb)
	var mini := ProgressBar.new()
	mini.theme_type_variation = &"MiniBar"
	mini.custom_minimum_size = Vector2(180, 8)
	mini.value = 45
	mini.show_percentage = false
	_caption(f, "MiniBar", mini)
	var bars := HBoxContainer.new()
	for k in [[PixelBar.Kind.HP, 1.0], [PixelBar.Kind.HP, 0.55], [PixelBar.Kind.HP, 0.1], [PixelBar.Kind.MANA, 0.7], [PixelBar.Kind.RED, 0.5]]:
		var pxb := _new("pixel_bar") as PixelBar
		pxb.kind = k[0]
		pxb.ratio = k[1]
		bars.add_child(pxb)
	_caption(f, "PixelBar HP / mana (3x)", bars)


func _build_heroes() -> void:
	var f := _section("Hero cards")
	var trait_icons: Array[Texture2D] = [_icon("star"), _icon("flame")]
	var tips := PackedStringArray(["Showman", "Brawler"])
	var av := "res://resources/ui/avatars/avatar_%02d.png"
	var states := [["normal", 1, "Bram", 5, false, false, 0.85], ["selected", 5, "Ivo", 6, true, false, 1.0], ["low hp", 10, "Nia", 10, false, false, 0.2], ["disabled", 3, "Tuck", 2, false, true, 1.0], ["no traits", 12, "Rook", 1, false, false, 0.6]]
	for s in states:
		var c := _new("hero_card") as HeroCard
		c.portrait = load(av % s[1])
		c.hero_name = s[2]
		c.level = s[3]
		c.selected = s[4]
		c.disabled = s[5]
		c.hp = s[6]
		c.mana = 0.6
		if s[0] != "no traits":
			c.set_traits(trait_icons, tips)
		_caption(f, s[0], c)


func _build_stars_and_badges() -> void:
	var f := _section("Stars and badges")
	for r in [[0.0, 0.0], [2.5, 2.5], [5.0, 5.0], [2.0, 4.0], [1.0, 3.5]]:
		var s := _new("star_rating") as StarRating
		s.set_range(r[0], r[1])
		_caption(f, "%s - %s" % [r[0], r[1]], s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var specs := [["count", 3, "", null, Color("e0453f"), false], ["!", 0, "!", null, Color("45b25a"), true], ["icon", 0, "", _icon("coin"), Color("4697ac"), false], ["99+", 120, "", null, Color("e0453f"), false]]
	for sp in specs:
		var b := _new("badge") as Badge
		b.count = sp[1]
		b.text = sp[2]
		b.icon = sp[3]
		b.tint = sp[4]
		b.pulsing = sp[5]
		row.add_child(b)
	_caption(f, "Badge: count, pulsing !, icon, 99+", row)


func _build_popups() -> void:
	var f := _section("Toast and drawer")
	_toasts = Control.new()
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toasts.offset_top = -64
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	var t := (load(C + "toast.tscn") as PackedScene).instantiate() as Toast
	t.setup(_icon("coin"), "+238 at finish", 1e6)
	f.add_child(t)
	var spawn := Button.new()
	spawn.text = "Spawn toast"
	spawn.pressed.connect(func() -> void:
		var n := (load(C + "toast.tscn") as PackedScene).instantiate() as Toast
		n.setup(_icon("star"), "Story ripe!")
		_toasts.add_child(n)
		n.position = Vector2(_toasts.size.x / 2 - 90, 8))
	f.add_child(spawn)
	var overlay := Control.new()  # drawers live in a full-rect layer above everything
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_drawer = _new("drawer") as Drawer
	_drawer.title = "Roster"
	_drawer.panel_size = Vector2(340, 250)
	overlay.add_child(_drawer)
	var body := _drawer.get_body()
	for n in ["Bram  Lv 5", "Ivo  Lv 6", "Nia  Lv 10"]:
		var l := Label.new()
		l.text = n
		body.add_child(l)
	body.add_child(HSeparator.new())
	var cb := _new("cost_button") as CostButton
	cb.label = "Recruit"
	cb.cost = 300
	body.add_child(cb)
	var open := Button.new()
	open.text = "Open drawer (ESC closes)"
	open.pressed.connect(_drawer.open)
	f.add_child(open)


func _build_icon_sheet() -> void:
	var f := _section("Icons (32px)")
	var d := DirAccess.open(ICONS)
	var files := Array(d.get_files()).filter(func(n: String) -> bool: return n.ends_with(".png"))
	files.sort()
	for n: String in files:
		var tr := TextureRect.new()
		tr.texture = load(ICONS + n)
		tr.tooltip_text = n.get_basename()
		tr.custom_minimum_size = Vector2(32, 32)
		f.add_child(tr)
