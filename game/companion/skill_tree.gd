extends Control
## Authored node positions and pack icons; this script only reflects research state.
signal purchase_requested(action: String, hero: String, upgrade: String)
var game: FarmFightState
var selected_class := "warrior"
var selected_skill := "power"
var buttons: Array[Button] = []

func _ready() -> void:
	$Graph/Connections.draw.connect(draw_connections)
	for button in $Graph.find_children("*", "Button", true, false):
		buttons.append(button)
		button.pressed.connect(func(): select_skill(button.get_meta("class"), button.get_meta("skill")))
	$Detail/Buy.pressed.connect(func():
		purchase_requested.emit("unlock" if selected_skill == "unlock" else "upgrade", selected_class, "" if selected_skill == "unlock" else selected_skill))

func select_skill(hero: String, skill: String) -> void:
	selected_class = hero
	selected_skill = skill
	refresh()

func refresh() -> void:
	if game == null: return
	for button in buttons:
		var id: String = button.get_meta("class")
		var skill: String = button.get_meta("skill")
		var unlocked: bool = game.s.research[id].unlocked
		var bought: bool = unlocked if skill == "unlock" else int(game.s.research[id][skill]) > 0
		button.modulate = Color("c4efbb") if bought else (Color.WHITE if unlocked or skill == "unlock" else Color("8d9396"))
		button.get_node("Rank").text = id.capitalize() if skill == "unlock" else "%s %d" % [skill.capitalize(), game.s.research[id][skill]]
		button.tooltip_text = id.capitalize() + " • " + ("Unlock branch" if skill == "unlock" else skill.capitalize())
		# Locked nodes stay selectable so the player can inspect their requirement.
	var data := game.balance.hero(selected_class)
	var action := "unlock" if selected_skill == "unlock" else "upgrade"
	var rank := 0 if selected_skill == "unlock" else int(game.s.research[selected_class][selected_skill])
	$Detail/Title.text = selected_class.capitalize() + (" branch" if selected_skill == "unlock" else " • " + selected_skill.capitalize())
	$Detail/Level.text = ("Branch unlocked" if game.s.research[selected_class].unlocked else "New hero class") if selected_skill == "unlock" else "Level %d → %d" % [rank, rank + 1]
	match selected_skill:
		"unlock":
			$Detail/Effect.text = "Unlocks the %s tower" % data.title
			$Detail/Description.text = data.description + "\nBuild its tower at the frontier to begin passive spawning."
		"power", "health":
			var base: float = data.power if selected_skill == "power" else data.health
			$Detail/Effect.text = "%.1f → %.1f %s" % [base * (1.0 + rank * game.balance.stat_per_rank), base * (1.0 + (rank + 1) * game.balance.stat_per_rank), "power" if selected_skill == "power" else "HP"]
			$Detail/Description.text = "Strengthens all living and future %s heroes.\nEach level adds %d%% of the base stat." % [data.title, roundi(game.balance.stat_per_rank * 100)]
		"spawn":
			$Detail/Effect.text = "%.1fs → %.1fs per hero" % [game.spawn_seconds(selected_class), maxf(game.balance.minimum_spawn_seconds, data.spawn_seconds / (1.0 + (rank + 1) * game.balance.spawn_per_rank))]
			$Detail/Description.text = "Trains heroes faster at this tower.\nPassive spawning is free. Paid reinforcements keep their own cooldown."
	var price := game.quote(action, selected_class, selected_skill)
	$Detail/Buy.text = ("Unlock" if action == "unlock" else "Upgrade") + " • %dg" % price.gold + (" + %dw" % price.wood if price.wood else "")
	var error := game.action_error(action, selected_class, selected_skill)
	$Detail/Buy.disabled = not error.is_empty()
	$Detail/Hint.text = error if not error.is_empty() else "Choose your investment. Every branch remains available."
	$Graph/Connections.queue_redraw()

func draw_connections() -> void:
	if game == null: return
	var canvas: Control = $Graph/Connections
	var root_center: Vector2 = $Graph/Root.position + $Graph/Root.size / 2 - canvas.position
	for id in FarmFightState.CLASSES:
		var branch := $Graph.get_node(id.capitalize())
		var unlock: Button = branch.get_node("Unlock")
		var center: Vector2 = branch.position + unlock.position + unlock.size / 2 - canvas.position
		var color := Color("a6dbb1") if game.s.research[id].unlocked else Color("796957")
		canvas.draw_line(root_center, center, color, 3.0)
		for skill in FarmFightState.UPGRADES:
			var child: Button = branch.get_node(skill.capitalize())
			canvas.draw_line(center, branch.position + child.position + child.size / 2 - canvas.position, color, 2.0)
	var selected: Button = $Graph.get_node(selected_class.capitalize() + "/" + selected_skill.capitalize())
	canvas.draw_rect(Rect2(selected.position + selected.get_parent().position - canvas.position, selected.size).grow(3), Color("fff0a1"), false, 2.0)
