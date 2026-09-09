extends SceneTree

const Companion = preload("res://conquest/companion.tscn")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var c = Companion.instantiate()
	# Tree1 has eight rectangular frames, not six square frames.
	var tree_frames: SpriteFrames = load("res://conquest/units/tree_idle.tres")
	assert(tree_frames.get_frame_count("idle") == 8)
	for index in 8:
		var frame: AtlasTexture = tree_frames.get_frame_texture("idle", index)
		assert(frame.region == Rect2(index * 192, 0, 192, 256))
		assert(frame.atlas.get_size() == Vector2(1536, 256))
	var wood_visual: AnimatedSprite2D = c.get_node("Settlement/WorkingHamlet/WoodSpot/Visual")
	assert(wood_visual.sprite_frames == tree_frames and wood_visual.centered)
	assert(wood_visual.position == Vector2.ZERO and wood_visual.offset == Vector2.ZERO)
	for visual in c.find_children("*", "AnimatedSprite2D", true, false):
		var texture = visual.sprite_frames.get_frame_texture(visual.animation, 0)
		if texture is AtlasTexture and texture.atlas.resource_path.ends_with("Trees/Tree1.png"):
			assert(visual.sprite_frames == tree_frames)
	c.save_path = "user://designer-check-save.json"
	c.seed_from_full_window = false
	DirAccess.remove_absolute(c.save_path)
	# Emulate designer changes before the scene enters the tree.
	var terrain: TileMapLayer = c.get_node("Settlement/Terrain/Ground")
	terrain.erase_cell(Vector2i(10, 0))
	var cells := terrain.get_used_cells()
	var barracks = c.get_node("Settlement/TownDistrict/Barracks")
	barracks.position += Vector2(75, -8)
	var authored_position: Vector2 = barracks.position
	var hamlet = c.get_node("Settlement/WorkingHamlet")
	var extra = load("res://conquest/units/wood_spot.tscn").instantiate()
	extra.name = "DesignerSpot"
	extra.spot_id = "designer_wood"
	extra.position = Vector2(1650, 130)
	extra.gathering = extra.gathering.duplicate()
	extra.gathering.yield_amount = 11
	extra.gathering.cycle_seconds = 2.0
	extra.get_node("Visual").modulate = Color(0.8, 1, 0.8)
	hamlet.add_child(extra)
	var worker = load("res://conquest/units/villager.tscn").instantiate()
	worker.name = "DesignerVillager"
	worker.villager_id = "designer_villager"
	worker.display_name = "Robin"
	worker.initial_spot_id = extra.spot_id
	worker.position = Vector2(1630, 150)
	hamlet.add_child(worker)
	var balance = c.balance.duplicate(true)
	balance.encounters.append(balance.encounters[0].duplicate())
	c.balance = balance
	root.add_child(c)
	await process_frame
	assert(terrain.get_used_cells() == cells)
	assert(barracks.position == authored_position)
	assert(c.game.balance.encounters.size() == 4)
	assert(c.villager_views.size() == 4 and c.resource_spots.size() == 4)
	assert(c.game.s.assignments.designer_villager == "designer_wood")
	c.game.advance_gathering(2)
	assert(c.game.s.wood == 11)
	assert(load("res://conquest/data/wood.tres").yield_amount == 5)
	var academy = c.get_node("Settlement/TownDistrict/Academy")
	c.rebuild_formation()
	assert(c.get_node("Settlement/TownDistrict/Academy") == academy)
	assert(not academy.get_node("Visual").visible and academy.get_node("LockedVisual").visible)
	c.game.s.academy = true
	c.refresh()
	assert(academy.get_node("Visual").visible and not academy.get_node("LockedVisual").visible)
	c.scroll_town(250)
	barracks.get_node("Hit").pressed.emit()
	assert(c.popup_kind == "barracks")
	assert(is_equal_approx(c.popup_anchor, c.settlement.to_local(barracks.get_node("PopupAnchor").global_position).x))
	c.close_panel()
	c.scroll_town(0)
	c.resource_spots.wood_01.get_node("Hit").pressed.emit()
	assert(c.popup_kind == "gathering")
	await process_frame
	await process_frame
	var rows = c.get_node("Popup/Content/Picker/Rows")
	assert(rows.get_child_count() == 4)
	var unassign: Button
	for row in rows.get_children():
		if row.text.begins_with(c.villager_views.woodcutter.display_name + " ·"): unassign = row
		else: assert(row.disabled)
	assert(unassign != null and not unassign.disabled)
	unassign.pressed.emit()
	assert(not c.game.s.assignments.has("woodcutter"))
	# The now-empty spot can take a worker currently assigned elsewhere.
	for row in rows.get_children():
		if row.text.begins_with(c.villager_views.miner.display_name + " ·"): row.pressed.emit(); break
	assert(c.game.s.assignments.miner == "wood_01")
	assert(c.villager_views.miner.destination == c.resource_spots.wood_01)
	c.persist()
	assert(c.get_node("Popup/Content/BodyScroll").get_global_rect().end.y <= c.get_node("Popup/Content/Picker").global_position.y)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/designer-assignment.png")
	c.close_panel()
	c.minimize_to_sparring()
	var food_before: int = c.game.s.food
	c.game.advance(c.game.s.last + 10)
	assert(c.game.s.food > food_before)
	c.restore_town()
	assert(terrain.get_used_cells() == cells)
	root.remove_child(c)
	c.free()
	DirAccess.remove_absolute("user://designer-check-save.json")
	var full = load("res://conquest/conquest.tscn").instantiate()
	full.save_path = "user://designer-full-check-save.json"
	DirAccess.remove_absolute(full.save_path)
	full.balance = balance
	full.game.s.owned = 3
	root.add_child(full)
	await process_frame
	full.deploy()
	assert(full.game.s.owned == 4 and not full.game.s.battle.is_empty())
	full.game.finish_battle()
	full.refresh()
	assert(full.deploy_button.disabled)
	root.remove_child(full)
	full.free()
	DirAccess.remove_absolute("user://designer-full-check-save.json")
	print("DESIGNER SCENE CHECKS PASSED")
	quit()
