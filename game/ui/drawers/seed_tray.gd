class_name SeedTray
extends Drawer
## The seed tray: every owned hero as a card (with trait chips); tap to pick or drop them for the next series. Under
## the cards one compact row: story chips (tap a ripe one to make it the Main Event, tap again to clear), the live
## star / gold preview of the picked lineup, and the four stage props (tap an owned one to use it in the next series).
## It slides up when nothing is planted and tucks away once a lineup is planted (the HUD decides when).
## `game` / `events` default to the autoloads; tests set them before add_child. Refreshes only from Events.

const CARD := preload("res://game/ui/components/hero_card.tscn")
const CHIP := preload("res://game/ui/drawers/story_chip.tscn")
const PROP := preload("res://game/ui/drawers/prop_button.tscn")
const MAX_WIDTH := 1240.0
const HEIGHT := 160.0  ## the content decides (~169, +10 when the cards need a scrollbar)

var game: Node
var events: Node

@onready var cards: HBoxContainer = %Cards
@onready var chips: HBoxContainer = %Chips
@onready var stars: StarRating = %Stars
@onready var props: HBoxContainer = %Props
@onready var _no_stories: Label = %NoStories
@onready var _preview_text: Label = %PreviewText


func _ready() -> void:
	super()
	$Column/Header.visible = false  # compact: tap the arena or press ESC to tuck it away
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	for signal_name in [&"roster_changed", &"hero_changed", &"story_changed", &"prop_changed", &"gold_changed",
			&"planted_changed", &"manager_changed"]:
		events.get(signal_name).connect(_on_event)
	var p := get_parent() as Control
	if p:
		p.resized.connect(_on_parent_resized)
	refresh()


func open() -> void:
	_fit()
	super.open()
	get_tree().process_frame.connect(_tighten, CONNECT_ONE_SHOT)


## The first layout pass reserves a scrollbar's height that the real width does not need: shrink to the content.
func _tighten() -> void:
	if is_open and size.y > panel_size.y:
		size = panel_size
		_slide(_rest(), true)


func refresh() -> void:
	_refresh_cards()
	_refresh_stories()
	_refresh_preview()
	_refresh_props()


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _refresh_cards() -> void:
	for card in cards.get_children():
		cards.remove_child(card)
		card.queue_free()
	var picked: Array[int] = game.state.preferred_lineup
	for id in game.state.heroes.size():
		if not game.state.heroes[id].owned:
			continue
		var card := CARD.instantiate() as HeroCard
		card.portrait = HeroPortraits.portrait(id)
		card.hero_name = game.hero_defs[id].display_name
		card.level = game.state.heroes[id].level
		card.selected = id in picked
		card.pressed.connect(_on_card.bind(id))
		cards.add_child(card)
		var hp: int = Roster.stats_for(game.hero_defs[id], game.state.heroes[id].level, game.tuning).health
		card.set_hp(hp, hp)
		var icons: Array[Texture2D] = []
		var tips := PackedStringArray()
		for hero_trait in game.hero_traits(id):
			icons.append(StoryLook.icon_named(hero_trait.icon_name))
			tips.append(StoryLook.trait_tip(hero_trait.display_name, hero_trait.description))
		card.set_traits(icons, tips)


func _refresh_stories() -> void:
	for chip in chips.get_children():
		if chip is StoryChip:
			chips.remove_child(chip)
			chip.queue_free()
	var shown := StoryLook.ripe_first(game.stories()).slice(0, game.story_slots())
	_no_stories.visible = shown.is_empty()
	for story: Dictionary in shown:
		var chip := CHIP.instantiate() as StoryChip
		chips.add_child(chip)
		chip.show_story(story, story.id == game.main_event_id)
		chip.pressed.connect(_on_chip)


func _refresh_preview() -> void:
	var preview: Dictionary = game.preview(game.state.preferred_lineup, {"main_event": game.main_event_id})
	var lo := float(preview.stars_min)
	var hi := float(preview.stars_max)
	stars.set_range(lo, hi)
	if hi <= 0.0:
		_preview_text.text = "Pick %d+ fighters" % game.tuning.min_lineup
		return
	var gold_lo := StatPill._fmt(int(preview.income_min))
	var gold_hi := StatPill._fmt(int(preview.income_max))
	_preview_text.text = "~%s gold per bout" % (gold_lo if gold_lo == gold_hi else "%s-%s" % [gold_lo, gold_hi])


func _refresh_props() -> void:
	for prop in props.get_children():
		props.remove_child(prop)
		prop.queue_free()
	for def in game.prop_defs():
		var owned: int = game.props_owned(def.id)
		var button := PROP.instantiate() as PropButton
		props.add_child(button)
		var tip := "%s: %s\n" % [def.display_name, def.description]
		tip += "Owned: %d. Tap to use it in the next series." % owned if owned > 0 \
				else "Not owned. Buy it for %s gold in the Stories drawer." % StatPill._fmt(game.prop_price(def.id))
		button.show_prop(def.id, StoryLook.icon_named(def.icon_name), tip, owned, game.prop_price(def.id), game.selected_prop == def.id)
		button.pressed.connect(_on_prop)


func _on_card(id: int) -> void:
	game.toggle_lineup(id)


## The game refuses an unripe story, so only the toggle lives here.
func _on_chip(story_id: int) -> void:
	if story_id == game.main_event_id:
		game.clear_main_event()
	else:
		game.set_main_event(story_id)
	refresh()


func _on_prop(id: StringName) -> void:
	game.select_prop(&"" if game.selected_prop == id else id)
	refresh()


func _fit() -> void:
	var ps := _parent_size()
	panel_size = Vector2(minf(MAX_WIDTH, ps.x - 2.0 * margin), HEIGHT)


func _on_parent_resized() -> void:
	if is_open:
		_fit()
		size = panel_size
		_snap()
