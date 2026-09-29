extends Node2D
## Decorative visitors pacing along the public path. Pure view: no game state.

const Actor := preload("res://resources/art/sunnyside_actor.gd")
const SPEED := 36.0
const COUNT := 6
const PATH_Y := 236.0
# Path stretches either side of the arena (world px).
const STRETCHES: Array[Vector2] = [Vector2(40, 490), Vector2(1046, 1496)]

var _walkers: Array[Dictionary] = []


func _ready() -> void:
	for i in COUNT:
		var actor := Actor.new()
		actor.setup(randi(), "warrior")
		actor.show_equipment = false
		actor.sprite.modulate = Color.from_hsv(randf(), 0.2, 1.0)
		var stretch := STRETCHES[i % STRETCHES.size()]
		var x := randf_range(stretch.x, stretch.y)
		actor.position = Vector2(x, PATH_Y + (i % 3) * 8)
		add_child(actor)
		_walkers.append({"actor": actor, "x": x, "stretch": stretch, "target": x, "wait": randf_range(0.0, 3.0)})


func _process(delta: float) -> void:
	for w in _walkers:
		var actor: Node2D = w.actor
		if w.wait > 0.0:
			w.wait -= delta
			if w.wait <= 0.0:
				var stretch: Vector2 = w.stretch
				w.target = randf_range(stretch.x, stretch.y)
				actor.flip_h = w.target < w.x
				actor.play(&"walk")
			continue
		w.x = move_toward(w.x, w.target, SPEED * delta)
		actor.position.x = roundf(w.x)
		if w.x == w.target:
			w.wait = randf_range(1.5, 4.5)
			actor.play(&"idle")
