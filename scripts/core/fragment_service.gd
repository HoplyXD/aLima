extends Node
## Fragment lifecycle authority (LOCKED -> RELEASED -> SEATED). Registered as the
## `FragmentService` autoload.
##
## The persistent save state (GameState.save_state.persistent.fragments) is the
## runtime authority for fragment state; the DataRepository fragments hold only the
## authored *initial* state that GameState copies into persistent on initialize.
##
## A route is never allowed to hand a fragment to the player (CLAUDE.md §4-B/C):
## completing a route releases its fragment, and the Spawn Director then promotes an
## ordinary openable instance to carry it. This service performs only the
## LOCKED -> RELEASED transition (and mirrors it onto the repo so the Spawn Director,
## which reads repo state, agrees). SEATED is owned by SeatingService.


## Current state of a fragment, preferring the persistent (runtime) value and
## falling back to the authored repo value when the fragment is not yet tracked.
func get_state(fragment_id: String) -> int:
	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if fragments.has(fragment_id):
		var fragment: Fragment = fragments[fragment_id]
		return fragment.state
	var repo := DataRepository.singleton()
	var authored: Fragment = repo.get_fragment(fragment_id)
	return authored.state if authored != null else ModelEnums.FragmentState.LOCKED


func is_locked(fragment_id: String) -> bool:
	return get_state(fragment_id) == ModelEnums.FragmentState.LOCKED


func is_released(fragment_id: String) -> bool:
	return get_state(fragment_id) == ModelEnums.FragmentState.RELEASED


func is_seated(fragment_id: String) -> bool:
	return get_state(fragment_id) == ModelEnums.FragmentState.SEATED


## Transitions a LOCKED fragment to RELEASED, mirrors the state onto the repo so the
## Spawn Director sees it, persists atomically, and emits EventBus.fragment_released.
## Returns true only when a real LOCKED -> RELEASED transition happened. A fragment
## that is already RELEASED or SEATED is left untouched (idempotent, returns false).
func release_fragment(fragment_id: String, reason: String = "") -> bool:
	if fragment_id.is_empty():
		return false
	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if not fragments.has(fragment_id):
		push_warning("FragmentService: unknown fragment '%s'" % fragment_id)
		return false
	var fragment: Fragment = fragments[fragment_id]
	if fragment.state != ModelEnums.FragmentState.LOCKED:
		return false

	fragment.state = ModelEnums.FragmentState.RELEASED
	_mirror_to_repo(fragment_id, ModelEnums.FragmentState.RELEASED)

	var save_result := SaveService.save_game()
	if not save_result.ok:
		# Roll back so the caller can retry; never advertise an unsaved release.
		fragment.state = ModelEnums.FragmentState.LOCKED
		_mirror_to_repo(fragment_id, ModelEnums.FragmentState.LOCKED)
		push_warning("FragmentService: release save failed (%s)" % save_result.get("error", ""))
		return false

	if not reason.is_empty():
		print("[FragmentService] released %s (%s)" % [fragment_id, reason])
	EventBus.fragment_released.emit(fragment_id)
	return true


## Copies every persistent fragment state onto the matching repo fragment so the
## Spawn Director (which reads repo state) reflects what the player has actually
## released or seated. Call at session start and after loading a save.
func sync_repo_from_persistent() -> void:
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	for fragment_id in GameState.save_state.persistent.fragments.keys():
		var fragment: Fragment = GameState.save_state.persistent.fragments[fragment_id]
		_mirror_to_repo(fragment_id, fragment.state)


func _mirror_to_repo(fragment_id: String, state: int) -> void:
	var repo := DataRepository.singleton()
	var authored: Fragment = repo.get_fragment(fragment_id)
	if authored != null:
		authored.state = state
