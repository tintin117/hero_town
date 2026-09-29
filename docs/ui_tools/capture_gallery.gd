extends SceneTree
## Real-window screenshot of a scene at a given size (NOT headless):
##   godot --path . --resolution 1280x420 --script res://docs/ui_tools/capture_gallery.gd -- w=1280 h=420 [scene=res://game/ui/ui_gallery.tscn] [frames=12] [tag=name] [crop=x,y,w,h zoom=4]
## Writes .godot/captures/<tag or gallery>_<w>x<h>.png. A copy lives in .godot/capture_gallery.gd for the workflow in docs/UI_KIT.md.


func _init() -> void:
	var args := {"w": "1280", "h": "420", "scene": "res://game/ui/ui_gallery.tscn", "frames": "12", "tag": "gallery"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var size := Vector2i(int(args.w), int(args.h))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # project base is 1280x720; show real pixels
	root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(size)
	root.size = size
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	await process_frame
	root.add_child((load(args.scene) as PackedScene).instantiate())
	for i in int(args.frames):
		await process_frame
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/captures"))
	var path := "res://.godot/captures/%s_%dx%d.png" % [args.tag, size.x, size.y]
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	if args.has("crop"):  # crop=x,y,w,h zoom=N -> <tag>_crop.png, nearest-upscaled for inspecting pixels
		var c := (args.crop as String).split(",")
		var part := img.get_region(Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3])))
		var z := int(args.get("zoom", "4"))
		part.resize(part.get_width() * z, part.get_height() * z, Image.INTERPOLATE_NEAREST)
		part.save_png("res://.godot/captures/%s_crop.png" % args.tag)
	quit()
