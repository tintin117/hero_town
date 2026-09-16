extends Node2D
## Decorative work and delivery loops, independent of the economy.
const WorkerActor = preload("res://conquest/worker_actor.gd")
@export_range(0.1, 60, 0.1) var cycle_seconds := 10.0
@export_range(0.05, 60, 0.05) var work_seconds := 5.0
@export var delivery_distance := 55.0
@export_range(1, 30, 1) var animation_fps := 8.0
var workers: Array[Dictionary] = []
var scenery: Array[Sprite2D] = []
var clock := 0.0

func _ready() -> void:
	for actor in get_children():
		if actor is WorkerActor:
			var entry := {"actor": actor, "home": actor.position, "offset": actor.phase_offset,
				"work": actor.texture, "carry": actor.carry_texture, "return": actor.return_texture}
			workers.append(entry)
			update_worker(entry)
		elif actor is Sprite2D and actor.hframes > 1: scenery.append(actor)

func update_worker(entry: Dictionary) -> void:
	var cycle := maxf(0.1,cycle_seconds)
	var working := clampf(work_seconds,0.05,cycle-0.05)
	var travel := (cycle-working)*0.5
	var phase := fposmod(clock + float(entry.offset), cycle)
	var actor: Sprite2D = entry.actor
	var clip: Texture2D = entry.work if phase < working else (entry.carry if phase < working+travel else entry.return)
	if clip != null and actor.texture != clip:
		actor.frame = 0
		actor.texture = clip
		actor.hframes = maxi(1,clip.get_width() / actor.frame_width)
	actor.position = entry.home
	if phase >= working:
		actor.position.x += delivery_distance * ((phase-working)/travel if phase < working+travel else (cycle-phase)/travel)
	actor.flip_h = phase < working or phase >= working+travel
	actor.frame = int((clock + float(entry.offset)) * animation_fps) % actor.hframes

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	for entry in workers: update_worker(entry)
	for actor in scenery: actor.frame = int(clock * animation_fps) % actor.hframes
