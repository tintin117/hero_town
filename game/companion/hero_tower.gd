extends Node2D

signal selected
@export var class_id := "warrior"
@export var title := "Warrior"

func _ready() -> void:
	$HitTarget.pressed.connect(func(): selected.emit())

func refresh(game: FarmFightState) -> void:
	var unlocked: bool = game.s.research[class_id].unlocked
	var built: bool = game.s.towers.has(class_id)
	$Sprite.modulate.a = 1.0 if built else 0.3
	if built:
		$Status.text = "%s %d/%d\n%s" % [title, game.simulation.living_class(class_id), game.balance.hero_cap,
			"Ready" if game.s.towers[class_id].remaining <= 0 else "Spawn %.1fs" % game.s.towers[class_id].remaining]
	else: $Status.text = title + ("\nBuild tower" if unlocked else "\nResearch to unlock")
