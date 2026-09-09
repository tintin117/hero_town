extends Sprite2D

@export var idle_texture: Texture2D
@export var attack_texture: Texture2D
@export var frame_width := 192

func set_battling(battling: bool) -> void:
	frame = 0
	texture = attack_texture if battling else idle_texture
	hframes = maxi(1, texture.get_width() / frame_width)
