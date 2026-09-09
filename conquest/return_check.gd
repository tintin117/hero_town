extends SceneTree
## Replays the recorded, genuinely elapsed departure snapshot; never changes time.
func _initialize() -> void:
	call_deferred("check_return")
func check_return() -> void:
	var record = JSON.parse_string(FileAccess.get_file_as_string("res://conquest/fixtures/return_departure.json"))
	var fixture := "res://conquest/return-check-save.json"
	var f := FileAccess.open(fixture,FileAccess.WRITE)
	f.store_string(JSON.stringify(record.state))
	f.close()
	var scene = load("res://conquest/conquest.tscn").instantiate()
	scene.save_path = fixture
	root.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout
	assert(scene.notice.begins_with("Welcome back"))
	assert(scene.game.s.warriors == record.state.warriors and scene.game.s.healing == record.state.healing)
	assert(scene.game.s.projects.size() == record.state.projects.size())
	for building in record.state.projects:
		var elapsed: float = record.state.projects[building].remaining - scene.game.s.projects[building].remaining
		assert(elapsed >= 0 and elapsed < 3.0)
	assert(scene.game.completed.is_empty())
	print("RETURN SUMMARY CHECK PASSED: ",scene.notice)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://conquest/playtest-return-fixed.png")
	root.remove_child(scene)
	scene.free()
	DirAccess.remove_absolute(fixture)
	quit()
