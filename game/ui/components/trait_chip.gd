class_name TraitChip
extends PanelContainer
## Tiny rounded chip holding one trait icon (24px) with a tooltip. Used by HeroCard.

@onready var _icon: TextureRect = $Icon


func set_icon(tex: Texture2D, tip := "") -> void:
	_icon.texture = tex
	tooltip_text = tip
