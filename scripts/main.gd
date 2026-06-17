extends Node2D

const GD = preload("res://scripts/game_data.gd")
const HeroScene := preload("res://scenes/hero.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BuildingScene := preload("res://scenes/building.tscn")
const ShrineScene := preload("res://scenes/shrine.tscn")
const EmptySlotScene := preload("res://scenes/empty_slot.tscn")

const GROUND_Y := 500.0
const HERO_X := 450.0
const SAVE_PATH := "user://save.json"

# Building grid constants
const CELL_WIDTH   := 192.0
const GRID_COLS    := 5
const GRID_ROWS    := 3
const GRID_START_X := 96.0
const LAYER_DATA := [
	{"y": 430.0, "scale": 0.75,   "z": 10},   # back
	{"y": 463.0, "scale": 0.875,  "z": 20},   # mid
	{"y": 498.0, "scale": 1.00,   "z": 30},   # front
]
# Pre-placed buildings at game start (not saved — always reconstructed)
const PREBUILT_TH     := {"layer": 1, "col": 0, "type": "town_hall"}
# Portal is saved separately so it can be repositioned later
const PORTAL_DEFAULT_LAYER := 1
const PORTAL_DEFAULT_COL   := 3

var gold := 50
var shards := 0
var first_kill_done := false
var first_th2_done := false
var first_shrine_roll_done := false
var first_tier3_kill_done := false
var discovered_heroes: Array[String] = ["H001"]
var active_hero_id := "H001"
var _overlay_active := false
var _build_mode_active := false

# Shrine node reference (set when shrine is placed)
var _shrine_node: Node2D = null

# Grid state: _grid[layer][col] = "" or building_type
var _grid: Array = []
# _building_nodes[layer][col_start] = Node2D or null
var _building_nodes: Array = []
var _active_build_layer: int = -1
var _active_build_col: int = -1
var _empty_slot_nodes: Array = []   # flat list of all live EmptySlot nodes

# Hero instances keyed by hero_id
var _hero_instances: Dictionary = {}

@onready var heroes_layer: Node2D = $HeroesLayer
@onready var enemies_layer: Node2D = $EnemiesLayer
@onready var gold_label: Label = $UI/GoldLabel
@onready var shard_label: Label = $UI/ShardLabel
@onready var hero_avatar: Control = $UI/HeroAvatar
@onready var building_popup: Control = $UI/BuildingPopup
@onready var build_menu_popup: Control = $UI/BuildMenuPopup
@onready var shrine_popup: Control = $UI/ShrinePopup
@onready var back_row: Node2D = $BuildingGrid/BackRow
@onready var mid_row: Node2D = $BuildingGrid/MidRow
@onready var front_row: Node2D = $BuildingGrid/FrontRow
@onready var town_hall: Node2D = $BuildingGrid/MidRow/TownHall
@onready var portal: Node2D = $BuildingGrid/MidRow/Portal

var hero_instance: CharacterBody2D = null

func _ready() -> void:
	_init_grid()
	_spawn_hero()
	_connect_buildings()
	_apply_save(load_game())
	_build_ui()
	_refresh_hud()
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		_enter_overlay_ui()

# ---- Save / Load ----

func save_game() -> void:
	var slots_data: Array = []
	# Save portal slot (it can be repositioned)
	for r in GRID_ROWS:
		for c in GRID_COLS:
			var t: String = _grid[r][c]
			if t == "portal":
				# Only save col_start (the column where the node lives)
				if _building_nodes[r][c] != null:
					slots_data.append({"layer": r, "col": c, "type": "portal"})
			elif t != "" and t != "town_hall":
				if _building_nodes[r][c] != null:
					slots_data.append({"layer": r, "col": c, "type": t})

	var shrine_level := 1
	if is_instance_valid(_shrine_node):
		shrine_level = _shrine_node.level

	var data := {
		"gold": gold,
		"shards": shards,
		"first_kill_done": first_kill_done,
		"first_th2_done": first_th2_done,
		"first_shrine_roll_done": first_shrine_roll_done,
		"first_tier3_kill_done": first_tier3_kill_done,
		"discovered_heroes": discovered_heroes,
		"active_hero_id": active_hero_id,
		"hero_level": hero_instance.level if is_instance_valid(hero_instance) else 1,
		"town_hall_level": town_hall.level,
		"portal_level": portal.level,
		"shrine_level": shrine_level,
		"building_slots": slots_data,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	return result if result is Dictionary else {}

func _apply_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	gold = data.get("gold", gold)
	shards = data.get("shards", shards)
	first_kill_done = data.get("first_kill_done", false)
	first_th2_done = data.get("first_th2_done", false)
	first_shrine_roll_done = data.get("first_shrine_roll_done", false)
	first_tier3_kill_done = data.get("first_tier3_kill_done", false)
	var saved_discovered = data.get("discovered_heroes", ["H001"])
	discovered_heroes = Array(saved_discovered, TYPE_STRING, "", null)
	active_hero_id = data.get("active_hero_id", "H001")

	# Restore building levels before hero so level cap is correct
	town_hall.level = data.get("town_hall_level", 1)
	portal.level = data.get("portal_level", 1)
	portal._refresh_enemy_pool()
	town_hall.level_cap_changed.emit(town_hall.hero_level_cap())

	# Restore hero level for H001
	var saved_hero_level: int = data.get("hero_level", 1)
	if is_instance_valid(hero_instance) and saved_hero_level > 1:
		hero_instance.level = saved_hero_level
		hero_instance._apply_stats()
		hero_instance.stats_changed.emit()

	# Spawn any additional discovered heroes (H001 already spawned at startup)
	for hid in discovered_heroes:
		if hid != "H001":
			_spawn_hero_by_id(hid)

	# Restore constructed buildings
	var saved_shrine_level: int = data.get("shrine_level", 1)
	var saved_slots: Array = data.get("building_slots", [])
	for entry in saved_slots:
		var t: String = entry.get("type", "")
		var r: int = entry.get("layer", -1)
		var c: int = entry.get("col", -1)
		if t == "" or r < 0 or c < 0:
			continue
		if t == "portal":
			# Move portal to saved position if different from default
			if r != PORTAL_DEFAULT_LAYER or c != PORTAL_DEFAULT_COL:
				_move_portal(r, c)
		else:
			_place_building(r, c, t)

	# Restore shrine level now that the node is placed
	if is_instance_valid(_shrine_node) and saved_shrine_level > 1:
		_shrine_node.level = saved_shrine_level

	_refresh_empty_slots()

# ---- Building Grid ----

func _init_grid() -> void:
	_grid = []
	_building_nodes = []
	for r in GRID_ROWS:
		_grid.append([])
		_building_nodes.append([])
		for _c in GRID_COLS:
			_grid[r].append("")
			_building_nodes[r].append(null)

	# Mark Town Hall (always layer 1, col 0-1, 2 cells wide)
	var th_data: Dictionary = GD.BUILDINGS["town_hall"]
	var th_w: int = th_data["cells_wide"] as int
	for i in th_w:
		_grid[PREBUILT_TH["layer"]][PREBUILT_TH["col"] + i] = "town_hall"
	_building_nodes[PREBUILT_TH["layer"]][PREBUILT_TH["col"]] = town_hall

	# Mark Portal (default layer 1, col 3-4, 2 cells wide)
	var p_data: Dictionary = GD.BUILDINGS["portal"]
	var p_w: int = p_data["cells_wide"] as int
	for i in p_w:
		_grid[PORTAL_DEFAULT_LAYER][PORTAL_DEFAULT_COL + i] = "portal"
	_building_nodes[PORTAL_DEFAULT_LAYER][PORTAL_DEFAULT_COL] = portal

	_refresh_empty_slots()

func _cell_center_x(col: int) -> float:
	return GRID_START_X + col * CELL_WIDTH + CELL_WIDTH * 0.5

func _can_place(layer: int, col: int, cells_wide: int) -> bool:
	if col < 0 or col + cells_wide > GRID_COLS:
		return false
	for i in cells_wide:
		if _grid[layer][col + i] != "":
			return false
	return true

func _get_row_node(layer: int) -> Node2D:
	match layer:
		0: return back_row
		1: return mid_row
		2: return front_row
	return mid_row

func _place_building(layer: int, col: int, building_type: String) -> void:
	var bdata: Dictionary = GD.BUILDINGS.get(building_type, {})
	if bdata.is_empty():
		return
	var cells_wide: int = bdata["cells_wide"] as int
	if not _can_place(layer, col, cells_wide):
		return

	# Mark grid cells
	for i in cells_wide:
		_grid[layer][col + i] = building_type

	# Instantiate building visual (shrine gets its own dedicated scene)
	var node: Node2D
	if building_type == "shrine":
		node = ShrineScene.instantiate()
		_shrine_node = node
		node.setup(GD.BUILDINGS["shrine"]["levels"], GD.HEROES)
		node.th_level = town_hall.level
		node.hero_rolled.connect(_on_shrine_hero_rolled)
		node.clicked.connect(func(): _on_building_clicked("shrine"))
	else:
		node = BuildingScene.instantiate()
	var row_node := _get_row_node(layer)
	row_node.add_child(node)

	var layer_scale: float = LAYER_DATA[layer]["scale"] as float
	var center_x := GRID_START_X + col * CELL_WIDTH + (cells_wide * CELL_WIDTH) * 0.5
	var layer_y: float = LAYER_DATA[layer]["y"] as float
	node.position = Vector2(center_x, layer_y)
	node.scale = Vector2(layer_scale, layer_scale)

	_building_nodes[layer][col] = node

	# Shrine wires its own signals above; other buildings get generic click
	if building_type != "shrine":
		node.clicked.connect(func(_n): _on_building_clicked(building_type))

func _move_portal(new_layer: int, new_col: int) -> void:
	var p_data: Dictionary = GD.BUILDINGS["portal"]
	var p_w: int = p_data["cells_wide"] as int

	# Clear old portal grid cells
	for r in GRID_ROWS:
		for c in GRID_COLS:
			if _grid[r][c] == "portal":
				_grid[r][c] = ""
				if _building_nodes[r][c] == portal:
					_building_nodes[r][c] = null

	if not _can_place(new_layer, new_col, p_w):
		# Can't place at new position — revert to default
		for i in p_w:
			_grid[PORTAL_DEFAULT_LAYER][PORTAL_DEFAULT_COL + i] = "portal"
		_building_nodes[PORTAL_DEFAULT_LAYER][PORTAL_DEFAULT_COL] = portal
		return

	for i in p_w:
		_grid[new_layer][new_col + i] = "portal"
	_building_nodes[new_layer][new_col] = portal

	var row_node := _get_row_node(new_layer)
	portal.reparent(row_node)
	var layer_scale: float = LAYER_DATA[new_layer]["scale"] as float
	var center_x := GRID_START_X + new_col * CELL_WIDTH + (p_w * CELL_WIDTH) * 0.5
	var layer_y: float = LAYER_DATA[new_layer]["y"] as float
	portal.position = Vector2(center_x, layer_y)
	portal.scale = Vector2(layer_scale, layer_scale)

func _refresh_empty_slots() -> void:
	# Remove all existing empty slot nodes
	for s in _empty_slot_nodes:
		if is_instance_valid(s):
			s.queue_free()
	_empty_slot_nodes.clear()

	if not _build_mode_active:
		return

	# Check what buildings can potentially be placed
	var any_buildable := false
	for btype in GD.BUILDINGS:
		if btype == "town_hall" or btype == "portal":
			continue
		var bdata: Dictionary = GD.BUILDINGS[btype]
		if (bdata["unlock_th_level"] as int) <= town_hall.level:
			any_buildable = true
			break
	if not any_buildable:
		return

	# Create EmptySlot for each empty cell
	for r in GRID_ROWS:
		for c in GRID_COLS:
			if _grid[r][c] != "":
				continue
			# Check if any buildable building can fit starting at this col
			var fits := false
			for btype in GD.BUILDINGS:
				if btype == "town_hall" or btype == "portal":
					continue
				var bdata: Dictionary = GD.BUILDINGS[btype]
				if (bdata["unlock_th_level"] as int) > town_hall.level:
					continue
				var w: int = bdata["cells_wide"] as int
				if _can_place(r, c, w):
					fits = true
					break
			if not fits:
				continue

			var slot: Node2D = EmptySlotScene.instantiate()
			var row_node := _get_row_node(r)
			row_node.add_child(slot)
			var layer_scale: float = LAYER_DATA[r]["scale"] as float
			slot.position = Vector2(_cell_center_x(c), LAYER_DATA[r]["y"] as float)
			slot.scale = Vector2(layer_scale, layer_scale)
			slot.layer_index = r
			slot.col_index = c
			slot.slot_clicked.connect(_on_slot_clicked)
			_empty_slot_nodes.append(slot)

# ---- Hero ----

func _spawn_hero() -> void:
	_spawn_hero_by_id("H001")
	hero_instance = _hero_instances.get("H001")

func _spawn_hero_by_id(hero_id: String) -> void:
	if hero_id in _hero_instances:
		return
	var hdata: Dictionary = GD.HEROES.get(hero_id, {})
	if hdata.is_empty():
		return
	var inst: CharacterBody2D = HeroScene.instantiate()
	inst.position = Vector2(_hero_spawn_x(_hero_instances.size()), GROUND_Y)
	inst.patrol_max_x = portal.global_position.x - 150.0
	heroes_layer.add_child(inst)
	inst.setup(hdata)
	inst.stats_changed.connect(_refresh_hero_card)
	_hero_instances[hero_id] = inst
	if hero_id == "H001" or hero_instance == null:
		hero_instance = inst

func _hero_spawn_x(index: int) -> float:
	return HERO_X - index * 70.0

# ---- Buildings ----

func _connect_buildings() -> void:
	portal.setup(GD.BUILDINGS["portal"]["levels"], GD.ENEMIES)
	town_hall.setup(GD.BUILDINGS["town_hall"]["levels"])
	portal.enemy_ready.connect(_on_enemy_ready)
	town_hall.level_cap_changed.connect(_on_level_cap_changed)
	town_hall.clicked.connect(func(): _on_building_clicked("town_hall"))
	portal.clicked.connect(func(): _on_building_clicked("portal"))

# ---- Enemy spawning ----

func _get_enemy_spawn_x() -> float:
	return portal.global_position.x + 120.0

func _on_enemy_ready(enemy_id: String) -> void:
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.position = Vector2(_get_enemy_spawn_x(), GROUND_Y)
	enemies_layer.add_child(enemy)
	enemy.setup(hero_instance, GD.ENEMIES.get(enemy_id, {}))
	enemy.died.connect(_on_enemy_died.bind(enemy))

func _on_enemy_died(gold_amount: int, shard_amount: int, enemy: Node) -> void:
	if not first_kill_done:
		first_kill_done = true
		gold_amount += 50
		shard_amount += 5
	# M004: first Tier 3 enemy kill
	if not first_tier3_kill_done and is_instance_valid(enemy):
		var edata: Dictionary = enemy.get_data() if enemy.has_method("get_data") else {}
		if edata.get("tier", 0) >= 3:
			first_tier3_kill_done = true
			gold_amount += 400
			shard_amount += 40
	add_rewards(gold_amount, shard_amount)
	portal.on_enemy_died()

# ---- Economy ----

func add_rewards(gold_amount: int, shard_amount: int) -> void:
	gold += gold_amount
	shards += shard_amount
	_refresh_hud()
	save_game()

func spend(gold_cost: int, shard_cost: int = 0) -> bool:
	if gold < gold_cost or shards < shard_cost:
		return false
	gold -= gold_cost
	shards -= shard_cost
	_refresh_hud()
	return true

# ---- Building callbacks ----

func _on_level_cap_changed(new_cap: int) -> void:
	hero_instance.max_level = new_cap
	_refresh_hero_card()

func try_upgrade_town_hall() -> void:
	var cost: int = town_hall.next_upgrade_cost()
	if cost < 0 or gold < cost:
		return
	gold = town_hall.upgrade(gold)
	# M002: first TH Lv2 upgrade
	if town_hall.level >= 2 and not first_th2_done:
		first_th2_done = true
		add_rewards(100, 10)
	# Keep shrine th_level in sync
	if is_instance_valid(_shrine_node):
		_shrine_node.th_level = town_hall.level
	_refresh_hud()
	_refresh_empty_slots()
	save_game()

func try_upgrade_portal() -> void:
	var new_gold: int = portal.upgrade(gold)
	if new_gold == gold:
		return
	gold = new_gold
	_refresh_hud()
	save_game()

func try_upgrade_hero(hero_id: String = "H001") -> void:
	var hinst = _hero_instances.get(hero_id)
	if not is_instance_valid(hinst):
		return
	var gc: int = hinst.upgrade_gold_cost()
	var sc: int = hinst.upgrade_shard_cost()
	if not spend(gc, sc):
		return
	hinst.upgrade_level()
	_refresh_hero_card()
	save_game()

# ---- Popup: building info ----

func _on_building_clicked(context: String) -> void:
	_show_building_popup(context)

func _show_building_popup(context: String) -> void:
	var title := ""
	var info := ""
	var upgrade_label := ""
	var can_upgrade := false

	match context:
		"town_hall":
			title = "Town Hall  Lv%d" % town_hall.level
			var cost: int = town_hall.next_upgrade_cost()
			if cost < 0:
				info = "Hero level cap: %d\n(MAX level)" % town_hall.hero_level_cap()
				upgrade_label = "MAX"
			else:
				info = "Hero level cap: %d\nNext cap: %d\nUpgrade cost: %dg" % [
					town_hall.hero_level_cap(), town_hall.next_hero_cap(), cost]
				upgrade_label = "Upgrade  %dg" % cost
				can_upgrade = gold >= cost
		"portal":
			title = "Portal  Lv%d" % portal.level
			var levels: Array = GD.BUILDINGS["portal"]["levels"]
			var at_max: bool = portal.level >= levels.size()
			var tier: int = levels[portal.level - 1]["enemy_tier"] as int
			if at_max:
				info = "Enemy tier: %d\n(MAX level)" % tier
				upgrade_label = "MAX"
			else:
				var next_cost: int = levels[portal.level]["cost"] as int
				var next_tier: int = levels[portal.level]["enemy_tier"] as int
				info = "Enemy tier: %d\nNext tier: %d\nUpgrade cost: %dg" % [tier, next_tier, next_cost]
				upgrade_label = "Upgrade  %dg" % next_cost
				can_upgrade = gold >= next_cost
		"hero":
			_show_building_popup("hero_H001")
			return
		"shrine":
			_show_shrine_popup()
			return
		"tavern":
			title = "Tavern"
			info = "Visitor heroes (Phase 3)"
			upgrade_label = "Coming soon"
		"blacksmith":
			title = "Blacksmith"
			info = "Power bonus (Phase 3)"
			upgrade_label = "Coming soon"
		_:
			if context.begins_with("hero_"):
				var hero_popup_id: String = context.substr(5)
				var hinst = _hero_instances.get(hero_popup_id)
				var hdata: Dictionary = GD.HEROES.get(hero_popup_id, {})
				if not is_instance_valid(hinst) or hdata.is_empty():
					return
				title = "%s  (%s)" % [hdata.get("name", "Hero") as String, (hdata.get("rarity", "") as String).capitalize()]
				var gc: int = hinst.upgrade_gold_cost()
				var sc: int = hinst.upgrade_shard_cost()
				info = "Level: %d / %d\nPower: %d\nUpgrade cost: %dg + %ds" % [
					hinst.level, hinst.max_level, hinst.power(), gc, sc]
				if hinst.level >= hinst.max_level:
					upgrade_label = "At level cap"
				else:
					upgrade_label = "Upgrade  %dg / %ds" % [gc, sc]
					can_upgrade = gold >= gc and shards >= sc
			else:
				return

	building_popup.show_for(context, title, info, upgrade_label, can_upgrade)

func _on_popup_upgrade_requested(context: String) -> void:
	match context:
		"town_hall":
			try_upgrade_town_hall()
		"portal":
			try_upgrade_portal()
		_:
			if context.begins_with("hero_"):
				try_upgrade_hero(context.substr(5))
	_show_building_popup(context)

# ---- Shrine ----

func _show_shrine_popup() -> void:
	if not is_instance_valid(_shrine_node):
		return
	var roll_gold: int = _shrine_node.roll_cost_gold()
	var roll_shard: int = _shrine_node.roll_cost_shard()
	var upgrade_cost: int = _shrine_node.next_upgrade_cost()
	var can_roll: bool = gold >= roll_gold and shards >= roll_shard
	var can_upgrade: bool = upgrade_cost >= 0 and gold >= upgrade_cost
	shrine_popup.show_for(_shrine_node.level, roll_gold, roll_shard, upgrade_cost, can_roll, can_upgrade)

func _on_shrine_roll_requested() -> void:
	if not is_instance_valid(_shrine_node):
		return
	var roll_gold: int = _shrine_node.roll_cost_gold()
	var roll_shard: int = _shrine_node.roll_cost_shard()
	if not spend(roll_gold, roll_shard):
		return
	# M003: first shrine roll bonus
	if not first_shrine_roll_done:
		first_shrine_roll_done = true
		add_rewards(0, 20)
	_shrine_node.roll(discovered_heroes)
	# Refresh button states without clearing the roll result
	var upgrade_cost: int = _shrine_node.next_upgrade_cost()
	var can_roll: bool = gold >= _shrine_node.roll_cost_gold() and shards >= _shrine_node.roll_cost_shard()
	var can_upgrade: bool = upgrade_cost >= 0 and gold >= upgrade_cost
	shrine_popup.refresh_buttons(roll_gold, roll_shard, upgrade_cost, can_roll, can_upgrade)

func _on_shrine_upgrade_requested() -> void:
	if not is_instance_valid(_shrine_node):
		return
	var cost: int = _shrine_node.next_upgrade_cost()
	if cost < 0 or gold < cost:
		return
	gold = _shrine_node.upgrade(gold)
	_refresh_hud()
	save_game()
	_show_shrine_popup()

func _on_shrine_hero_rolled(hero_id: String, is_duplicate: bool, shard_gain: int) -> void:
	if not is_duplicate:
		discovered_heroes.append(hero_id)
		_spawn_hero_by_id(hero_id)
	else:
		add_rewards(0, shard_gain)
	var hdata: Dictionary = GD.HEROES.get(hero_id, {})
	var hero_name: String = hdata.get("name", "Unknown") as String
	var rarity: String = hdata.get("rarity", "common") as String
	shrine_popup.show_result(hero_name, rarity, is_duplicate, shard_gain)
	save_game()

func _refresh_open_popup() -> void:
	if building_popup.visible and building_popup._context != "":
		_show_building_popup(building_popup._context)

# ---- Popup: build menu ----

func _on_slot_clicked(layer: int, col: int) -> void:
	_active_build_layer = layer
	_active_build_col = col

	var options: Array = []
	for btype in GD.BUILDINGS:
		if btype == "town_hall" or btype == "portal":
			continue
		var bdata: Dictionary = GD.BUILDINGS[btype]
		var unlocked: bool = (bdata["unlock_th_level"] as int) <= town_hall.level
		var w: int = bdata["cells_wide"] as int
		var fits: bool = _can_place(layer, col, w)
		if not unlocked or not fits:
			continue  # skip entirely if can't fit; show locked ones that fit
		var cost: int = bdata["build_cost"] as int
		options.append({
			"type": btype,
			"label": bdata["display_name"] as String,
			"cost_label": "%dg" % cost if cost > 0 else "Free",
			"can_afford": gold >= cost,
			"unlocked": unlocked,
		})

	if options.is_empty():
		return
	build_menu_popup.show_options(options, layer, col)

func _on_build_requested(building_type: String) -> void:
	if _active_build_layer < 0:
		return
	var bdata: Dictionary = GD.BUILDINGS.get(building_type, {})
	if bdata.is_empty():
		return
	var cost: int = bdata["build_cost"] as int
	if not spend(cost):
		return
	_place_building(_active_build_layer, _active_build_col, building_type)
	_active_build_layer = -1
	_active_build_col = -1
	_build_mode_active = false
	_refresh_empty_slots()
	save_game()

# ---- HUD & UI ----

func _refresh_hud() -> void:
	gold_label.text = "Gold: %d" % gold
	shard_label.text = "Shards: %d" % shards
	_refresh_hero_card()
	_refresh_open_popup()
	_refresh_overlay_bar()

func _build_ui() -> void:
	# Replace static HBox content with a ScrollContainer for multi-hero list
	var old_hbox := hero_avatar.get_node_or_null("HBox")
	if old_hbox:
		old_hbox.queue_free()
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_avatar.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(vbox)
	# Resize panel to fit more heroes
	hero_avatar.offset_top = -200.0
	var menu_btn: Button = $UI/MenuButton
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	var compact_btn: Button = $UI/CompactButton
	if compact_btn:
		compact_btn.pressed.connect(_on_compact_pressed)
	var expand_btn: Button = $UI/OverlayBar/HBox/ExpandButton
	if expand_btn:
		expand_btn.pressed.connect(_on_expand_pressed)

	var build_btn: Button = $UI/BuildButton
	if build_btn:
		build_btn.pressed.connect(_on_build_btn_pressed)

	building_popup.upgrade_requested.connect(_on_popup_upgrade_requested)
	build_menu_popup.build_requested.connect(_on_build_requested)
	build_menu_popup.popup_hidden.connect(_on_build_menu_closed)
	shrine_popup.roll_requested.connect(_on_shrine_roll_requested)
	shrine_popup.upgrade_requested.connect(_on_shrine_upgrade_requested)

	_refresh_hero_card()

func _on_build_btn_pressed() -> void:
	_build_mode_active = not _build_mode_active
	_refresh_empty_slots()

func _on_build_menu_closed() -> void:
	_build_mode_active = false
	_refresh_empty_slots()

func _on_hero_card_clicked() -> void:
	_show_building_popup("hero")

func _on_menu_pressed() -> void:
	save_game()
	_exit_overlay_mode()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_compact_pressed() -> void:
	_enter_overlay_mode()

func _on_expand_pressed() -> void:
	_exit_overlay_mode()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if building_popup.visible:
			building_popup.hide_popup()
		elif shrine_popup.visible:
			shrine_popup.visible = false
		elif build_menu_popup.visible:
			build_menu_popup.hide_popup()
			_build_mode_active = false
			_refresh_empty_slots()
		elif _build_mode_active:
			_build_mode_active = false
			_refresh_empty_slots()
		elif _overlay_active:
			_exit_overlay_mode()

# ---- Overlay / Compact mode ----

func _enter_overlay_mode() -> void:
	var sw := DisplayServer.screen_get_size().x
	var sh := DisplayServer.screen_get_size().y
	const OVERLAY_H := 120
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(sw, OVERLAY_H))
	DisplayServer.window_set_position(Vector2i(0, sh - OVERLAY_H))
	get_tree().root.transparent_bg = true
	get_tree().root.content_scale_size = Vector2i(sw, OVERLAY_H)
	_enter_overlay_ui()

func _exit_overlay_mode() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	get_tree().root.content_scale_size = Vector2i(1152, 648)
	DisplayServer.window_set_size(Vector2i(1152, 648))
	DisplayServer.window_set_position(Vector2i(
		(DisplayServer.screen_get_size().x - 1152) / 2.0,
		(DisplayServer.screen_get_size().y - 648) / 2.0
	))
	get_tree().root.transparent_bg = false
	_exit_overlay_ui()

func _enter_overlay_ui() -> void:
	_overlay_active = true
	$UI/GoldLabel.visible = false
	$UI/ShardLabel.visible = false
	$UI/HeroAvatar.visible = false
	$UI/MenuButton.visible = false
	$UI/CompactButton.visible = false
	$UI/BuildButton.visible = false
	$UI/OverlayBar.visible = true
	$Background.visible = false
	$Ground.visible = false
	_refresh_overlay_bar()

func _exit_overlay_ui() -> void:
	_overlay_active = false
	$UI/GoldLabel.visible = true
	$UI/ShardLabel.visible = true
	$UI/HeroAvatar.visible = true
	$UI/MenuButton.visible = true
	$UI/CompactButton.visible = true
	$UI/BuildButton.visible = true
	$UI/OverlayBar.visible = false
	$Background.visible = true
	$Ground.visible = true

func _refresh_overlay_bar() -> void:
	if not _overlay_active:
		return
	var bar: Control = $UI/OverlayBar
	if not bar:
		return
	var lbl_gold: Label = bar.get_node_or_null("HBox/GoldLabel")
	var lbl_shards: Label = bar.get_node_or_null("HBox/ShardLabel")
	var lbl_hero: Label = bar.get_node_or_null("HBox/HeroLabel")
	if lbl_gold:
		lbl_gold.text = "Gold: %d" % gold
	if lbl_shards:
		lbl_shards.text = "  Shards: %d" % shards
	if lbl_hero and is_instance_valid(hero_instance):
		lbl_hero.text = "  Hero Lv%d  Power: %d" % [hero_instance.level, hero_instance.power()]

func _refresh_hero_card() -> void:
	# Rebuild hero list dynamically inside HeroAvatar
	var vbox: VBoxContainer = hero_avatar.get_node_or_null("ScrollContainer/VBox")
	if not vbox:
		return
	for child in vbox.get_children():
		child.queue_free()

	for hid in discovered_heroes:
		var inst = _hero_instances.get(hid)
		var hdata: Dictionary = GD.HEROES.get(hid, {})
		var hname: String = hdata.get("name", hid) as String
		var rarity: String = hdata.get("rarity", "common") as String

		var row := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		row.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = "[%s] %s" % [rarity[0].to_upper(), hname]
		name_lbl.add_theme_font_size_override("font_size", 10)
		info_vbox.add_child(name_lbl)

		if is_instance_valid(inst):
			var stat_lbl := Label.new()
			stat_lbl.text = "Lv %d/%d  Pwr:%d" % [inst.level, inst.max_level, inst.power()]
			stat_lbl.add_theme_font_size_override("font_size", 10)
			info_vbox.add_child(stat_lbl)

		var manage_btn := Button.new()
		manage_btn.text = "▶"
		manage_btn.custom_minimum_size = Vector2(28, 0)
		var captured_id := hid
		manage_btn.pressed.connect(func(): _show_building_popup("hero_" + captured_id))
		hbox.add_child(manage_btn)

		vbox.add_child(row)
