extends SceneTree
## Writes game/ui/theme/fight_club_theme.tres from the derived textures (run build_ui_textures.gd + --import first).
## godot --headless --path . --script res://docs/ui_tools/build_theme.gd
## Everything visual lives in this one theme; scenes only pick type variations (TitleLabel, Pill, HypeGauge, ...).

const TEX := "res://game/ui/theme/tex/"
const OL := Color("161c2e")
const CREAM := Color("f4ead2")
const CREAM_MUTED := Color("c9bfa6")
const GOLD_TEXT := Color("ffd75e")
const DARK_TEXT := Color("2b3247")
const DARK_MUTED := Color("6b6a72")
const SHADOW := Color(0.086, 0.11, 0.18, 0.95)

var t := Theme.new()


func _init() -> void:
	var font := load("res://fonts/PeaberryBase.ttf") as Font
	t.default_font = font
	t.default_font_size = 16
	labels()
	buttons()
	panels()
	gauges()
	sliders_and_scrolls()
	checks()
	tabs_and_tooltip()
	var err := ResourceSaver.save(t, "res://game/ui/theme/fight_club_theme.tres")
	print("saved theme: ", error_string(err))
	quit()


func tex(name: String, m: Array, c: Array = [], center := true) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(TEX + name + ".png")
	s.texture_margin_left = m[0]
	s.texture_margin_top = m[1]
	s.texture_margin_right = m[2]
	s.texture_margin_bottom = m[3]
	s.draw_center = center
	if c.size() == 4:
		s.content_margin_left = c[0]
		s.content_margin_top = c[1]
		s.content_margin_right = c[2]
		s.content_margin_bottom = c[3]
	return s


func flat(bg: Color, border: Color, radius: int, bw := 2, cm := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	if cm > 0:
		s.set_content_margin_all(cm)
	return s


func labels() -> void:
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 0)
	var variants := {
		"SmallLabel": ["Label", CREAM_MUTED, 16, 0],
		"NumberLabel": ["Label", Color("fff6d8"), 24, 3],
		"TitleLabel": ["Label", Color("fff6d8"), 24, 4],
		"GoldLabel": ["Label", GOLD_TEXT, 16, 0],
		"BadgeLabel": ["Label", Color.WHITE, 16, 3],
		"DarkLabel": ["Label", DARK_TEXT, 16, 0],
		"DarkSmallLabel": ["Label", DARK_MUTED, 16, 0],
	}
	for n: String in variants:
		var v: Array = variants[n]
		t.set_type_variation(n, v[0])
		t.set_color("font_color", n, v[1])
		t.set_font_size("font_size", n, v[2])
		if n.begins_with("Dark"):
			t.set_color("font_shadow_color", n, Color(1, 1, 1, 0.0))
		elif v[3] > 0:
			t.set_constant("outline_size", n, v[3])
			t.set_color("font_outline_color", n, OL)
			t.set_color("font_shadow_color", n, Color(0, 0, 0, 0))


func buttons() -> void:
	var cm := [12, 5, 12, 10]
	var m := [14, 14, 14, 16]
	var normal := tex("btn_normal", m, cm)
	var hover := tex("btn_hover", m, cm)
	var pressed := tex("btn_pressed", m, [12, 9, 12, 7])
	var disabled := tex("btn_disabled", m, cm)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", tex("focus_ring", [8, 8, 8, 8], [], false))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color("fff6b0"))
	t.set_color("font_pressed_color", "Button", Color("dfd3ad"))
	t.set_color("font_hover_pressed_color", "Button", Color("dfd3ad"))
	t.set_color("font_focus_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color("54463a"))
	t.set_color("icon_normal_color", "Button", Color.WHITE)
	t.set_color("icon_hover_color", "Button", Color(1.12, 1.12, 1.05))
	t.set_color("icon_pressed_color", "Button", Color(0.9, 0.9, 0.9))
	t.set_color("icon_disabled_color", "Button", Color(0.55, 0.55, 0.55, 0.8))
	t.set_color("font_shadow_color", "Button", SHADOW)
	t.set_constant("shadow_offset_x", "Button", 1)
	t.set_constant("shadow_offset_y", "Button", 1)
	t.set_constant("h_separation", "Button", 6)
	# red: the "stop / danger" call to action
	t.set_type_variation("RedButton", "Button")
	t.set_stylebox("normal", "RedButton", tex("btn_red", m, cm))
	t.set_stylebox("hover", "RedButton", tex("btn_red", m, cm))
	t.set_stylebox("pressed", "RedButton", tex("btn_red_pressed", m, [12, 9, 12, 7]))
	t.set_stylebox("hover_pressed", "RedButton", tex("btn_red_pressed", m, [12, 9, 12, 7]))
	# compact icon-only button
	t.set_type_variation("CostButton", "Button")
	t.set_color("font_disabled_color", "CostButton", Color("8c1f24"))
	t.set_color("icon_disabled_color", "CostButton", Color(0.8, 0.7, 0.65, 0.9))
	t.set_type_variation("IconButton", "Button")
	var ic := [6, 3, 6, 8]
	t.set_stylebox("normal", "IconButton", tex("btn_normal", m, ic))
	t.set_stylebox("hover", "IconButton", tex("btn_hover", m, ic))
	t.set_stylebox("pressed", "IconButton", tex("btn_pressed", m, [6, 7, 6, 4]))
	t.set_stylebox("hover_pressed", "IconButton", tex("btn_pressed", m, [6, 7, 6, 4]))
	t.set_stylebox("disabled", "IconButton", tex("btn_disabled", m, ic))


func panels() -> void:
	var paper := tex("paper_cream", [8, 8, 8, 8], [10, 8, 10, 8])
	t.set_stylebox("panel", "Panel", paper)
	t.set_stylebox("panel", "PanelContainer", paper)
	var v := {
		"HudBar": [tex("hud_bar", [8, 8, 8, 8], [8, 5, 8, 5])],
		"Pill": [tex("pill", [7, 7, 7, 7], [8, 2, 8, 3])],
		"Slot": [tex("slot", [8, 8, 8, 8], [6, 6, 6, 6])],
		"Chip": [tex("chip", [5, 5, 5, 5], [3, 1, 3, 2])],
		"Drawer": [tex("paper_slate", [22, 22, 22, 22], [18, 14, 18, 14])],
		"Ribbon": [tex("ribbon_blue", [32, 0, 32, 0], [36, 2, 36, 5])],
		"SelectRing": [tex("focus_ring", [8, 8, 8, 8], [], false)],
	}
	for n: String in v:
		t.set_type_variation(n, "PanelContainer")
		t.set_stylebox("panel", n, v[n][0])
	t.set_type_variation("Ring", "Panel")
	t.set_stylebox("panel", "Ring", tex("focus_ring", [8, 8, 8, 8], [], false))
	t.set_type_variation("SlotPanel", "Panel")
	t.set_stylebox("panel", "SlotPanel", tex("slot", [8, 8, 8, 8]))
	t.set_type_variation("DrawerBody", "Panel")
	t.set_stylebox("panel", "DrawerBody", tex("paper_slate", [22, 22, 22, 22]))
	t.set_type_variation("HudPanel", "Panel")
	t.set_stylebox("panel", "HudPanel", tex("hud_bar", [8, 8, 8, 8]))
	t.set_type_variation("PillPanel", "Panel")
	t.set_stylebox("panel", "PillPanel", tex("pill", [7, 7, 7, 7]))
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 4)
	for pair in [["TightVBox", "VBoxContainer", 0], ["GaugeRow", "HBoxContainer", 6], ["ChipRow", "HBoxContainer", 3]]:
		t.set_type_variation(pair[0], pair[1])
		t.set_constant("separation", pair[0], pair[2])
	t.set_stylebox("separator", "HSeparator", flat(Color("8a6f55"), Color("8a6f55"), 0, 0))
	(t.get_stylebox("separator", "HSeparator") as StyleBoxFlat).content_margin_top = 1
	(t.get_stylebox("separator", "HSeparator") as StyleBoxFlat).content_margin_bottom = 1
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("separator", "VSeparator", flat(Color("48598a"), Color("48598a"), 0, 0))
	(t.get_stylebox("separator", "VSeparator") as StyleBoxFlat).content_margin_left = 1
	(t.get_stylebox("separator", "VSeparator") as StyleBoxFlat).content_margin_right = 1
	t.set_constant("separation", "VSeparator", 8)


func gauges() -> void:
	# thin flat progress bar (fame progress under a pill); border colour = outline, so the ends read as capped
	t.set_type_variation("MiniBar", "ProgressBar")
	var mb := flat(Color("1c2440"), OL, 3, 2)
	mb.set_content_margin_all(0)
	t.set_stylebox("background", "MiniBar", mb)
	t.set_stylebox("fill", "MiniBar", flat(Color("ffc93c"), OL, 3, 2))
	var base := tex("gauge_base", [12, 8, 12, 8])
	for pair in [["ProgressBar", "fill_excite"], ["HypeGauge", "fill_hype"], ["ExciteGauge", "fill_excite"], ["HpGauge", "fill_green"], ["ManaGauge", "fill_blue"]]:
		var n: String = pair[0]
		var fill := tex(pair[1], [0, 0, 0, 0])
		if n == "ProgressBar":
			t.set_stylebox("background", n, base)
			t.set_stylebox("fill", n, fill)
			fill.expand_margin_left = -6
			fill.expand_margin_right = -6
			fill.expand_margin_top = -7
			fill.expand_margin_bottom = -7
			t.set_font_size("font_size", n, 16)
			t.set_color("font_color", n, CREAM)
			t.set_color("font_outline_color", n, OL)
			t.set_constant("outline_size", n, 3)
		else:
			# custom "GaugeBar" control reads these; inset = border thickness of the base art
			t.set_stylebox("base", n, base)
			t.set_stylebox("fill", n, fill)
			t.set_constant("inset_left", n, 6)
			t.set_constant("inset_right", n, 6)
			t.set_constant("inset_top", n, 7)
			t.set_constant("inset_bottom", n, 7)
	t.set_color("mark", "ExciteGauge", Color("161c2e"))
	t.set_color("mark", "HypeGauge", Color("161c2e"))


func sliders_and_scrolls() -> void:
	var track := flat(Color("1c2440"), OL, 4, 2)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var area := flat(Color("ffc93c"), OL, 4, 2)
	area.border_color = Color("d18b1f")
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("ffe27a"), Color("d18b1f"), 4, 2))
	var knob := load(TEX + "knob.png") as Texture2D
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", load(TEX + "knob_hover.png"))
	t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_icon("tick", "HSlider", knob)
	t.set_constant("center_grabber", "HSlider", 0)
	t.set_constant("grabber_offset", "HSlider", 0)
	var blank := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for n in ["VScrollBar", "HScrollBar"]:
		var w := 10
		var scroll := flat(Color("1c2440"), OL, 3, 2)
		scroll.set_content_margin_all(0)
		t.set_stylebox("scroll", n, scroll)
		t.set_stylebox("scroll_focus", n, scroll)
		t.set_stylebox("grabber", n, flat(Color("d8c79a"), OL, 3, 2))
		t.set_stylebox("grabber_highlight", n, flat(Color("fff2a0"), OL, 3, 2))
		t.set_stylebox("grabber_pressed", n, flat(Color("ffc93c"), OL, 3, 2))
		for ic in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(ic, n, blank)
		t.set_constant("padding", n, 0)
	# the scrollbars keep a fixed 10px thickness through their minimum size
	(t.get_stylebox("scroll", "VScrollBar") as StyleBoxFlat).content_margin_left = 5
	(t.get_stylebox("scroll", "VScrollBar") as StyleBoxFlat).content_margin_right = 5
	(t.get_stylebox("scroll", "HScrollBar") as StyleBoxFlat).content_margin_top = 5
	(t.get_stylebox("scroll", "HScrollBar") as StyleBoxFlat).content_margin_bottom = 5


func checks() -> void:
	for n in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", n, CREAM)
		t.set_color("font_hover_color", n, Color("fff6b0"))
		t.set_color("font_pressed_color", n, CREAM)
		t.set_color("font_hover_pressed_color", n, Color("fff6b0"))
		t.set_color("font_disabled_color", n, Color("9a8f7c"))
		t.set_color("font_shadow_color", n, SHADOW)
		t.set_constant("shadow_offset_x", n, 1)
		t.set_constant("shadow_offset_y", n, 1)
		t.set_constant("h_separation", n, 8)
		t.set_stylebox("focus", n, tex("focus_ring", [8, 8, 8, 8], [], false))
	t.set_icon("checked", "CheckBox", load(TEX + "check_on.png"))
	t.set_icon("unchecked", "CheckBox", load(TEX + "check_off.png"))
	t.set_icon("checked_disabled", "CheckBox", load(TEX + "check_on.png"))
	t.set_icon("unchecked_disabled", "CheckBox", load(TEX + "check_off.png"))
	t.set_icon("checked", "CheckButton", load(TEX + "switch_on.png"))
	t.set_icon("unchecked", "CheckButton", load(TEX + "switch_off.png"))
	t.set_icon("checked_disabled", "CheckButton", load(TEX + "switch_on.png"))
	t.set_icon("unchecked_disabled", "CheckButton", load(TEX + "switch_off.png"))


func tabs_and_tooltip() -> void:
	t.set_stylebox("panel", "TabContainer", tex("paper_cream", [8, 8, 8, 8], [10, 8, 10, 8]))
	t.set_stylebox("tab_selected", "TabContainer", tex("paper_cream", [8, 8, 8, 8], [10, 4, 10, 4]))
	t.set_stylebox("tab_hovered", "TabContainer", tex("pill", [7, 7, 7, 7], [10, 4, 10, 4]))
	t.set_stylebox("tab_unselected", "TabContainer", tex("hud_bar", [8, 8, 8, 8], [10, 4, 10, 4]))
	t.set_stylebox("tab_focus", "TabContainer", tex("focus_ring", [8, 8, 8, 8], [], false))
	t.set_color("font_selected_color", "TabContainer", DARK_TEXT)
	t.set_color("font_hovered_color", "TabContainer", Color("fff6b0"))
	t.set_color("font_unselected_color", "TabContainer", CREAM_MUTED)
	t.set_constant("side_margin", "TabContainer", 6)
	t.set_stylebox("panel", "TooltipPanel", tex("paper_cream", [8, 8, 8, 8], [8, 5, 8, 6]))
	t.set_color("font_color", "TooltipLabel", DARK_TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	t.set_font_size("font_size", "TooltipLabel", 16)
