extends PanelContainer

## Presentation only. These signals are integration points for future game logic.
## The panel never spends currency, mutates BuildingBase, or spawns heroes.
signal close_requested
signal class_selected(building_id: String)
signal move_requested(building: BuildingBase)
signal training_previewed(building_id: String, node_data: Dictionary)
signal upgrade_previewed(building_id: String, rarity: int)
signal hero_choice_previewed(building_id: String, rarity: int, candidate_index: int)

const CLASS_IDS := ["barracks", "cleric_hall", "mage_tower", "rogue_den"]
const CLASS_NAMES := ["Warrior", "Cleric", "Mage", "Rogue"]
const CANDIDATES := {
	0: [["Guard", "Defense"], ["Raider", "Attack"], ["Lancer", "HP"]],
	3: [["Priest", "Healing"], ["Warden", "Defense"], ["Oracle", "Skill"]],
	2: [["Pyromancer", "Attack"], ["Arcanist", "Skill"], ["Frostweaver", "Defense"]],
	1: [["Assassin", "Attack"], ["Duelist", "Agility"], ["Scout", "HP"]],
}

@onready var tree = $Layout/HeroContent/Scroll/Tree
@onready var detail_title: Label = $Layout/HeroContent/Detail/VBox/Title
@onready var detail_description: Label = $Layout/HeroContent/Detail/VBox/Description
@onready var action: Button = $Layout/HeroContent/Detail/VBox/Action
@onready var status: Label = $Layout/Status
@onready var choice_overlay: ColorRect = $ChoiceOverlay
@onready var cards: HBoxContainer = $ChoiceOverlay/Center/Frame/Content/Cards

var building: BuildingBase
var _selected: Dictionary = {}
var _preview_level: int = 1
var _preview_trained: Dictionary = {}
var _pending_tier: int = 1

func _ready() -> void:
	$Layout/Header/Close.pressed.connect(func(): close_requested.emit())
	$Layout/Tabs/Hero.pressed.connect(_set_tab.bind(false))
	$Layout/Tabs/Manage.pressed.connect(_set_tab.bind(true))
	for index in CLASS_IDS.size():
		$Layout/Classes.get_child(index).pressed.connect(func(): class_selected.emit(CLASS_IDS[index]))
	tree.node_selected.connect(_select_node)
	action.pressed.connect(_preview_action)
	$Layout/ManageContent/Upgrade.pressed.connect(_preview_next_upgrade)
	$Layout/ManageContent/Move.pressed.connect(func():
		if is_instance_valid(building):
			move_requested.emit(building))
	$Layout/ManageContent/Reset.pressed.connect(func():
		if is_instance_valid(building):
			open(building))
	$ChoiceOverlay/Center/Frame/Content/Cancel.pressed.connect(func(): choice_overlay.hide())
	# Keep standalone F6 preview useful without requiring a game singleton.
	_set_tab(false)

func open(target: BuildingBase) -> void:
	building = target
	var data := building.get_data()
	var class_index := CLASS_IDS.find(data.id)
	$Layout/Header/Title.text = "%s Research" % CLASS_NAMES[maxi(class_index, 0)]
	for index in CLASS_IDS.size():
		$Layout/Classes.get_child(index).set_pressed_no_signal(index == class_index)
	_preview_level = clampi(building.current_level, 1, 5)
	_preview_trained.clear()
	_selected.clear()
	tree.hero_class = data.hero_class
	tree.preview_level = _preview_level
	tree.selected_key = ""
	tree.rebuild()
	$Layout/HeroContent/Scroll.scroll_vertical = 0
	$Layout/ManageContent/Portrait.texture = data.sprite_texture
	$Layout/ManageContent/Name.text = data.display_name
	_update_manage()
	detail_title.text = "Select a research node"
	detail_description.text = "Each rarity has its own stat branches.\nScroll down to inspect later tiers."
	action.text = "Select a node"
	action.disabled = true
	status.text = "Preview only. No currency or hero stats change."
	choice_overlay.hide()
	_set_tab(false)

func _set_tab(manage: bool) -> void:
	$Layout/HeroContent.visible = not manage
	$Layout/ManageContent.visible = manage
	$Layout/Tabs/Hero.set_pressed_no_signal(not manage)
	$Layout/Tabs/Manage.set_pressed_no_signal(manage)

func _select_node(data: Dictionary) -> void:
	_selected = data
	detail_title.text = data.title
	detail_title.modulate = tree.COLORS[data.tier]
	detail_description.text = data.description
	var tier: int = data.tier
	if data.kind == "building":
		if tier < _preview_level:
			action.text = "Current / unlocked tier"
			action.disabled = true
		elif tier == _preview_level:
			action.text = "Preview upgrade — choose 1 of 3"
			action.disabled = false
		else:
			action.text = "Requires building Lv %d" % tier
			action.disabled = true
	else:
		action.disabled = tier >= _preview_level or _preview_trained.has(data.key)
		action.text = "Requires building Lv %d" % (tier + 1) if tier >= _preview_level else ("Previewed" if _preview_trained.has(data.key) else "Preview training")

func _preview_action() -> void:
	if _selected.is_empty() or not is_instance_valid(building):
		return
	if _selected.kind == "building":
		_preview_next_upgrade()
	else:
		_preview_trained[_selected.key] = true
		training_previewed.emit(building.building_id, _selected.duplicate())
		status.text = "Preview: %s selected. No stats changed." % _selected.title
		_select_node(_selected)

func _preview_next_upgrade() -> void:
	if not is_instance_valid(building) or _preview_level >= 5:
		return
	_pending_tier = _preview_level
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var data := building.get_data()
	var candidates: Array = CANDIDATES[data.hero_class]
	var portrait: Texture2D = Art.hero_sprite_frames(data.hero_class).get_frame_texture("idle", 0)
	for index in 3:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(124, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		var picture := TextureRect.new()
		picture.texture = portrait
		picture.custom_minimum_size = Vector2(0, 84)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(picture)
		card.add_child(_card_label(candidates[index][0], Color("f1ead9")))
		card.add_child(_card_label(tree.RARITIES[_pending_tier], tree.COLORS[_pending_tier]))
		card.add_child(_card_label(candidates[index][1], Color("c4b28f")))
		var choose := Button.new()
		choose.text = "Choose"
		choose.pressed.connect(_choose_candidate.bind(index))
		card.add_child(choose)
	$ChoiceOverlay/Center/Frame/Content/Title.text = "%s UNLOCKED" % tree.RARITIES[_pending_tier].to_upper()
	$ChoiceOverlay/Center/Frame/Content/Title.modulate = tree.COLORS[_pending_tier]
	upgrade_previewed.emit(building.building_id, _pending_tier)
	choice_overlay.show()

func _card_label(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	return label

func _choose_candidate(index: int) -> void:
	if not is_instance_valid(building):
		return
	var candidates: Array = CANDIDATES[building.get_data().hero_class]
	_preview_level = _pending_tier + 1
	tree.preview_level = _preview_level
	tree.rebuild()
	choice_overlay.hide()
	_update_manage()
	hero_choice_previewed.emit(building.building_id, _pending_tier, index)
	status.text = "Preview: %s chosen. No hero recruited." % candidates[index][0]
	if not _selected.is_empty():
		_select_node(_selected)

func _update_manage() -> void:
	$Layout/ManageContent/Summary.text = "Actual building: Lv %d\nPreview: Lv %d / %s\n\nUpgrade -> unlock a rarity -> choose 1 of 3.\nStats, costs and rolls will be connected later." % [building.current_level, _preview_level, tree.RARITIES[_preview_level - 1]]
	$Layout/ManageContent/Upgrade.disabled = _preview_level >= 5
	$Layout/ManageContent/Upgrade.text = "All tiers previewed" if _preview_level >= 5 else "Preview next upgrade"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if choice_overlay.visible:
			choice_overlay.hide()
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()
