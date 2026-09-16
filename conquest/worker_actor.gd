extends Sprite2D
## Texture is the work pose; these clips play during the decorative delivery loop.
@export var carry_texture: Texture2D
@export var return_texture: Texture2D
@export_range(0, 60, 0.1) var phase_offset := 0.0
@export_range(1, 1024, 1) var frame_width := 192
