class_name AutoManager
extends RefCounted
## The hired promoter: rings the bell for the planted lineup once hype reaches the threshold.


static func should_book(state: GameState, t: Tuning, planted: Array[int]) -> bool:
	return state.manager.enabled and state.hype >= state.manager.threshold \
			and Roster.valid_lineup(state, t, planted)
