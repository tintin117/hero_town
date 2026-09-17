extends RefCounted
## One physical width for the menu and companion, fitted to the monitor.
const PREFERRED_WIDTH := 1280
const SCREEN_MARGIN := 32

static func width_for_area(area: Vector2i) -> int:
	return maxi(1, mini(PREFERRED_WIDTH, mini(area.x - SCREEN_MARGIN, floori((area.y - SCREEN_MARGIN) * 16.0 / 9.0))))

static func window_width(window: Window) -> int:
	if DisplayServer.get_name() == "headless": return PREFERRED_WIDTH
	return width_for_area(DisplayServer.screen_get_usable_rect(window.current_screen).size)
