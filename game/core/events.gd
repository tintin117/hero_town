extends Node
## Autoload "Events": signals describe what already happened and carry the new value.
## Emitted by Game only; UI, Arena and Town listen. Contract: docs/ARCHITECTURE.md section 4.

signal gold_changed(gold: int, delta: int)
signal hype_changed(hype: float)  ## <= 10 Hz while hype moves
signal fame_changed(points: int, tier: int)  ## tier is 0-based
signal fight_booked(lineup: Array[int], main_event: StringName)
signal fight_started(info: Dictionary)  ## lineup, attendance, seats, seed, duration
signal combat_event(event: Dictionary)
signal fight_finished(result: Dictionary)  ## one bout settled
signal series_started(info: Dictionary)  ## lineup, attendance, seats, wins_needed
signal series_finished(result: Dictionary)  ## winner (-1 = unresolved), wins {id: n}, bouts, fame_bonus
signal roster_changed
signal hero_changed(id: int)
signal building_changed(id: StringName)
signal story_changed(story_id: int)
signal story_ripe(story_id: int)
signal prop_changed
signal manager_changed
signal toast(text: String, icon: StringName)
signal paused_changed(paused: bool)
