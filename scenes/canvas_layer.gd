extends CanvasLayer


@onready var building_popup = $BuildingPopup
@onready var build_menu_popup = $BuildMenuPopup
@onready var placement_controller = $"../PlacementController"
@onready var currency_label: Label = $CurrencyLabel

func _ready() -> void:
	$"../BuildingBase".clicked.connect(_on_building_clicked)
	build_menu_popup.build_requested.connect(_on_build_requested)
	GameState.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(GameState.gold, GameState.shard)

func _on_building_clicked() -> void:
	building_popup.open()

func _on_placement_button_pressed() -> void:
	var options: Array = []
	for data in GameData.BUILDINGS.values():
		if data.build_cost <= 0:
			continue
		options.append({
			"type": data.id,
			"label": data.display_name,
			"cost": data.build_cost,
			"can_afford": GameState.can_afford(data.build_cost),
			"thumbnail": data.thumbnail,
		})
	build_menu_popup.show_options(options)

func _on_build_requested(building_type: String) -> void:
	placement_controller.start_placement(GameData.BUILDINGS[building_type])

func _on_currency_changed(gold: int, shard: int) -> void:
	currency_label.text = "Gold: %d   Shard: %d" % [gold, shard]
