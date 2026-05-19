extends Node2D

var gold := 0

const HeroScene := preload("res://scenes/hero.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")

@onready var heroes_layer: Node2D = $HeroesLayer
@onready var enemies_layer: Node2D = $EnemiesLayer
@onready var enemy_spawner: Timer = $EnemySpawner
@onready var gold_label: Label = $UI/GoldLabel

var hero_instance: CharacterBody2D = null

func _ready() -> void:
	enemy_spawner.timeout.connect(_on_enemy_spawner_timeout)
	_spawn_hero()

func _spawn_hero() -> void:
	hero_instance = HeroScene.instantiate()
	hero_instance.position = Vector2(300.0, 300.0)
	heroes_layer.add_child(hero_instance)

func _on_enemy_spawner_timeout() -> void:
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.position = Vector2(1100.0, 300.0)
	enemies_layer.add_child(enemy)
	enemy.setup(hero_instance)
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(amount: int) -> void:
	add_gold(amount)

func add_gold(amount: int) -> void:
	gold += amount
	gold_label.text = "Gold: %d" % gold
