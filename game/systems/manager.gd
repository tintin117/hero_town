class_name AutoManager
extends RefCounted
## The hired promoter: books the preferred lineup once hype reaches the threshold.


static func should_book(state: GameState, t: Tuning) -> bool:
	return state.manager.enabled and state.hype >= state.manager.threshold \
			and Roster.valid_lineup(state, t, state.preferred_lineup)
