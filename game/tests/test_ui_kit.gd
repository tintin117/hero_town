extends RefCounted
## UI kit checks: theme, component scenes + setters, gallery layout at three window sizes, no game coupling.

const THEME := "res://game/ui/theme/fight_club_theme.tres"
const COMPONENTS := "res://game/ui/components/"
const SIZES: Array[Vector2i] = [Vector2i(960, 420), Vector2i(1280, 420), Vector2i(1600, 560)]
const ICONS := ["star", "star_empty", "star_half", "flame", "crowd", "trophy", "lock", "play", "pause", "laurel",
	"fireworks", "megaphone", "spotlight", "drink", "poster"]
const VARIATIONS := {"Label": ["TitleLabel", "NumberLabel", "SmallLabel", "GoldLabel", "DarkLabel"],
	"PanelContainer": ["HudBar", "Pill", "Drawer", "Ribbon", "Chip"], "Button": ["RedButton", "IconButton", "CostButton"]}

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var theme := load(THEME) as Theme
	if theme == null:
		return ["fight_club_theme.tres does not load"]
	_check_theme(theme)
	for icon in ICONS:
		var tex := load("res://resources/ui/icons/%s.png" % icon) as Texture2D
		if tex == null:
			problems.append("missing icon %s" % icon)
	_check_components(theme)
	_check_gallery(theme)
	_check_no_game_coupling()
	return problems


func _check_theme(theme: Theme) -> void:
	for type in ["Button", "Panel", "PanelContainer", "Label", "ProgressBar", "HSlider", "CheckBox", "CheckButton", "TooltipPanel", "TabContainer", "VScrollBar", "HSeparator"]:
		if not theme.get_type_list().has(type):
			problems.append("theme lacks type %s" % type)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not theme.has_stylebox(state, "Button"):
			problems.append("Button/%s missing" % state)
	if theme.get_stylebox("hover", "Button") == theme.get_stylebox("normal", "Button"):
		problems.append("Button hover must differ from normal")
	if theme.default_font == null:
		problems.append("theme has no default font")
	for base: String in VARIATIONS:
		for v: String in VARIATIONS[base]:
			if theme.get_type_variation_base(v) != base:
				problems.append("type variation %s (%s) missing" % [v, base])


func _host(theme: Theme) -> Control:
	var host := Control.new()
	host.theme = theme
	host.size = Vector2(400, 300)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


func _check_components(theme: Theme) -> void:
	var host := _host(theme)
	var scenes := Array(DirAccess.get_files_at(COMPONENTS)).filter(func(f: String) -> bool: return f.ends_with(".tscn"))
	if scenes.size() < 10:
		problems.append("expected >= 10 component scenes, found %d" % scenes.size())
	var tex := load("res://resources/ui/icons/coin.png") as Texture2D
	for file: String in scenes:
		var node := (load(COMPONENTS + file) as PackedScene).instantiate()
		var name := file.get_basename()
		if name == "toast":  # its _ready awaits a frame; just prove the API
			node.setup(tex, "hello", 1.0)
			if node.text != "hello":
				problems.append("toast.setup did not store the text")
			node.free()
			continue
		host.add_child(node)
		match name:
			"icon_button":
				node.icon_texture = tex
				node.tip = "tip"
				node.toggle_mode = true
				node.set_active(true)
				if not node.button_pressed or node.icon != tex or node.tooltip_text != "tip":
					problems.append("icon_button setters")
			"stat_pill":
				node.icon = tex
				node.set_value(1234567, false)
				node.set_progress(0.5)
				if node.get_node("Row/Column/Value").text != "1,234,567":
					problems.append("stat_pill number format: %s" % node.get_node("Row/Column/Value").text)
				node.text = "Tier 2"
				if node.get_node("Row/Column/Value").text != "Tier 2":
					problems.append("stat_pill text override")
			"hype_gauge":
				node.set_threshold(70)
				node.set_value(30)
				if node.is_ready_to_book():
					problems.append("hype below threshold must not be ready")
				node.set_value(80)
				if not node.is_ready_to_book() or not node.get_node("Bar").hot:
					problems.append("hype at/above threshold must highlight")
			"excitement_gauge":
				node.set_value(10)
				var t0: int = node.tier
				node.set_value(30)
				var t1: int = node.tier
				node.set_value(70)
				if t0 != 0 or t1 != 1 or node.tier != 2:
					problems.append("excitement tiers 0/1/2 expected, got %d/%d/%d" % [t0, t1, node.tier])
				if node.get_node("Column/Head/TierName").text == "":
					problems.append("excitement tier name empty")
			"hero_card":
				node.portrait = load("res://resources/ui/avatars/avatar_01.png")
				node.hero_name = "Bram"
				node.level = 5
				node.set_hp(30, 60)
				node.set_mana(10, 40)
				var icons: Array[Texture2D] = [tex, tex]
				node.set_traits(icons, PackedStringArray(["a", "b"]))
				node.selected = true
				node.disabled = true
				if node.get_node("Card/Row/Info/Traits").get_child_count() != 2 or not is_equal_approx(node.hp, 0.5):
					problems.append("hero_card setters")
			"star_rating":
				node.set_range(2.0, 4.0)
				if node.get_child_count() != 5:
					problems.append("star_rating needs 5 stars")
			"badge":
				node.set_count(3)
				node.pulsing = true
				if not node.visible:
					problems.append("badge with count must be visible")
				node.set_count(0)
				node.pulsing = false
				if node.visible:
					problems.append("empty badge must hide")
			"drawer":
				var closed := [0]
				node.closed.connect(func() -> void: closed[0] += 1)
				node.title = "Roster"
				node.open()
				node.close()
				if not node.get_body() is Container or closed[0] != 1:
					problems.append("drawer open/close/closed signal")
			"cost_button":
				node.cost = 500
				node.set_gold(100)
				if not node.disabled:
					problems.append("cost_button must disable when unaffordable")
				node.set_gold(900)
				if node.disabled:
					problems.append("cost_button must enable when affordable")
			"pixel_bar":
				node.ratio = 0.5
				node.kind = PixelBar.Kind.MANA
			"trait_chip":
				node.set_icon(tex, "tip")
	host.free()


## Runs the container layout passes top-down so rects are valid without waiting a frame.
func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _controls(n: Node, out: Array[Control]) -> void:
	for c in n.get_children():
		if c is Control and c.visible:
			out.append(c)
		_controls(c, out)


func _check_gallery(theme: Theme) -> void:
	for s in SIZES:
		var vp := SubViewport.new()
		vp.size = s
		(Engine.get_main_loop() as SceneTree).root.add_child(vp)
		var gallery := (load("res://game/ui/ui_gallery.tscn") as PackedScene).instantiate() as Control
		vp.add_child(gallery)
		for i in 3:
			_layout(gallery)
		var window := Rect2(Vector2.ZERO, Vector2(s))
		var all: Array[Control] = []
		_controls(gallery, all)
		if all.size() < 100:
			problems.append("%s: gallery has only %d controls" % [s, all.size()])
		var scroll := gallery.get_node("Scroll") as ScrollContainer
		for c in all:
			var r := c.get_global_rect()
			var in_scroll := scroll.is_ancestor_of(c)
			# below the fold inside the ScrollContainer is fine; horizontal overflow never is
			var ok := (r.position.x >= -0.5 and r.end.x <= window.end.x + 0.5) if in_scroll else window.grow(0.5).encloses(r)
			if not ok and not (c is ScrollBar) and not c.get_parent() is Popup:
				problems.append("%s: %s outside window %s" % [s, c.get_path(), r])
				break
		var hud := gallery.find_child("MockHud", true, false) as Control
		if hud == null:
			problems.append("%s: gallery lacks the mock HUD" % s)
		else:
			var groups: Array[Control] = []
			for g in ["TopBar", "BottomBar", "Excitement"]:
				groups.append(hud.get_node(g))
			_no_overlap(groups, "%s HUD groups" % s)
			_no_overlap(_kids(hud.get_node("TopBar/Row")), "%s top bar" % s)
			_no_overlap(_kids(hud.get_node("BottomBar/Row")), "%s bottom bar" % s)
			var frame := hud.get_parent() as Control
			if frame.get_global_rect().end.y > s.y + 0.5:
				problems.append("%s: mock HUD frame taller than the window" % s)
		vp.free()


func _kids(n: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in n.get_children():
		if c is Control and c.visible:
			out.append(c)
	return out


func _no_overlap(items: Array[Control], label: String) -> void:
	for i in items.size():
		for j in range(i + 1, items.size()):
			var hit := items[i].get_global_rect().intersection(items[j].get_global_rect())
			if hit.size.x > 1.0 and hit.size.y > 1.0:
				problems.append("%s: %s overlaps %s" % [label, items[i].name, items[j].name])


func _check_no_game_coupling() -> void:
	var re := RegEx.create_from_string("\\b(Game|Events|GameState)\\b")
	for dir in ["res://game/ui/components/", "res://game/ui/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for line in FileAccess.get_file_as_string(dir + f).split("\n"):
				var code := line.split("#")[0]
				if re.search(code) != null:
					problems.append("%s%s references the game layer: %s" % [dir, f, line.strip_edges()])
