class_name RosterEntry
extends VBoxContainer
## One hero in the roster drawer: HeroCard + XP/wins (owned) or a recruit CostButton (for sale) + skill name.
## Dumb view: the drawer pushes state with show_hero() and listens to `picked` / `recruit_requested`.

signal picked(id: int)  ## an owned hero was clicked (lineup toggle)
signal recruit_requested(id: int)

var hero_id := -1
var owned := false

@onready var card: HeroCard = $Stack/Card
@onready var slot: Badge = $Stack/Overlay/Slot
@onready var buy: CostButton = $Action/Buy
@onready var _progress: Control = $Action/Progress
@onready var _xp: ProgressBar = $Action/Progress/Xp
@onready var _stats: Label = $Action/Progress/Stats
@onready var _skill: Label = $Stack/Card/Card/Row/Info/Skill  # the scene swaps the card's HP/mana bars for it


func _ready() -> void:
	card.pressed.connect(func() -> void:
		if owned:
			picked.emit(hero_id))
	buy.pressed.connect(func() -> void: recruit_requested.emit(hero_id))


## `xp_needed` is 0 at the level cap. `lineup_slot` is 1-based, 0 = not in the lineup. `hall_full`: the
## Recruitment Hall has no room, so recruiting is off whatever the gold.
func show_hero(def: HeroDef, hero: HeroState, xp_needed: int, lineup_slot: int, affordable: bool, hall_full := false) -> void:
	hero_id = def.id
	owned = hero.owned
	card.portrait = HeroPortraits.portrait(def.id)
	card.hero_name = def.display_name
	card.level = hero.level
	card.selected = lineup_slot > 0
	card.disabled = not owned and not affordable  # dimmed + lock: can't be bought yet
	slot.count = lineup_slot
	_progress.visible = owned
	buy.visible = not owned
	buy.cost = def.price
	buy.unaffordable = not affordable
	hall_full = hall_full and not owned
	buy.disabled = buy.disabled or hall_full
	buy.tooltip_text = "Recruitment Hall full - upgrade it" if hall_full else ""
	var maxed := xp_needed == 0
	_xp.max_value = 1.0 if maxed else xp_needed
	_xp.value = _xp.max_value if maxed else hero.xp
	_stats.text = "%s   %d wins" % ["MAX" if maxed else "XP %d/%d" % [hero.xp, xp_needed], hero.wins]
	_skill.text = def.skill.name
	var tip := "%s: %s" % [def.skill.name, def.skill.description]
	card.tooltip_text = tip
