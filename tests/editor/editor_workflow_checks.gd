extends Node
## Round-trip edited copies through disk before running them: no source asset or player save is changed.

const SCRATCH := "res://.godot/editor_workflow_checks/"
var checks := 0
var failures := 0
var temporary_files: Array[String] = []
var completed_sections: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EDITOR WORKFLOW: " + description)

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("Editor workflow checks require -- --test to protect player saves.")
		get_tree().quit(1)
		return
	GameState.persistence_enabled = false
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	_run.call_deferred()

func _run() -> void:
	_balance_edits()
	await _menu_edits()
	await _companion_edits()
	await _worker_edits()
	await _sparring_edits()
	await _remaster_edits()
	check(completed_sections.size() == 6, "all six workflow sections completed without script errors")
	for path in temporary_files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("EDITOR WORKFLOW CHECKS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _balance_edits() -> void:
	var edited = load("res://data/companion/default_balance.tres").duplicate(true)
	edited.starting_gold = 321.0
	edited.starting_warriors = 5
	edited.first_warrior_cost = 7
	edited.first_warrior_seconds = 2.0
	edited.presentation_seconds = 3.0
	edited.warrior_hp = 60.0
	edited.lands[0].name = "Artist test meadow"
	edited.lands[0].hp = 1.0
	edited.lands[0].attack = 0.0
	var path := SCRATCH + "balance.tres"
	check(ResourceSaver.save(edited, path) == OK, "edited balance resource can be saved")
	temporary_files.append(path)
	var balance = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var rules_script = load("res://game/companion/conquest_state.gd")
	var rules = rules_script.new(balance)
	check(rules.s.gold == 321.0 and rules.s.warriors == 5, "saved balance changes starting state")
	check(rules.start("warriors") and rules.s.gold == 314.0, "saved balance changes charged training cost")
	check(rules.s.projects.barracks.remaining == 2.0, "saved balance changes project duration")
	rules.advance(rules.s.last + 2.1)
	check(rules.s.warriors == 7 and rules.s.projects.is_empty(), "edited training duration reaches the real completion path")
	check(rules.deploy(), "edited encounter can deploy")
	check(rules.s.battle.duration == 3.0 and rules.s.battle.max_hp == 420.0, "edited pacing and warrior HP reach the battle snapshot")
	path = SCRATCH + "balance-battle.json"
	temporary_files.append(path)
	check(rules.save_game(path), "in-flight edited campaign saves")
	# A later balance edit must not rewrite an already saved battle presentation.
	balance.presentation_seconds = 20.0
	balance.warrior_hp = 99.0
	balance.lands[0].name = "Renamed after deployment"
	balance.lands[0].count = 9
	var resumed = rules_script.new(balance)
	resumed.load_game(path)
	check(resumed.s.battle.duration == 3.0 and resumed.s.battle.warrior_hp == 60.0, "saved battle retains original pacing and health after balance changes")
	check(resumed.s.battle.land_name == "Artist test meadow" and resumed.s.battle.enemy_count == 2, "saved battle retains authored encounter identity and count")
	resumed.advance(resumed.s.last + 1.0)
	check(is_equal_approx(resumed.s.battle.remaining, 2.0), "resumed battle advances from its saved remainder")
	resumed.finish_battle()
	check(resumed.s.result.contains("Artist test meadow") and resumed.s.warriors == 7, "battle completion preserves original result identity and army")
	var legacy = rules_script.new()
	legacy.deploy()
	legacy.s.erase("initial_warriors")
	for key in ["duration", "warrior_hp", "land_name", "enemy_count"]: legacy.s.battle.erase(key)
	check(legacy.save_game(path), "legacy in-flight fixture saves")
	balance.lands[0].hp = 5000.0
	var migrated = rules_script.new(balance)
	migrated.load_game(path)
	check(migrated.s.battle.duration == 14.0 and migrated.s.battle.warrior_hp == 40.0, "legacy battle receives its original pacing and health defaults")
	check(migrated.s.battle.enemy_count == 2, "legacy battle enemy count is independent of later encounter HP edits")
	check(migrated.project("warriors").cost == balance.first_warrior_cost, "changing new-game army size preserves the existing campaign's first-training discount")
	completed_sections.append("balance")

func _make_local(node: Node, scene_root: Node) -> void:
	# Equivalent to Make Local for these scratch copies; include edited instanced children.
	node.scene_file_path = ""
	if node != scene_root: node.owner = scene_root
	for child in node.get_children(): _make_local(child, scene_root)

func _save_scene(edited: Node, name: String) -> PackedScene:
	_make_local(edited, edited)
	var packed := PackedScene.new()
	check(packed.pack(edited) == OK, name + " scene can be packed")
	var path := SCRATCH + name + ".tscn"
	check(ResourceSaver.save(packed, path) == OK, name + " scene can be saved")
	temporary_files.append(path)
	edited.free()
	return ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)

func _remove(node: Node) -> void:
	for player in node.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.1).timeout
	node.queue_free()
	await get_tree().process_frame

func _menu_edits() -> void:
	var companion_template = load("res://game/companion/companion.tscn").instantiate()
	companion_template.balance = companion_template.balance.duplicate(true)
	companion_template.balance.starting_gold = 777.0
	companion_template.balance.starting_warriors = 6
	var edited = load("res://game/menu/main_menu.tscn").instantiate()
	edited.companion_scene = _save_scene(companion_template, "menu_companion")
	edited.companion_save_path = SCRATCH + "menu-save.json"
	temporary_files.append(edited.companion_save_path)
	temporary_files.append(edited.companion_save_path + ".previous")
	edited.get_node("MainMenuScene/water").visible = true
	var label: RichTextLabel = edited.get_node("front_ui/Layout/PlayButton/RichTextLabel")
	label.text = "Continue test campaign"
	label.add_theme_font_size_override("normal_font_size", 43)
	var menu = _save_scene(edited, "menu").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	label = menu.get_node("front_ui/Layout/PlayButton/RichTextLabel")
	check(label.text == "Continue test campaign", "menu label edit survives startup")
	check(label.get_theme_font_size("normal_font_size") == 43, "menu font edit survives startup")
	check(menu.get_node("MainMenuScene/water").visible, "menu scene visibility edit survives startup")
	check(menu.create_fresh_save(), "New Game can save the selected companion balance")
	for player in menu.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.1).timeout
	var tree := get_tree()
	tree.current_scene = menu
	menu._open_companion()
	var companion = tree.current_scene
	tree.current_scene = self
	companion.set_process(false)
	check(companion.save_path == SCRATCH + "menu-save.json", "menu routes its custom save path into the launched companion")
	check(companion.game.s.gold == 777.0 and companion.game.s.warriors == 6, "menu New Game loads the selected scene balance into play")
	await _remove(companion)
	completed_sections.append("menu")

func _companion_edits() -> void:
	var edited = load("res://game/companion/companion.tscn").instantiate()
	edited.save_path = SCRATCH + "companion-save.json"
	edited.seed_from_full_window = false
	edited.persistence_enabled = false
	temporary_files.append(edited.save_path)
	var tree: Sprite2D = edited.get_node("Settlement/TownDistrict/WestTree")
	tree.position = Vector2(49, 117)
	tree.scale = Vector2(0.6, 0.6)
	var barracks: Node2D = edited.get_node("Settlement/TownDistrict/BarracksSite")
	barracks.position += Vector2(35, -12)
	var barracks_position := barracks.position
	var training_position: Vector2 = barracks.position + barracks.get_node("Trainee1").position
	edited.get_node("Settlement/TownDistrict/ActorTemplates/Warrior").scale = Vector2(0.72, 0.72)
	var ground: TileMapLayer = edited.get_node("Settlement/Terrain/Ground")
	var erased_cell: Vector2i = ground.get_used_cells()[0]
	ground.erase_cell(erased_cell)
	var worker_child_count: int = edited.get_node("Settlement/WorkingHamlet").get_child_count()
	edited.get_node("HUD/Close").tooltip_text = "Artist-authored close hint"
	var companion = _save_scene(edited, "companion").instantiate()
	get_tree().root.add_child(companion)
	companion.set_process(false)
	await get_tree().process_frame
	tree = companion.get_node("Settlement/TownDistrict/WestTree")
	ground = companion.get_node("Settlement/Terrain/Ground")
	check(tree.position == Vector2(49, 117) and tree.scale == Vector2(0.6, 0.6), "companion scenery transforms survive startup")
	check(ground.get_cell_source_id(erased_cell) == -1, "companion erased terrain cell is not repainted at startup")
	check(companion.get_node("HUD/Close").tooltip_text == "Artist-authored close hint", "companion static control edit survives startup")
	check(companion.workers.get_child_count() == worker_child_count, "companion uses authored workers without duplicate generated sprites")
	check(companion.get_node("Settlement/TownDistrict/BarracksSite").position == barracks_position, "building group movement survives startup")
	check(companion.district.to_local(companion.trainees[0].global_position).is_equal_approx(training_position), "training remains aligned with an edited building group")
	check(companion.formation.get_child(0).scale == Vector2(0.72, 0.72), "companion formation uses the edited warrior template")
	companion.persist()
	check(not FileAccess.file_exists(companion.save_path), "persistence-disabled scene preview creates no campaign save")
	await _remove(companion)
	completed_sections.append("companion")

func _worker_edits() -> void:
	var edited = load("res://game/companion/town_workers.tscn").instantiate()
	var actor: Sprite2D = edited.get_node("Woodcutter")
	actor.position = Vector2(91, 158)
	actor.scale = Vector2(0.7, 0.7)
	var workers = _save_scene(edited, "workers").instantiate()
	get_tree().root.add_child(workers)
	workers.set_process(false)
	workers.clock = 0.0
	workers._process(0.0)
	check(workers.get_node("Woodcutter").position == Vector2(91, 158), "worker loop starts from edited home position")
	workers.clock = 6.0
	workers._process(0.0)
	check(workers.get_node("Woodcutter").position.x > 91.0, "worker delivery moves relative to edited home")
	check(workers.get_node("Woodcutter").scale == Vector2(0.7, 0.7), "worker scale edit survives playback")
	await _remove(workers)
	completed_sections.append("workers")

func _sparring_edits() -> void:
	var edited = load("res://game/companion/taskbar_sparring.tscn").instantiate()
	edited.get_node("Warrior").position = Vector2(52, 63)
	edited.get_node("Warrior").scale = Vector2(0.75, 0.75)
	var sparring = _save_scene(edited, "sparring").instantiate()
	get_tree().root.add_child(sparring)
	sparring.set_process(false)
	sparring.clock = 0.0
	sparring._process(0.0)
	check(sparring.get_node("Warrior").position == Vector2(52, 63), "sparring uses edited pose origin")
	check(sparring.get_node("Warrior").scale == Vector2(0.75, 0.75), "sparring preserves edited scale")
	await _remove(sparring)
	completed_sections.append("sparring")

func _remaster_edits() -> void:
	GameState.settings.compact = false
	GameState.settings.landscape = 0
	GameState.set_reorganizing(true)
	GameState.gold = 1000
	check(GameState.place_building("barracks", Vector2i(4, 1)).ok, "remaster fixture creates a real army")
	var frames: SpriteFrames = load("res://resources/art/warrior_blue.tres").duplicate(true)
	frames.set_animation_speed("idle", 3.5)
	var frames_path := SCRATCH + "frames.tres"
	check(ResourceSaver.save(frames, frames_path) == OK, "edited animation resource can be saved")
	temporary_files.append(frames_path)
	var unit_template = load("res://game/town/unit_view.tscn").instantiate()
	unit_template.sprite_frames_override = ResourceLoader.load(frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE)
	unit_template.get_node("Sprite").scale = Vector2(0.67, 0.67)
	unit_template.get_node("Sprite").modulate = Color(0.7, 0.9, 0.8, 1.0)
	unit_template.get_node("Sprite").rotation = 0.2
	var building_template = load("res://game/town/town_building.tscn").instantiate()
	building_template.get_node("Sprite").scale = Vector2(0.44, 0.44)
	building_template.spawn_seconds = 0.0
	building_template.texture_override = GameData.BUILDINGS.mage_tower.sprite_texture
	var edited = load("res://game/town/town.tscn").instantiate()
	edited.music.autoplay = false
	edited.unit_scene = _save_scene(unit_template, "unit")
	edited.building_scene = _save_scene(building_template, "building")
	edited.fit_camera_to_window = false
	edited.camera.position = Vector2(77, -22)
	edited.camera.zoom = Vector2(1.23, 1.23)
	var castle: Sprite2D = edited.get_node("Scenery/Meadow/Castle1")
	castle.position = Vector2(-525, -10)
	castle.scale = Vector2(0.51, 0.51)
	var ground: TileMapLayer = edited.get_node("Scenery/Meadow/Terrain")
	var erased_cell: Vector2i = ground.get_used_cells()[0]
	ground.erase_cell(erased_cell)
	edited.hud.get_node("Toolbar/Buttons/Build").text = "Construct test"
	edited.hud.get_node("Toolbar/Buttons/Build").add_theme_font_size_override("font_size", 19)
	var town = _save_scene(edited, "town").instantiate()
	get_tree().root.add_child(town)
	town.director.set_physics_process(false)
	await get_tree().process_frame
	check(town.camera.position == Vector2(77, -22) and town.camera.zoom == Vector2(1.23, 1.23), "manual camera edits survive when automatic fitting is disabled")
	check(town.get_node("Scenery/Meadow/Castle1").position == Vector2(-525, -10), "remaster scenery position survives startup")
	check(town.get_node("Scenery/Meadow/Terrain").get_cell_source_id(erased_cell) == -1, "remaster erased tile remains erased")
	GameState.update_setting("landscape", 1)
	GameState.update_setting("landscape", 0)
	check(town.get_node("Scenery/Meadow/Castle1").scale == Vector2(0.51, 0.51), "landscape switching preserves authored prop overrides")
	check(town.get_node("Scenery/Meadow/Terrain").get_cell_source_id(erased_cell) == -1, "landscape switching does not regenerate terrain")
	check(town.hud.get_node("Toolbar/Buttons/Build").text == "Construct test", "remaster static button text survives startup")
	check(town.hud.get_node("Toolbar/Buttons/Build").get_theme_font_size("font_size") == 19, "remaster per-control font override survives responsive layout")
	check(town.building_views.size() == 1 and town.unit_views.size() == 3, "authored templates preserve the state-driven building and army counts")
	var building = town.building_views.values()[0]
	check(building.sprite.scale == Vector2(0.44, 0.44), "runtime building instance uses edited scene scale")
	check(building.sprite.texture == GameData.BUILDINGS.mage_tower.sprite_texture, "runtime building instance uses texture override")
	var unit = town.unit_views.values()[0]
	check(unit.sprite.scale == Vector2(0.67, 0.67), "runtime soldier instance uses edited scene scale")
	check(unit.sprite.sprite_frames.get_animation_speed("idle") == 3.5, "runtime soldier uses the saved animation resource override")
	unit.update_view(0.1, 0.0)
	check(unit.sprite.modulate.is_equal_approx(Color(0.7, 0.9, 0.8, 1.0)) and is_equal_approx(unit.sprite.rotation, 0.2), "soldier playback preserves authored tint and rotation")
	await _remove(town)
	completed_sections.append("remaster")
