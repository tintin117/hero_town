class_name Hero
extends Character

@export var hero_data: HeroData
@export var patrol_start_x: float = 0.0
@export var patrol_end_x: float = 0.0
@export var revive_delay: float = 5.0  ## seconds a downed hero rests before reviving at full hp
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _patrol_dir: int = 1


func _ready() -> void:
	apply_hero_data()
	super._ready()
	add_to_group("heroes")


## Applies hero_data's base stats, then this hero's class buff if active.
## Resets to hero_data's raw values first, so re-running never stacks a buff twice.
## Safe to call anytime after spawn (e.g. on roster changes) without touching current hp.
func apply_hero_data() -> void:
	if hero_data == null:
		return
	max_hp = hero_data.base_hp
	atk = hero_data.base_power
	atk_speed = hero_data.atk_speed
	mana_per_hit = hero_data.mana_per_hit
	if GameState.has_class_buff(hero_data.hero_class):
		var buff: Dictionary = GameState.CLASS_BUFFS.get(hero_data.hero_class, {})
		if buff.has("stat"):
			set(buff["stat"], get(buff["stat"]) * buff["mult"])


func _update_move(_delta: float) -> void:
	anim_player.play("move")
	_chase_and_engage("enemies")


func _idle_move() -> void:
	_patrol()


func _patrol() -> void:
	if absf(patrol_end_x - patrol_start_x) < 0.01:
		velocity = Vector3.ZERO
		return
	if global_position.x >= patrol_end_x:
		_patrol_dir = -1
	elif global_position.x <= patrol_start_x:
		_patrol_dir = 1
	velocity = Vector3(_patrol_dir * move_speed, 0.0, 0.0)


func _should_knockback(attacker: Character) -> bool:
	return attacker is Enemy and attacker.is_boss


func _die() -> void:
	anim_player.play("die")
	collision_layer = 0
	get_tree().create_timer(revive_delay).timeout.connect(_revive)


func _revive() -> void:
	hp = max_hp
	_update_health_bar()
	anim_player.play("idle")
	collision_layer = HITBOX_LAYER
	state = State.MOVE
