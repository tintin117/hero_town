extends Drawer
## The seed tray: every owned hero as a card; click to pick or drop them for the next series. It slides
## up by itself when nothing is planted and tucks away once a lineup is planted (the HUD decides when).
## `game` / `events` default to the autoloads; tests set them before add_child.

const CARD := preload("res://game/ui/components/hero_card.tscn")

var game: Node
var events: Node

@onready var cards: HBoxContainer = %Cards
@onready var hint: Label = %Hint


func _ready() -> void:
	super()
	$Column/Header.visible = false  # compact: tap the arena or press ESC to tuck it away
	game = game if game else get_node_or_null("/root/Game")
	events = events if events else get_node_or_null("/root/Events")
	for signal_name in [&"roster_changed", &"hero_changed"]:
		events.get(signal_name).connect(_on_event)
	refresh()


func _on_event(_a: Variant = null) -> void:
	refresh()


func refresh() -> void:
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
		card.pressed.connect(game.toggle_lineup.bind(id))
		cards.add_child(card)
		var hp: int = Roster.stats_for(game.hero_defs[id], game.state.heroes[id].level, game.tuning).health
		card.set_hp(hp, hp)
	var capacity: int = Roster.fighter_capacity(game.state, game.tuning)
	hint.text = "Picked %d/%d - now hold the arena to plant" % [picked.size(), capacity] \
			if picked.size() >= game.tuning.min_lineup else "Pick at least %d fighters (%d/%d)" % [game.tuning.min_lineup, picked.size(), capacity]
