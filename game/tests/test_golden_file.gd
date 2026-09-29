extends RefCounted
## Guards the captured prototype numbers that combat_sim is verified against.


func run() -> Array[String]:
	var problems: Array[String] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/tests/golden.json"))
	if not data is Dictionary:
		return ["golden.json missing or invalid"]
	for key in ["fights", "incomes", "stats", "heroes"]:
		if not data.has(key) or data[key].is_empty():
			problems.append("golden.json lacks '%s'" % key)
	if data.get("fights", []).size() != 33:
		problems.append("expected 33 golden fights, found %d" % data.get("fights", []).size())
	if data.get("heroes", []).size() != 8:
		problems.append("expected 8 heroes")
	return problems
