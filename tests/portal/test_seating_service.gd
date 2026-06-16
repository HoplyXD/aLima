extends GutTest
## Tests for the atomic seating transaction.

const SeatingServiceScript := preload("res://scripts/journal/seating_service.gd")

var _seating: SeatingService = null


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	SaveService.set_save_paths("user://test_save.json", "user://test_save.tmp")
	SaveService.delete_save_files()
	_seating = SeatingServiceScript.new()
	add_child_autofree(_seating)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths("user://save.json", "user://save.tmp")


func _make_fragment(id: String, slot: int) -> Fragment:
	var fragment := Fragment.new()
	fragment.id = id
	fragment.master_artifact_id = "master_artifact_demo"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = slot
	fragment.state = ModelEnums.FragmentState.RELEASED
	fragment.echo_set_ref = "demo_echo_set"
	fragment.historical_fact_ref = ""
	return fragment


func test_portal_completed_seats_fragment_and_creates_museum_entry() -> void:
	var fragment := _make_fragment("fragment_01", 0)
	GameState.save_state.persistent.fragments["fragment_01"] = fragment

	var received: Array = []
	EventBus.fragment_seated.connect(func(id: String, slot: int): received.append([id, slot]))

	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)

	assert_eq(fragment.state, ModelEnums.FragmentState.SEATED)
	assert_true(GameState.save_state.persistent.museum_entries.has("entry_fragment_01_player"))
	var entry: MuseumEntry = (
		GameState.save_state.persistent.museum_entries["entry_fragment_01_player"]
	)
	assert_eq(entry.artifact_id, "fragment_01")
	assert_eq(entry.fact_card, "A small gear.")
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], "fragment_01")
	assert_eq(received[0][1], 0)


func test_duplicate_portal_completed_is_ignored() -> void:
	var fragment := _make_fragment("fragment_01", 0)
	GameState.save_state.persistent.fragments["fragment_01"] = fragment

	var received: Array = []
	EventBus.fragment_seated.connect(func(id: String, slot: int): received.append([id, slot]))

	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)
	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)
	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)

	assert_eq(fragment.state, ModelEnums.FragmentState.SEATED)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 1)
	assert_eq(received.size(), 1)


func test_seated_fragment_is_ignored() -> void:
	var fragment := _make_fragment("fragment_01", 0)
	fragment.state = ModelEnums.FragmentState.SEATED
	GameState.save_state.persistent.fragments["fragment_01"] = fragment

	var received: Array = []
	EventBus.fragment_seated.connect(func(id: String, slot: int): received.append([id, slot]))

	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)

	assert_eq(received.size(), 0)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 0)


func test_save_failure_rolls_back_seat() -> void:
	# Make save fail by using an invalid directory.
	SaveService.set_save_paths("/invalid_dir/test_save.json", "/invalid_dir/test_save.tmp")
	var fragment := _make_fragment("fragment_01", 0)
	GameState.save_state.persistent.fragments["fragment_01"] = fragment

	EventBus.portal_completed.emit(
		"fragment_01", "entry_fragment_01_player", false, "A small gear."
	)

	assert_eq(fragment.state, ModelEnums.FragmentState.RELEASED)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 0)
