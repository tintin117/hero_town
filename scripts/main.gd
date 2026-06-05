extends Node2D

const GD = preload("res://scripts/game_data.gd")
const HeroScene := preload("res://scenes/hero.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")

const GROUND_Y := 500.0
const HERO_X := 700.0
const ENEMY_SPAWN_X := 1050.0
const SAVE_PATH := "user://save.json"

var gold := 50
var shards := 0
var first_kill_done := false
var _overlay_active := false

@onready var heroes_layer: Node2D = $HeroesLayer
@onready var enemies_layer: Node2D = $EnemiesLayer
@onready var gold_label: Label = $UI/GoldLabel
@onready var shard_label: Label = $UI/ShardLabel
@onready var portal: Node2D = $Portal
@onready var town_hall: Node2D = $TownHall
@onready var hero_card: Control = $UI/HeroCard

var hero_instance: CharacterBody2D = null

func _ready() -> void:
	_spawn_hero()
	_connect_buildings()
	_apply_save(load_game())
	_build_ui()
	_refresh_hud()
	# If launched in compact mode, activate overlay immediately
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		_enter_overlay_ui()

# ---- Save / Load ----

func save_game() -> void:
	var data := {
		"gold": gold,
		"shards": shards,
		"first_kill_done": first_kill_done,
		"hero_level": hero_instance.level if is_instance_valid(hero_instance) else 1,
		"town_hall_level": town_hall.level,
		"portal_level": portal.level,
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
	# Restore building levels before hero so level cap is correct
	town_hall.level = data.get("town_hall_level", 1)
	portal.level = data.get("portal_level", 1)
	portal._refresh_enemy_pool()
	town_hall.level_cap_changed.emit(town_hall.hero_level_cap())
	# Restore hero level
	var saved_hero_level: int = data.get("hero_level", 1)
	if is_instance_valid(hero_instance) and saved_hero_level > 1:
		hero_instance.level = saved_hero_level
		hero_instance._apply_stats()
		hero_instance.stats_changed.emit()

# ---- Hero ----

func _spawn_hero() -> void:
	hero_instance = HeroScene.instantiate()
	hero_instance.position = Vector2(HERO_X, GROUND_Y)
	heroes_layer.add_child(hero_instance)
	hero_instance.setup(GD.HEROES["H001"])
	hero_instance.stats_changed.connect(_refresh_hero_card)

func _connect_buildings() -> void:
	portal.setup(GD.BUILDINGS["portal"]["levels"], GD.ENEMIES)
	town_hall.setup(GD.BUILDINGS["town_hall"]["levels"])
	portal.enemy_ready.connect(_on_enemy_ready)
	town_hall.level_cap_changed.connect(_on_level_cap_changed)

# ---- Enemy spawning ----

func _on_enemy_ready(enemy_id: String) -> void:
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.position = Vector2(ENEMY_SPAWN_X, GROUND_Y)
	enemies_layer.add_child(enemy)
	enemy.setup(hero_instance, GD.ENEMIES.get(enemy_id, {}))
	enemy.died.connect(_on_enemy_died.bind(enemy))

func _on_enemy_died(gold_amount: int, shard_amount: int, _enemy: Node) -> void:
	if not first_kill_done:
		first_kill_done = true
		gold_amount += 50
		shard_amount += 5
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
	_refresh_hud()
	_refresh_building_panels()
	save_game()

func try_upgrade_portal() -> void:
	var new_gold: int = portal.upgrade(gold)
	if new_gold == gold:
		return
	gold = new_gold
	_refresh_hud()
	_refresh_building_panels()
	save_game()

func try_upgrade_hero() -> void:
	if not is_instance_valid(hero_instance):
		return
	var gc: int = hero_instance.upgrade_gold_cost()
	var sc: int = hero_instance.upgrade_shard_cost()
	if not spend(gc, sc):
		return
	hero_instance.upgrade_level()
	_refresh_hero_card()
	save_game()

# ---- HUD & UI ----

func _refresh_hud() -> void:
	gold_label.text = "Gold: %d" % gold
	shard_label.text = "Shards: %d" % shards
	_refresh_hero_card()
	_refresh_building_panels()
	_refresh_overlay_bar()

func _build_ui() -> void:
	var th_btn: Button = $UI/TownHallPanel/VBox/UpgradeButton
	if th_btn:
		th_btn.pressed.connect(try_upgrade_town_hall)
	var p_btn: Button = $UI/PortalPanel/VBox/UpgradeButton
	if p_btn:
		p_btn.pressed.connect(try_upgrade_portal)
	var h_btn: Button = $UI/HeroCard/VBox/UpgradeButton
	if h_btn:
		h_btn.pressed.connect(try_upgrade_hero)
	var menu_btn: Button = $UI/MenuButton
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	var compact_btn: Button = $UI/CompactButton
	if compact_btn:
		compact_btn.pressed.connect(_on_compact_pressed)
	var expand_btn: Button = $UI/OverlayBar/HBox/ExpandButton
	if expand_btn:
		expand_btn.pressed.connect(_on_expand_pressed)
	_refresh_hero_card()

func _on_menu_pressed() -> void:
	save_game()
	_exit_overlay_mode()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_compact_pressed() -> void:
	_enter_overlay_mode()

func _on_expand_pressed() -> void:
	_exit_overlay_mode()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlay_active:
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
	# Rescale the viewport to exactly match the overlay window so UI nodes
	# are rendered at actual pixel size (not squished from 648px → 120px)
	get_tree().root.content_scale_size = Vector2i(sw, OVERLAY_H)
	_enter_overlay_ui()

func _exit_overlay_mode() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	# Restore viewport scale to the game's native resolution
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
	$UI/HeroCard.visible = false
	$UI/TownHallPanel.visible = false
	$UI/PortalPanel.visible = false
	$UI/MenuButton.visible = false
	$UI/CompactButton.visible = false
	$UI/OverlayBar.visible = true
	$Background.visible = false
	$Ground.visible = false
	_refresh_overlay_bar()

func _exit_overlay_ui() -> void:
	_overlay_active = false
	$UI/GoldLabel.visible = true
	$UI/ShardLabel.visible = true
	$UI/HeroCard.visible = true
	$UI/TownHallPanel.visible = true
	$UI/PortalPanel.visible = true
	$UI/MenuButton.visible = true
	$UI/CompactButton.visible = true
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
	if not is_instance_valid(hero_instance):
		return
	var name_lbl: Label = hero_card.get_node_or_null("VBox/NameLabel")
	var level_lbl: Label = hero_card.get_node_or_null("VBox/LevelLabel")
	var power_lbl: Label = hero_card.get_node_or_null("VBox/PowerLabel")
	var upgrade_btn: Button = hero_card.get_node_or_null("VBox/UpgradeButton")
	if name_lbl:
		name_lbl.text = "Militia Ratcatcher"
	if level_lbl:
		level_lbl.text = "Lv %d / %d" % [hero_instance.level, hero_instance.max_level]
	if power_lbl:
		power_lbl.text = "Power: %d" % hero_instance.power()
	if upgrade_btn:
		var gc: int = hero_instance.upgrade_gold_cost()
		var sc: int = hero_instance.upgrade_shard_cost()
		upgrade_btn.text = "Upgrade  %dg / %ds" % [gc, sc]
		upgrade_btn.disabled = (
			hero_instance.level >= hero_instance.max_level or
			gold < gc or shards < sc
		)

func _refresh_building_panels() -> void:
	_refresh_th_panel()
	_refresh_portal_panel()

func _refresh_th_panel() -> void:
	var panel: Control = $UI/TownHallPanel
	if not panel:
		return
	var cost: int = town_hall.next_upgrade_cost()
	var info_lbl: Label = panel.get_node_or_null("VBox/InfoLabel")
	var btn: Button = panel.get_node_or_null("VBox/UpgradeButton")
	if info_lbl:
		if cost < 0:
			info_lbl.text = "Town Hall Lv%d (MAX)\nHero cap: %d" % [town_hall.level, town_hall.hero_level_cap()]
		else:
			info_lbl.text = "Town Hall Lv%d\nHero cap: %d\nUpgrade → cap %d\nCost: %dg" % [
				town_hall.level, town_hall.hero_level_cap(),
				town_hall.next_hero_cap(), cost
			]
	if btn:
		btn.text = "Upgrade" if cost >= 0 else "MAX"
		btn.disabled = cost < 0 or gold < cost

func _refresh_portal_panel() -> void:
	var panel: Control = $UI/PortalPanel
	if not panel:
		return
	var tier: int = GD.BUILDINGS["portal"]["levels"][portal.level - 1]["enemy_tier"]
	var levels: Array = GD.BUILDINGS["portal"]["levels"]
	var at_max: bool = portal.level >= levels.size()
	var info_lbl: Label = panel.get_node_or_null("VBox/InfoLabel")
	var btn: Button = panel.get_node_or_null("VBox/UpgradeButton")
	if info_lbl:
		if at_max:
			info_lbl.text = "Portal Lv%d (MAX)\nTier %d enemies" % [portal.level, tier]
		else:
			var next_cost: int = levels[portal.level]["cost"]
			var next_tier: int = levels[portal.level]["enemy_tier"]
			info_lbl.text = "Portal Lv%d\nTier %d enemies\nUpgrade → Tier %d\nCost: %dg" % [
				portal.level, tier, next_tier, next_cost
			]
	if btn:
		btn.text = "Upgrade Portal" if not at_max else "MAX"
		btn.disabled = at_max or (not at_max and gold < (levels[portal.level]["cost"] as int))
