extends RefCounted
## Desktop strip: docking rect and the town sitting on the bottom edge.

var problems: Array[String] = []


func run() -> Array[String]:
	problems.clear()
	var usable := Rect2i(0, 0, 1920, 1040)  # 1080p minus a 40 px taskbar
	_expect(DesktopStrip.strip_rect(usable, 1536, 420, false) == Rect2i(192, 620, 1536, 420), "bottom dock sits on the taskbar, centred")
	_expect(DesktopStrip.strip_rect(usable, 1536, 52, true) == Rect2i(192, 0, 1536, 52), "top dock, collapsed to the bar")
	_expect(DesktopStrip.strip_rect(Rect2i(100, 0, 1280, 984), 1536, 420, false) == Rect2i(100, 564, 1280, 420), "narrow screen: full width")

	var host := Control.new()
	host.size = Vector2(1536, 368)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var town := (load("res://game/town/town.tscn") as PackedScene).instantiate() as Control
	host.add_child(town)
	town.align_bottom = true
	_expect(town.world.position.y == 368.0 - 256.0, "align_bottom puts the town on the bottom edge, got %s" % town.world.position.y)
	host.free()
	return problems


func _expect(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)
