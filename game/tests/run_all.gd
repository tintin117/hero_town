extends SceneTree
## godot --headless --path . --script res://game/tests/run_all.gd
## Runs every test_*.gd in this folder; each exposes run() -> Array[String] of failure messages.


func _init() -> void:
	await process_frame  # UI tests need a running, ready tree
	var failures := 0
	var dir := DirAccess.open("res://game/tests")
	var files := Array(dir.get_files()).filter(func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var problems: Array = load("res://game/tests/" + file).new().run()
		print("%s %s" % ["PASS" if problems.is_empty() else "FAIL", file])
		for message in problems:
			print("  - ", message)
		failures += problems.size()
	print("%d test file(s), %d failure(s)" % [files.size(), failures])
	quit(1 if failures > 0 else 0)
