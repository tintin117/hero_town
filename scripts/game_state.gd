extends Node

signal currency_changed(gold: int, shard: int)
signal roster_changed

const HERO_CAP := 8            # tunable roster cap
const MAX_STAR := 3
const CLASS_BUFF_THRESHOLD := 3
const CLASS_BUFFS := {         # stat multiplier applied to that class's heroes once threshold is met
	HeroData.HeroClass.WARRIOR: {"stat": "max_hp", "mult": 1.25},
	HeroData.HeroClass.ROGUE: {"stat": "atk", "mult": 1.25},
	HeroData.HeroClass.MAGE: {"stat": "mana_per_hit", "mult": 1.25},
	# HeroData.HeroClass.CLERIC: deferred -- will reduce skill cooldown once wired up in character.gd
}

var gold: int = 5000
var shard: int = 500
var owned_heroes: Dictionary = {}  # hero_id -> star (int, 1..MAX_STAR)

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

func get_class_counts() -> Dictionary:
	var counts := {}
	for hero_id in owned_heroes:
		var cls: HeroData.HeroClass = GameData.HEROES[hero_id].hero_class
		counts[cls] = counts.get(cls, 0) + 1
	return counts

func has_class_buff(cls: HeroData.HeroClass) -> bool:
	return get_class_counts().get(cls, 0) >= CLASS_BUFF_THRESHOLD

func is_roster_full() -> bool:
	return owned_heroes.size() >= HERO_CAP

## Grants hero_id for free (e.g. the starting hero) without spending currency.
func grant_hero(hero_id: String) -> void:
	owned_heroes[hero_id] = 1
	roster_changed.emit()

## Buys hero_id for the shop offer/reroll cost. Grants a new 1-star hero if not owned,
## merges to the next star if a lower-star duplicate is owned, or converts to dupe shards
## if already at MAX_STAR. Returns false if unaffordable or roster is full.
func buy_hero(hero_id: String, cost_gold: int, cost_shard: int) -> bool:
	if not can_afford(cost_gold, cost_shard):
		return false
	var is_new := not owned_heroes.has(hero_id)
	if is_new and is_roster_full():
		return false
	spend(cost_gold, cost_shard)
	if is_new:
		owned_heroes[hero_id] = 1
	else:
		var star: int = owned_heroes[hero_id]
		if star < MAX_STAR:
			owned_heroes[hero_id] = star + 1
		else:
			add(0, GameData.HEROES[hero_id].dupe_shard)
	roster_changed.emit()
	return true

func release_hero(hero_id: String) -> void:
	if not owned_heroes.has(hero_id):
		return
	owned_heroes.erase(hero_id)
	roster_changed.emit()
