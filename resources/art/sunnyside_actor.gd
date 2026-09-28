extends Node2D
## One animation clock drives all Sunnyside character layers. The origin is the feet.
signal animation_finished

const ROOT := "res://asset/Sunnyside_World_Assets/Characters/Human/"
const HAIRS := ["spikeyhair", "shorthair", "longhair", "bowlhair", "mophair", "curlyhair", "longhair", "shorthair"]
const HAIR_COLORS := [Color("bf653e"), Color("e4b459"), Color("563849"), Color("aebdba"), Color("302b45"), Color("916e42"), Color("a74051"), Color("d2c7ab")]
const FOOT := Vector2(48, 39)
const CLIPS := {
	"idle": ["IDLE", "idle", 9, 8.0, true],
	"walk": ["WALKING", "walk", 8, 10.0, true],
	"run": ["RUN", "run", 8, 12.0, true],
	"attack": ["ATTACK", "attack", 10, 16.0, false],
	"hurt": ["HURT", "hurt", 8, 14.0, false],
	"death": ["DEATH", "death", 13, 14.0, false],
}
static var frame_cache: Dictionary = {}

var sprite := AnimatedSprite2D.new()
var hair := AnimatedSprite2D.new()
var tool := AnimatedSprite2D.new()
var visuals := Node2D.new()
var equipment := Node2D.new()
var unit := "warrior"
var hero_id := 0
var show_equipment := true
var _setup_done := false
var _flip_h := false
var flip_h: bool:
	get: return _flip_h
	set(value):
		_flip_h = value
		visuals.scale = Vector2(-2.0 if value else 2.0, 2.0)
var animation: StringName:
	get: return sprite.animation
var frame: int:
	get: return sprite.frame
	set(value):
		sprite.frame = value
		_sync_frame()
var frame_progress: float:
	get: return sprite.frame_progress
var animation_progress: float:
	get:
		if not sprite.sprite_frames: return 0.0
		return (sprite.frame + sprite.frame_progress) / maxf(1.0, sprite.sprite_frames.get_frame_count(sprite.animation))
var sprite_frames: SpriteFrames:
	get: return sprite.sprite_frames


func setup(id: int, kind: String, red: bool = false) -> void:
	hero_id = posmod(id, HAIRS.size())
	unit = kind
	if not _setup_done:
		_setup_done = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(visuals)
		visuals.scale = Vector2(2, 2)
		for layer in [sprite, hair, tool]:
			layer.centered = false
			layer.position = -FOOT
			visuals.add_child(layer)
		visuals.add_child(equipment)
		equipment.draw.connect(_draw_equipment)
		sprite.frame_changed.connect(_sync_frame)
		sprite.animation_finished.connect(func(): animation_finished.emit())
	sprite.sprite_frames = _frames("base")
	hair.sprite_frames = _frames(HAIRS[hero_id])
	tool.sprite_frames = _frames("tools")
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 hair_color : source_color; void fragment(){ vec4 c=texture(TEXTURE,UV); float v=max(c.r,max(c.g,c.b)); COLOR=vec4(hair_color.rgb*(0.45+v*0.8),c.a)*COLOR; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("hair_color", HAIR_COLORS[hero_id].lightened(0.08) if red else HAIR_COLORS[hero_id])
	hair.material = material
	play("idle")


func _frames(layer: String) -> SpriteFrames:
	var sword := unit == "warrior"
	var cache_key := "%s:%s" % [layer, "sword" if sword else "gesture"]
	if frame_cache.has(cache_key): return frame_cache[cache_key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip in CLIPS:
		var data: Array = CLIPS[clip].duplicate()
		if clip == "attack" and not sword:
			data = ["DOING", "doing", 8, 16.0, false]
		var texture: Texture2D = load(ROOT + "%s/%s_%s_strip%d.png" % [data[0], layer, data[1], data[2]])
		frames.add_animation(clip)
		frames.set_animation_speed(clip, data[3])
		frames.set_animation_loop(clip, data[4])
		for index in range(data[2]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(index * 96, 0, 96, 64)
			frames.add_frame(clip, atlas)
	frame_cache[cache_key] = frames
	return frames


func play(clip: StringName) -> void:
	if not _setup_done: setup(hero_id, unit)
	if not sprite.sprite_frames.has_animation(clip): clip = &"idle"
	sprite.play(clip)
	_sync_frame()


func stop() -> void:
	sprite.stop()


func is_playing() -> bool:
	return sprite.is_playing()


func _sync_frame() -> void:
	if not _setup_done or not sprite.sprite_frames: return
	for layer in [hair, tool]:
		layer.animation = sprite.animation
		layer.frame = sprite.frame
		layer.frame_progress = sprite.frame_progress
	tool.visible = show_equipment and unit == "warrior" and sprite.animation == &"attack"
	equipment.visible = show_equipment
	equipment.queue_redraw()


func _draw_equipment() -> void:
	if not show_equipment or (unit == "warrior" and animation == &"attack"): return
	var swing := sin(animation_progress * PI) * 4.0 if animation == &"attack" else 0.0
	var wood := Color("a66f48")
	var light := Color("d7e8dc")
	var dark := Color("3e3948")
	var hand := Vector2(4, -5)
	match unit:
		"lancer":
			var start := hand + Vector2(swing, 0)
			equipment.draw_line(start + Vector2(-8, 2), start + Vector2(10, -2), dark, 3)
			equipment.draw_line(start + Vector2(-8, 2), start + Vector2(10, -2), wood, 1)
			equipment.draw_colored_polygon(PackedVector2Array([start + Vector2(9, -4), start + Vector2(15, -3), start + Vector2(10, 0)]), light)
		"archer":
			var bow := hand + Vector2(2, -3)
			equipment.draw_polyline(PackedVector2Array([bow + Vector2(0, -6), bow + Vector2(3, -4), bow + Vector2(4, 0), bow + Vector2(3, 4), bow + Vector2(0, 6)]), dark, 3)
			equipment.draw_polyline(PackedVector2Array([bow + Vector2(0, -6), bow + Vector2(3, -4), bow + Vector2(4, 0), bow + Vector2(3, 4), bow + Vector2(0, 6)]), wood, 1)
			equipment.draw_line(bow + Vector2(0, -6), bow + Vector2(-swing, 0), light, 1)
			equipment.draw_line(bow + Vector2(-swing, 0), bow + Vector2(0, 6), light, 1)
			if animation == &"attack": equipment.draw_line(bow + Vector2(-5, 0), bow + Vector2(9, 0), light, 1)
		"monk":
			equipment.draw_line(hand + Vector2(2, -12 - swing), hand + Vector2(2, 5), dark, 3)
			equipment.draw_line(hand + Vector2(2, -12 - swing), hand + Vector2(2, 5), wood, 1)
			equipment.draw_rect(Rect2(hand + Vector2(0, -14 - swing), Vector2(5, 5)), Color("78cf91"))
			equipment.draw_rect(Rect2(hand + Vector2(1, -13 - swing), Vector2(2, 2)), Color("d1ffe0"))
		_:
			equipment.draw_line(hand + Vector2(1, 3), hand + Vector2(4, -8), dark, 3)
			equipment.draw_line(hand + Vector2(2, 0), hand + Vector2(4, -8), light, 1)
			equipment.draw_line(hand + Vector2(-1, -1), hand + Vector2(5, 1), Color("efc165"), 1)


func capture_afterimage() -> Node2D:
	var ghost: Node2D = get_script().new()
	ghost.setup(hero_id, unit)
	ghost.show_equipment = show_equipment
	ghost.flip_h = flip_h
	ghost.play(animation)
	ghost.frame = frame
	ghost.stop()
	return ghost
