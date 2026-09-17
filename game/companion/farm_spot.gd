extends Node2D

signal selected
@export_enum("gold", "wood") var resource_kind := "gold"
@export var worker_spacing := Vector2(19, 3)
var count := -1
var clock := 0.0
var workers: Array[Sprite2D] = []
@onready var template: Sprite2D = $WorkerTemplate

func _ready() -> void:
	$HitTarget.pressed.connect(func(): selected.emit())
	$HitTarget.mouse_entered.connect(func(): $Count.modulate = Color("fff3b0"))
	$HitTarget.mouse_exited.connect(func(): $Count.modulate = Color.WHITE)

func update_spot(amount: int, capacity: int, rate: float, owned: bool) -> void:
	$HitTarget.disabled = not owned
	$Count.text = "%s  •  %d workers" % ["Gold outcrop" if resource_kind == "gold" else "Forest grove", amount]
	$HitTarget.tooltip_text = "%d / %d farmers • +%.2f %s / sec\nClick to assign workers" % [amount, capacity, amount * rate, resource_kind] if owned else "Conquer to farm"
	modulate.a = 1.0 if owned else 0.45
	if count == amount: return
	count = amount
	for worker in workers: worker.queue_free()
	workers.clear()
	for i in amount:
		var worker := template.duplicate() as Sprite2D
		worker.visible = true
		worker.position = work_position(i)
		add_child(worker)
		workers.append(worker)

func work_position(index: int) -> Vector2:
	var places := $WorkPlaces.get_children()
	return places[index % places.size()].position + template.position + Vector2(index / places.size(), 0) * worker_spacing

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	for deposit in get_children():
		if deposit is Sprite2D and (deposit.name == "Resource" or str(deposit.name).begins_with("Deposit")) and deposit.hframes > 1:
			deposit.frame = posmod(int(clock * 8 + deposit.position.x * 0.1), deposit.hframes)
	for i in workers.size():
		var actor := workers[i]
		var phase := fposmod(clock + i * 1.7, 10.0)
		var clip: Texture2D = template.texture if phase < 5 else (template.carry_texture if phase < 7.5 else template.return_texture)
		if actor.texture != clip:
			actor.frame = 0
			actor.texture = clip
			actor.hframes = maxi(1, clip.get_width() / template.frame_width)
		actor.position = work_position(i)
		if phase >= 5: actor.position = actor.position.lerp($Dropoff.position, (phase - 5) / 2.5 if phase < 7.5 else (10 - phase) / 2.5)
		actor.flip_h = phase >= 7.5 or (phase < 5 and i % $WorkPlaces.get_child_count() == 4)
		actor.frame = int((clock + i * 1.7) * 8) % actor.hframes
