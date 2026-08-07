extends Node

signal currency_changed(gold: int, shard: int)

var gold: int = 5000
var shard: int = 0

func can_afford(gold_cost: int, shard_cost: int = 0) -> bool:
	return gold >= gold_cost and shard >= shard_cost

func spend(gold_cost: int, shard_cost: int = 0) -> bool:
	if not can_afford(gold_cost, shard_cost):
		return false
	gold -= gold_cost
	shard -= shard_cost
	currency_changed.emit(gold, shard)
	return true

func add(gold_amount: int, shard_amount: int = 0) -> void:
	gold += gold_amount
	shard += shard_amount
	currency_changed.emit(gold, shard)
