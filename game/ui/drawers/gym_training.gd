class_name GymTraining
extends VBoxContainer
## The Gym's training panel inside its build entry: the trainees (portrait, level / XP hint, Recall) and a row of
## benched fighters to send. Dumb view: the drawer pushes state with show_training() and listens to the signals.
## Fighters are dictionaries {id: int, name: String, portrait: Texture2D, detail: String}.

signal assign_requested(id: int)
signal recall_requested(id: int)

@onready var trainees: VBoxContainer = %Trainees
@onready var candidates: HBoxContainer = %Candidates
@onready var hint: Label = %Hint
@onready var _title: Label = %Title
@onready var _send: Control = %Send


## Unbuilt gym: the panel is dimmed and only the hint shows.
func show_training(built: bool, slots: int, trainee_list: Array, candidate_list: Array) -> void:
	for box: Container in [trainees, candidates]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	modulate = Color.WHITE if built else Color(1, 1, 1, 0.55)
	_title.text = "Training %d/%d" % [trainee_list.size(), slots] if built else "Training"
	for fighter: Dictionary in trainee_list:
		trainees.add_child(_trainee_row(fighter))
	var free := built and trainee_list.size() < slots
	_send.visible = free and not candidate_list.is_empty()
	if _send.visible:
		for fighter: Dictionary in candidate_list:
			candidates.add_child(_candidate_button(fighter))
	hint.visible = not _send.visible
	if not built:
		hint.text = "Build the Gym to train benched fighters."
	elif not free:
		hint.text = "" if slots == 0 else "All training slots are busy."
	else:
		hint.text = "No benched fighter to send."


func _portrait(fighter: Dictionary) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = fighter.portrait
	rect.custom_minimum_size = Vector2(32, 32)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 64 px avatars halve exactly
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _trainee_row(fighter: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_portrait(fighter))
	var label := Label.new()
	label.theme_type_variation = &"DarkSmallLabel"
	label.text = "%s  %s" % [fighter.name, fighter.detail]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.clip_text = true
	row.add_child(label)
	var recall := Button.new()
	recall.text = "Recall"
	recall.focus_mode = Control.FOCUS_NONE
	recall.custom_minimum_size = Vector2(72, 36)
	recall.tooltip_text = "Take %s out of training" % fighter.name
	recall.pressed.connect(func() -> void: recall_requested.emit(fighter.id))
	row.add_child(recall)
	return row


func _candidate_button(fighter: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Train %s (%s)" % [fighter.name, fighter.detail]
	var rect := _portrait(fighter)
	rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.add_child(rect)
	button.pressed.connect(func() -> void: assign_requested.emit(fighter.id))
	return button
