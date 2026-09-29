class_name StarRating
extends HBoxContainer
## 1-5 star excitement estimate. set_value(3.5) = certain stars (halves allowed);
## set_range(2, 4) = 2 certain stars, then translucent "possible" stars up to 4. Min size 5 x 32 + gaps.

const STAR := preload("res://resources/ui/icons/star.png")
const HALF := preload("res://resources/ui/icons/star_half.png")
const EMPTY := preload("res://resources/ui/icons/star_empty.png")

@export_range(0.0, 5.0, 0.5) var min_value := 0.0:
	set(v):
		min_value = v
		max_value = maxf(max_value, v)
		_refresh()
@export_range(0.0, 5.0, 0.5) var max_value := 0.0:
	set(v):
		max_value = maxf(v, min_value)
		_refresh()

var _stars: Array[TextureRect] = []


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	for i in 5:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(32, 32)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_stars.append(r)
	_refresh()


func set_value(v: float) -> void:
	set_range(v, v)


func set_range(lo: float, hi: float) -> void:
	min_value = lo
	max_value = maxf(hi, lo)


func _refresh() -> void:
	for i in _stars.size():
		var certain := clampf(min_value - i, 0.0, 1.0)
		var possible := clampf(max_value - i, 0.0, 1.0)
		var r := _stars[i]
		r.self_modulate = Color.WHITE
		if certain >= 1.0:
			r.texture = STAR
		elif certain >= 0.5:
			r.texture = HALF
			if possible > certain:  # the rest of this star is only "possible"
				r.texture = STAR
				r.self_modulate = Color(1, 1, 1, 0.55)
		elif possible > 0.0:
			r.texture = STAR if possible >= 1.0 else HALF
			r.self_modulate = Color(1, 1, 1, 0.55)
		else:
			r.texture = EMPTY
	tooltip_text = "%s stars" % (str(min_value) if is_equal_approx(min_value, max_value) else "%s-%s" % [min_value, max_value])
