extends PanelContainer

signal roll_requested
signal upgrade_requested
signal close_requested

@onready var title_label: Label = $VBox/TitleLabel
@onready var cost_label: Label = $VBox/CostLabel
@onready var result_label: Label = $VBox/ResultLabel
@onready var roll_btn: Button = $VBox/RollButton
@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var close_btn: Button = $VBox/CloseButton

func _ready() -> void:
	roll_btn.pressed.connect(func(): roll_requested.emit())
	upgrade_btn.pressed.connect(func(): upgrade_requested.emit())
	close_btn.pressed.connect(func(): close_requested.emit(); visible = false)
	visible = false

func show_for(shrine_level: int, roll_gold: int, roll_shard: int,
		upgrade_cost: int, can_roll: bool, can_upgrade: bool) -> void:
	title_label.text = "Shrine  Lv%d" % shrine_level
	cost_label.text = "Roll cost: %dg + %ds" % [roll_gold, roll_shard]
	result_label.text = ""
	_refresh_buttons(roll_gold, roll_shard, upgrade_cost, can_roll, can_upgrade)
	visible = true

func refresh_buttons(roll_gold: int, roll_shard: int,
		upgrade_cost: int, can_roll: bool, can_upgrade: bool) -> void:
	cost_label.text = "Roll cost: %dg + %ds" % [roll_gold, roll_shard]
	_refresh_buttons(roll_gold, roll_shard, upgrade_cost, can_roll, can_upgrade)

func _refresh_buttons(_roll_gold: int, _roll_shard: int,
		upgrade_cost: int, can_roll: bool, can_upgrade: bool) -> void:
	roll_btn.disabled = not can_roll
	if upgrade_cost < 0:
		upgrade_btn.text = "MAX"
		upgrade_btn.disabled = true
	else:
		upgrade_btn.text = "Upgrade Shrine  %dg" % upgrade_cost
		upgrade_btn.disabled = not can_upgrade

func show_result(hero_name: String, rarity: String, is_duplicate: bool, shard_gain: int) -> void:
	var rarity_cap := rarity.capitalize()
	if is_duplicate:
		result_label.text = "%s (%s)\nAlready owned! +%d shards" % [hero_name, rarity_cap, shard_gain]
	else:
		result_label.text = "New hero: %s (%s)!" % [hero_name, rarity_cap]
