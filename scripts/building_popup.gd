extends PanelContainer

signal upgrade_requested(context: String)

var _context: String = ""

@onready var title_label: Label = $VBox/TitleLabel
@onready var info_label: Label = $VBox/InfoLabel
@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var close_btn: Button = $VBox/CloseButton

func _ready() -> void:
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	close_btn.pressed.connect(hide_popup)
	visible = false

func show_for(context: String, title: String, info: String,
		upgrade_label: String, can_upgrade: bool) -> void:
	_context = context
	title_label.text = title
	info_label.text = info
	upgrade_btn.text = upgrade_label
	upgrade_btn.disabled = not can_upgrade
	visible = true

func hide_popup() -> void:
	visible = false
	_context = ""

func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(_context)
