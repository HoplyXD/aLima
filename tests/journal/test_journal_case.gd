extends GutTest
## Tests for the five-slot Fragment Case: rendering, seating, and persistence.

const PAGE_SCENE := preload("res://scenes/Book/Page.tscn")


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	SaveService.set_save_paths("user://test_save.json", "user://test_save.tmp")
	SaveService.delete_save_files()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths("user://save.json", "user://save.tmp")


func _make_fragment(id: String, slot: int, state: int) -> Fragment:
	var fragment := Fragment.new()
	fragment.id = id
	fragment.master_artifact_id = "master_artifact_demo"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = slot
	fragment.state = state
	fragment.echo_set_ref = "demo_echo_set"
	fragment.historical_fact_ref = ""
	return fragment


func _render_case_page() -> Page:
	var page: Page = PAGE_SCENE.instantiate()
	add_child_autofree(page)
	page.set_number(4)
	return page


func _count_seated_labels(page: Page) -> int:
	var count := 0
	for panel in page._slot_panels:
		for child in panel.get_children():
			if child is VBoxContainer:
				for label in child.get_children():
					if label is Label and label.text == "SEATED":
						count += 1
	return count


func test_case_page_renders_five_slots() -> void:
	var page := _render_case_page()
	assert_eq(page._slot_panels.size(), 5, "Case page should render five slots")


func test_empty_case_shows_no_seated_labels() -> void:
	var page := _render_case_page()
	assert_eq(_count_seated_labels(page), 0, "All slots should appear empty")


func test_fragment_id_maps_to_case_slot_index() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 0, ModelEnums.FragmentState.SEATED
	)
	var page := _render_case_page()
	assert_eq(_count_seated_labels(page), 1, "Slot 0 should show seated")


func test_fragment_seated_event_fills_exactly_one_matching_slot() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 2, ModelEnums.FragmentState.RELEASED
	)

	var received: Array = []
	EventBus.fragment_seated.connect(func(id: String, slot: int): received.append([id, slot]))

	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")

	assert_eq(received.size(), 1)
	assert_eq(received[0][0], "fragment_01")
	assert_eq(received[0][1], 2)

	var page := _render_case_page()
	assert_eq(_count_seated_labels(page), 1, "Exactly one slot should be seated")


func test_duplicate_fragment_seated_does_not_duplicate_records() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 0, ModelEnums.FragmentState.RELEASED
	)

	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")
	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")
	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")

	assert_eq(GameState.save_state.persistent.museum_entries.size(), 1)
	var page := _render_case_page()
	assert_eq(
		_count_seated_labels(page),
		1,
		"Duplicate portal completion must not duplicate the visual slot"
	)


func test_seated_slot_state_persists_after_save_load() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 1, ModelEnums.FragmentState.RELEASED
	)
	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")
	assert_true(SaveService.save_game().ok)

	GameState.initialize("test-player")
	SaveService.load_game()

	var page := _render_case_page()
	assert_eq(_count_seated_labels(page), 1, "Seated slot should persist after save/load")


func test_seated_slot_state_persists_after_loop_reset() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 3, ModelEnums.FragmentState.RELEASED
	)
	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")

	GameState.reset_loop_state()

	var page := _render_case_page()
	assert_eq(_count_seated_labels(page), 1, "Seated slot should persist after loop reset")


func test_gold_and_master_records_appear_as_museum_entries() -> void:
	# Fragment seating creates a MuseumEntry.
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment(
		"fragment_01", 0, ModelEnums.FragmentState.RELEASED
	)
	EventBus.portal_completed.emit("fragment_01", "entry_01", false, "A fragment.")

	assert_true(GameState.save_state.persistent.museum_entries.has("entry_01"))
	var entry: MuseumEntry = GameState.save_state.persistent.museum_entries["entry_01"]
	assert_eq(entry.artifact_id, "fragment_01")


func test_purple_and_below_records_appear_as_journal_entries() -> void:
	# Restore a blue/purple-and-below object.
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = "inst_001"
	inst.condition = 80.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.value = 100
	GameState.save_state.loop.inventory.append(inst.to_dictionary())

	EventBus.restoration_completed.emit("inst_001", 80.0, "soft_cloth")

	assert_true(GameState.save_state.persistent.journal_entries.has("tarnished_pendant"))
