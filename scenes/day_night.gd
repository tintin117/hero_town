extends CanvasModulate

## Simple day/night tint cycle -- the 2D replacement for the old 3D sun/moon rig.

const DAY_COLOR := Color(1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.38, 0.42, 0.62)
const CYCLE_SECONDS := 480.0  ## full day+night cycle

var _t := 0.0  ## seconds elapsed; offset in _ready() so the game boots into daylight

func _ready() -> void:
	_t = CYCLE_SECONDS * 0.5  ## the sin curve is at its peak (full daylight) here

func _process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t, CYCLE_SECONDS) / CYCLE_SECONDS
	var daylight := (sin(phase * TAU - PI * 0.5) + 1.0) * 0.5
	color = NIGHT_COLOR.lerp(DAY_COLOR, daylight)
