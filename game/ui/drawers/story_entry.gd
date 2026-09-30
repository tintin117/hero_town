class_name StoryEntry
extends PanelContainer
## One story in the stories drawer: kind icon, title, ripeness bar with its status, the fighters' portraits and the
## Main Event button (set / clear). Dumb view: the drawer pushes state with show_story() and listens to `action_requested`.

signal action_requested(story_id: int)

var story_id := -1

@onready var action: Button = %Action
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _status: Label = %Status
@onready var _heroes: HBoxContainer = %Heroes


func _ready() -> void:
	action.pressed.connect(func() -> void: action_requested.emit(story_id))


## `portraits` / `names` are the story's fighters, in order.
func show_story(story: Dictionary, selected: bool, portraits: Array[Texture2D], names: PackedStringArray) -> void:
	story_id = int(story.id)
	var ripeness := float(story.ripeness)
	var kind_name: String = StoryLook.KIND_NAMES.get(story.kind, "Story")
	_icon.texture = StoryLook.kind_icon(story.kind)
	_title.text = story.title
	_bar.value = ripeness
	_status.text = "Main Event %s" % StoryLook.multiplier_text(StoryLook.multiplier(ripeness)) if selected else StoryLook.status(story)
	modulate = Color(0.78, 0.8, 0.86) if story.cooling else Color.WHITE
	tooltip_text = "%s, ripeness %d/100. Cashing it in pays %s." % [kind_name, int(ripeness), StoryLook.multiplier_text(StoryLook.multiplier(ripeness))]
	for child in _heroes.get_children():
		_heroes.remove_child(child)
		child.queue_free()
	for i in portraits.size():
		_heroes.add_child(_portrait(portraits[i], names[i] if i < names.size() else ""))
	action.text = "Clear" if selected else "Main Event"
	action.disabled = not story.ripe and not selected
	action.tooltip_text = "Not ripe yet" if action.disabled else "Set as the next series' Main Event" if not selected else "Back to a normal series"


func _portrait(texture: Texture2D, hero_name: String) -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"Slot"
	frame.tooltip_text = hero_name
	var rect := TextureRect.new()
	var crop := AtlasTexture.new()  # the same crop HeroCard uses for 64 px avatars
	crop.atlas = texture
	crop.region = Rect2(4, 6, 56, 52)
	rect.texture = crop
	rect.custom_minimum_size = Vector2(28, 26)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rect)
	return frame
