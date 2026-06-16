extends Node
## Atomic seating transaction for Portal discoveries.
##
## Listens to EventBus.portal_completed, persists a MuseumEntry, marks the
## fragment as SEATED, saves atomically, and then emits fragment_seated.
## Duplicate events are ignored; fragment is never seated before save succeeds.


func _ready() -> void:
	EventBus.portal_completed.connect(_on_portal_completed)


func _on_portal_completed(
	fragment_id: String, museum_entry_id: String, _used_fallback: bool, fact_card: String
) -> void:
	if fragment_id.is_empty() or museum_entry_id.is_empty():
		push_error("SeatingService: empty fragment_id or museum_entry_id")
		return

	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if not fragments.has(fragment_id):
		push_error("SeatingService: unknown fragment '%s'" % fragment_id)
		return

	var fragment: Fragment = fragments[fragment_id]
	if fragment.state == ModelEnums.FragmentState.SEATED:
		# Already seated; ignore duplicate portal completion.
		return

	if fragment.state != ModelEnums.FragmentState.RELEASED:
		push_error("SeatingService: fragment '%s' is not released" % fragment_id)
		return

	var museum_entries: Dictionary = GameState.save_state.persistent.museum_entries
	if museum_entries.has(museum_entry_id):
		# Idempotent: this museum entry already exists.
		return

	var entry := MuseumEntry.new()
	entry.artifact_id = fragment_id
	# The museum_entry_id is the authoritative key; artifact_id may later be the
	# assembled artifact id, but for fragments we use the fragment id.
	entry.fact_card = fact_card
	if entry.fact_card.is_empty():
		entry.fact_card = _lookup_fact_card(fragment_id, museum_entry_id)
	if entry.fact_card.is_empty():
		push_warning("SeatingService: no fact card for '%s'" % fragment_id)

	museum_entries[museum_entry_id] = entry
	fragment.state = ModelEnums.FragmentState.SEATED

	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_warning(
			(
				"SeatingService: save failed (%s); rolling back seat state"
				% save_result.get("error", "")
			)
		)
		# Roll back in-memory changes so the player can retry.
		museum_entries.erase(museum_entry_id)
		fragment.state = ModelEnums.FragmentState.RELEASED
		return

	EventBus.fragment_seated.emit(fragment_id, fragment.case_slot_index)


func _lookup_fact_card(fragment_id: String, museum_entry_id: String) -> String:
	# If the museum entry was already created by a prior attempt, reuse it.
	var existing: Dictionary = GameState.save_state.persistent.museum_entries
	if existing.has(museum_entry_id):
		var entry: MuseumEntry = existing[museum_entry_id]
		return entry.fact_card

	# Otherwise pull from authored fragment data if available.
	var fragment: Fragment = GameState.save_state.persistent.fragments.get(fragment_id)
	if fragment == null:
		return ""

	var fact_ref: String = fragment.historical_fact_ref
	if fact_ref.is_empty():
		return ""

	var repo := DataRepository.singleton()
	# Future: repository may expose historical facts by ref.
	return ""
