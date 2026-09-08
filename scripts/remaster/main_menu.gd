extends Control

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i.ZERO
	theme = preload("res://resources/research_theme.tres")
	var background := ColorRect.new()
	background.color = Color("203f49")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title := Label.new()
	title.text = "HERO TOWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f3cf7b"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A little town. An army of possibilities."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var portraits := HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(portraits)
	for unit in ["warrior", "archer", "lancer", "monk"]:
		var picture := TextureRect.new()
		picture.texture = Art.unit_frames(unit).get_frame_texture("idle", 0)
		picture.custom_minimum_size = Vector2(100, 100)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portraits.add_child(picture)
	for entry in [["Continue your town" if not GameState.buildings.is_empty() else "Begin your town", false], ["Play as desktop companion", true]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 52
		button.pressed.connect(func():
			GameState.update_setting("compact", entry[1])
			get_tree().change_scene_to_file("res://scenes/town_2d.tscn"))
		column.add_child(button)
	var info := Label.new()
	info.text = "4 army types · 20 stages · 4 captains\nAutomatic battles, independent research, and offline gold"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	column.add_child(info)
	var quit := Button.new()
	quit.text = "Save and quit"
	quit.pressed.connect(func():
		GameState.request_quit())
	column.add_child(quit)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("ffae90"))
	column.add_child(status)
	GameState.save_failed.connect(func(message): status.text = message)
