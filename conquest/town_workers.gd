extends Node2D
## Decorative work and delivery loops, independent of the economy.
const PACK := "res://asset/Tiny Swords (Free Pack)/"
var workers: Array[Dictionary] = []
var scenery: Array[Sprite2D] = []
var clock := 0.0

func _ready() -> void:
	add_scenery("Terrain/Resources/Wood/Trees/Tree1.png", Vector2(48, 130), 0.45, 8)
	add_scenery("Terrain/Resources/Wood/Trees/Stump 1.png", Vector2(105, 171), 0.5)
	add_scenery("Terrain/Resources/Wood/Wood Resource/Wood Resource.png", Vector2(151, 169), 0.7)
	add_scenery("Terrain/Resources/Gold/Gold Stones/Gold Stone 6.png", Vector2(207, 158), 0.9)
	add_scenery("Terrain/Resources/Gold/Gold Resource/Gold_Resource.png", Vector2(300, 174), 0.7)
	add_scenery("Terrain/Resources/Meat/Sheep/Sheep_Grass.png", Vector2(378, 162), 0.5, 12)
	add_scenery("Terrain/Resources/Meat/Meat Resource/Meat Resource.png", Vector2(451, 174), 0.65)
	add_worker("Woodcutter", Vector2(77, 163), "Axe", "Wood", 0.0)
	add_worker("Miner", Vector2(238, 163), "Pickaxe", "Gold", 2.5)
	add_worker("FoodGatherer", Vector2(399, 171), "Knife", "Meat", 5.0)

func add_scenery(path: String, at: Vector2, factor: float, frames := 1) -> void:
	var actor := Sprite2D.new()
	actor.texture = load(PACK + path)
	actor.position = at
	actor.scale = Vector2.ONE * factor
	actor.hframes = frames
	add_child(actor)
	if frames > 1: scenery.append(actor)

func add_worker(title: String, at: Vector2, tool: String, resource: String, offset: float) -> void:
	var actor := Sprite2D.new()
	actor.name = title
	actor.scale = Vector2.ONE * 0.5
	add_child(actor)
	var entry := {"actor": actor, "home": at, "offset": offset,
		"work": load(PACK + "Units/Blue Units/Pawn/Pawn_Interact " + tool + ".png"),
		"carry": load(PACK + "Units/Blue Units/Pawn/Pawn_Run " + resource + ".png"),
		"return": load(PACK + "Units/Blue Units/Pawn/Pawn_Run " + tool + ".png")}
	workers.append(entry)
	update_worker(entry)

func update_worker(entry: Dictionary) -> void:
	var phase := fmod(clock + float(entry.offset), 10.0)
	var actor: Sprite2D = entry.actor
	var clip: Texture2D = entry.work if phase < 5 else (entry.carry if phase < 7.5 else entry.return)
	if actor.texture != clip:
		actor.frame = 0
		actor.texture = clip
		actor.hframes = clip.get_width() / 192
	actor.position = entry.home
	if phase >= 5:
		actor.position.x += 55 * ((phase - 5) / 2.5 if phase < 7.5 else (10 - phase) / 2.5)
	actor.flip_h = phase < 5 or phase >= 7.5
	actor.frame = int((clock + float(entry.offset)) * 8) % actor.hframes

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	for entry in workers: update_worker(entry)
	for actor in scenery: actor.frame = int(clock * 8) % actor.hframes
