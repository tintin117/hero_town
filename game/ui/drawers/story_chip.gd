class_name StoryChip
extends MarginContainer
## One story in the seed tray: kind icon, title, ripeness bar and a ripe mark; selected = gold ring plus a
## "MAIN EVENT x2.4" tag in place of the bar. Cooling (overripe) stories are greyed. Dumb view: `pressed(story_id)`.

signal pressed(story_id: int)

const STAR := preload("res://resources/ui/icons/star.png")

var story_id := -1
var ripe := false

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _tag: Label = %Tag
@onready var _ripe_mark: Badge = %RipeMark
@onready var _ring: Control = $Ring


func show_story(story: Dictionary, selected: bool) -> void:
	story_id = int(story.id)
	ripe = story.ripe
	var ripeness := float(story.ripeness)
	_icon.texture = StoryLook.kind_icon(story.kind)
	_title.text = story.title
	_bar.value = ripeness
	_bar.visible = not selected
	_tag.visible = selected
	_tag.text = "MAIN EVENT %s" % StoryLook.multiplier_text(StoryLook.multiplier(ripeness))
	_ring.visible = selected
	_ripe_mark.icon = STAR if ripe and not selected else null
	_ripe_mark.pulsing = ripe and not selected
	modulate = Color(0.68, 0.7, 0.76) if story.cooling else (Color.WHITE if ripe or selected else Color(0.86, 0.86, 0.9))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ripe else Control.CURSOR_ARROW
	var kind_name: String = StoryLook.KIND_NAMES.get(story.kind, "Story")
	tooltip_text = "%s: %s. %s, ripeness %d/100.%s" % [kind_name, story.title, StoryLook.status(story), int(ripeness),
			"  Tap to clear the Main Event." if selected else "  Tap to make it the Main Event." if ripe else ""]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(story_id)
