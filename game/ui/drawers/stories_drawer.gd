class_name StoriesDrawer
extends Drawer
## Stories screen: the club's stories (ripeness, status, fighters, Main Event set / clear) on the left, the stage
## props shop on the right (icon, effect, price, owned, Buy). Bottom edge like the roster and build drawers.
## `game` / `events` default to the autoloads; tests set them before add_child. Reads game.stories() /
## prop_defs(), writes only set_main_event / clear_main_event / buy_prop, refreshes only from Events.

const STORY := preload("res://game/ui/drawers/story_entry.tscn")
const PROP := preload("res://game/ui/drawers/prop_entry.tscn")
const MAX_WIDTH := 1240.0
const MAX_HEIGHT := 320.0

var game: Node
var events: Node
var story_entries: Array[StoryEntry] = []
var prop_entries := {}  ## prop id -> PropEntry

@onready var empty: Label = %Empty
@onready var _list: VBoxContainer = %List
@onready var _shop: VBoxContainer = %Shop
@onready var _selected: Label = %Selected


func _ready() -> void:
	super._ready()
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	if game == null:
		return
	for def in game.prop_defs():
		var entry := PROP.instantiate() as PropEntry
		_shop.add_child(entry)
		entry.buy_requested.connect(_on_buy)
		prop_entries[def.id] = entry
	if events:
		for signal_name in [&"story_changed", &"story_ripe", &"roster_changed", &"hero_changed", &"prop_changed",
				&"gold_changed", &"planted_changed", &"series_started", &"series_finished"]:
			events.connect(signal_name, _on_event)
	var p := get_parent() as Control
	if p:
		p.resized.connect(_on_parent_resized)
	refresh()


func open() -> void:
	_fit()
	super.open()


func refresh() -> void:
	_refresh_stories()
	_refresh_props()


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _refresh_stories() -> void:
	for entry in story_entries:
		_list.remove_child(entry)
		entry.queue_free()
	story_entries.clear()
	var all: Array = StoryLook.ripe_first(game.stories())
	empty.visible = all.is_empty()
	title = "Stories %d/%d" % [all.size(), game.story_slots()]
	for story: Dictionary in all:
		var portraits: Array[Texture2D] = []
		var names := PackedStringArray()
		for id: int in story.heroes:
			portraits.append(HeroPortraits.portrait(id))
			names.append(game.hero_defs[id].display_name)
		var entry := STORY.instantiate() as StoryEntry
		_list.add_child(entry)
		entry.show_story(story, story.id == game.main_event_id, portraits, names)
		entry.action_requested.connect(_on_story_action)
		story_entries.append(entry)


func _refresh_props() -> void:
	var picked := "none"
	for def in game.prop_defs():
		if def.id == game.selected_prop:
			picked = def.display_name
		var price: int = game.prop_price(def.id)
		prop_entries[def.id].show_prop(def.id, StoryLook.icon_named(def.icon_name), def.display_name, def.description,
				price, game.props_owned(def.id), game.can_afford(price), def.id == game.selected_prop)
	_selected.text = "Selected prop: %s" % picked


func _on_story_action(story_id: int) -> void:
	if story_id == game.main_event_id:
		game.clear_main_event()
	else:
		game.set_main_event(story_id)
	refresh()


func _on_buy(id: StringName) -> void:
	game.buy_prop(id)
	refresh()


func _fit() -> void:
	var ps := _parent_size()
	panel_size = Vector2(minf(MAX_WIDTH, ps.x - 2.0 * margin), minf(MAX_HEIGHT, ps.y - 2.0 * margin))


func _on_parent_resized() -> void:
	if is_open:
		_fit()
		size = panel_size
		_snap()
