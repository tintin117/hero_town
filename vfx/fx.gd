extends Node
const EFFECTS := {
	"impact_spark": "res://vfx/effects/impact/impact_spark.tscn",
	"shockwave": "res://vfx/effects/impact/shockwave.tscn",
	"hit_flash": "res://vfx/effects/impact/hit_flash.tscn",
	"hit_burst": "res://vfx/effects/impact/hit_burst.tscn",
	"pickup_sparkle": "res://vfx/effects/ui/pickup_sparkle.tscn",
	"smoke_pop": "res://vfx/effects/utility/smoke_pop.tscn",
}

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _popup_font: SystemFont
var _hitstop_busy := false
var _shake_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_popup_font = SystemFont.new()
	_popup_font.font_names = PackedStringArray(["Arial Black", "Arial", "Sans-Serif"])
	_popup_font.font_weight = 900

## Spawn an effect by name at a global position.
## opts: { "parent": Node, "size": float, "speed": float,
##         "color_main": Color, "color_accent": Color, "rotation": float }
func spawn(effect_name: String, global_pos: Vector2, opts: Dictionary = {}) -> FxEffect:
	if not EFFECTS.has(effect_name):
		return null
	var scene: PackedScene = load(EFFECTS[effect_name])
	var fx: FxEffect = scene.instantiate()
	fx.auto_play = true
	if opts.has("size"): fx.size = opts.size
	if opts.has("speed"): fx.speed = opts.speed
	if opts.has("color_main"): fx.color_main = opts.color_main
	if opts.has("color_accent"): fx.color_accent = opts.color_accent
	if opts.has("rotation"): fx.rotation = opts.rotation
	var parent: Node = opts.get("parent", get_tree().current_scene)
	parent.add_child(fx)
	fx.global_position = global_pos
	return fx

# --- Game feel -------------------------------------------------------------

## Shake the active Camera2D. strength in pixels.
func shake(strength: float = 3.0, duration: float = 0.25) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	# Kill any running shake first or overlapping tweens leave the camera offset.
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	cam.offset = Vector2.ZERO

	var t := create_tween()
	_shake_tween = t
	var steps := maxi(int(duration * 60.0), 4)

	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		t.tween_property(cam, "offset", off, duration / steps)

	t.tween_property(cam, "offset", Vector2.ZERO, duration / steps)

## Freeze-frame: dip Engine.time_scale for a moment. Safe to call repeatedly.
func hitstop(duration: float = 0.06, time_scale: float = 0.05) -> void:
	if _hitstop_busy:
		return
	_hitstop_busy = true
	var prev := Engine.time_scale
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = prev
	_hitstop_busy = false

## Full-screen color flash.
func flash(color: Color = Color.WHITE, duration: float = 0.12, max_alpha: float = 0.85) -> void:
	if _flash_layer == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 100
		add_child(_flash_layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_layer.add_child(_flash_rect)
	_flash_rect.color = Color(color.r, color.g, color.b, max_alpha)
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)

## Juicy damage/score popup text.
## opts: { "color": Color, "crit": bool, "font_size": int, "parent": Node }
func popup(text: String, global_pos: Vector2, opts: Dictionary = {}) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.z_index = 999
	var fsize: int = opts.get("font_size", 24)
	var col: Color = opts.get("color", Color("#fff8e7"))
	if opts.get("crit", false):
		#fsize = int(fsize * 1.2)
		col = opts.get("color", Color("#ffd23f"))
	lbl.add_theme_font_override("font", _popup_font)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.12, 1))
	lbl.add_theme_constant_override("outline_size", maxi(fsize / 5, 4))
	var parent: Node = opts.get("parent", get_tree().current_scene)
	parent.add_child(lbl)
	lbl.global_position = global_pos
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2.ONE * 0.2
	lbl.rotation = randf_range(-0.08, 0.08)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "global_position",
		global_pos + Vector2(randf_range(-14, 14), -60), 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(lbl, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(lbl.queue_free)
