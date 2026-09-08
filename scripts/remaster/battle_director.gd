class_name BattleDirector
extends Node

signal phase_changed
signal battle_started
signal battle_finished(result: Dictionary)
signal preparation_started
signal combat_events(events: Array[Dictionary])

var simulation: BattleSimulation
var phase: String = "PREPARE"
var remaining: float = TownRules.PREP_SECONDS
var stage_number: int = 1
var round_id: int = 0
var result: Dictionary = {}
var _accumulator: float = 0.0
var _retry_after_round: bool = false

func _ready() -> void:
	GameState.army_improved.connect(_on_improved)
	GameState.progression_changed.connect(_refresh_stage)
	GameState.battle_mode_selected.connect(_on_mode_selected)
	GameState.phase = phase
	_refresh_stage()

func _refresh_stage() -> void:
	if phase == "PREPARE":
		stage_number = mini(20, GameState.cleared_stage + 1) if GameState.advancing else GameState.farm_stage
	phase_changed.emit()

func _on_improved(_id: String) -> void:
	if GameState.cleared_stage >= 20: return
	if phase == "PREPARE": GameState.set_advancing(true)
	else: _retry_after_round = true

func _on_mode_selected(advance_enabled: bool) -> void:
	# The player's latest Farm/Challenge choice overrides a queued upgrade retry.
	if phase != "PREPARE": _retry_after_round = advance_enabled

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if phase == "PREPARE":
		if GameState.buildings.is_empty(): return
		remaining -= delta
		if remaining <= 0: start_now()
	elif phase == "BATTLE":
		_accumulator += delta
		while _accumulator >= BattleSimulation.STEP and phase == "BATTLE":
			_accumulator -= BattleSimulation.STEP
			simulation.step()
			combat_events.emit(simulation.events)
			remaining = maxf(0, simulation.limit - simulation.elapsed)
			if simulation.outcome != -1: _finish()
	else:
		remaining -= delta
		if remaining <= 0: prepare()

func start_now() -> void:
	if phase != "PREPARE" or GameState.buildings.is_empty(): return
	_refresh_stage()
	round_id = GameState.begin_battle()
	simulation = BattleSimulation.new()
	simulation.setup(GameState.buildings.duplicate(true), GameData.STAGES[stage_number])
	phase = "BATTLE"
	GameState.phase = phase
	remaining = simulation.limit
	_accumulator = 0
	battle_started.emit()
	phase_changed.emit()

func _finish() -> void:
	if phase != "BATTLE": return
	phase = "RESULTS"
	GameState.phase = phase
	result = GameState.settle_battle(round_id, stage_number, simulation.outcome == 1, simulation.elapsed)
	result["reports"] = simulation.reports.duplicate(true)
	result["duration"] = simulation.elapsed
	remaining = TownRules.RESULT_SECONDS
	battle_finished.emit(result)
	phase_changed.emit()

func prepare() -> void:
	phase = "PREPARE"
	GameState.phase = phase
	remaining = TownRules.PREP_SECONDS
	simulation = null
	if _retry_after_round:
		_retry_after_round = false
		GameState.set_advancing(true)
	_refresh_stage()
	preparation_started.emit()
	phase_changed.emit()
