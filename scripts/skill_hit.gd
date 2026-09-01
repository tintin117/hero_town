class_name SkillHit
extends Area2D

## Generic skill-cast hitbox: stationary (AOE) when speed == 0, otherwise
## travels along direction (projectile).

@export var damage: float = 0.0
@export var radius: float = 40.0
@export var speed: float = 0.0
@export var direction: Vector2 = Vector2.DOWN
@export var lifetime: float = 0.4
@export var tick_interval: float = 0.0 ## 0 = single hit on contact; >0 = re-damage every interval while overlapping.
@export var crit: bool = true
@export var screen_shake: bool = true

var caster: Character
var target_group: String = ""

@onready var _collision: CollisionShape2D = $CollisionShape2D

var _hit: Array[Character] = []


func _ready() -> void:
	(_collision.shape as CircleShape2D).radius = radius
	collision_layer = 0
	collision_mask = 1 << 2  # Character.HITBOX_LAYER
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

	if tick_interval > 0.0:
		var tick_timer := Timer.new()
		tick_timer.wait_time = tick_interval
		tick_timer.timeout.connect(_on_tick)
		add_child(tick_timer)
		tick_timer.start()
	else:
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if speed > 0.0:
		global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	var character := _valid_target(body)
	if character == null or character in _hit:
		return
	_hit.append(character)
	character.take_damage(damage, caster)
	character.spawn_fx(damage, crit, screen_shake)


func _on_tick() -> void:
	for body in get_overlapping_bodies():
		var character := _valid_target(body)
		if character != null:
			character.take_damage(damage, caster)
			character.spawn_fx(damage, crit, screen_shake)


func _valid_target(body: Node) -> Character:
	var character := body as Character
	if character == null or character == caster:
		return null
	if not character.is_in_group(target_group):
		return null
	return character
