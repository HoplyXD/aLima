extends GutTest
## The Perfect Loop finale (END-R3/R5 minimal slice): triggers when the fifth
## fragment seats, waits for the Portal flow to close, fires exactly once per
## save, and releases its clock pause on close.

const TEST_SAVE := "user://test_finale_save.json"
const TEST_TEMP := "user://test_finale_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("finale-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()


func after_each() -> void:
	# Drive any open finale to completion so state never leaks across tests.
	if FinaleService.is_finale_pending_or_running():
		PortalFlowController.flow_finished.emit("")
		for i in 12:
			if not FinaleService.is_finale_pending_or_running():
				break
			FinaleService.advance()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _seat_all_fragments() -> void:
	for fragment_id in GameState.save_state.persistent.fragments.keys():
		GameState.save_state.persistent.fragments[fragment_id].state = (
			ModelEnums.FragmentState.SEATED
		)


func test_finale_waits_for_portal_flow_then_opens() -> void:
	_seat_all_fragments()
	EventBus.fragment_seated.emit("fragment_05", 4)
	assert_true(FinaleService.is_finale_pending_or_running(), "finale is pending")
	assert_false(
		GameState.save_state.persistent.perfect_loop_completed, "flag waits for the finale itself"
	)
	PortalFlowController.flow_finished.emit("fragment_05")
	assert_true(FinaleService.is_finale_pending_or_running(), "finale overlay is up")
	assert_true(
		GameState.save_state.persistent.perfect_loop_completed, "the Perfect Loop is recorded"
	)
	assert_true(DayClock.has_pause_owner(DayClock.PAUSE_FINALE), "finale holds the clock")
	# Advance through every line, the end card, and the close.
	for i in 12:
		if not FinaleService.is_finale_pending_or_running():
			break
		FinaleService.advance()
	assert_false(FinaleService.is_finale_pending_or_running(), "finale closes")
	assert_false(DayClock.has_pause_owner(DayClock.PAUSE_FINALE), "clock pause released")


func test_finale_does_not_trigger_below_five_seats() -> void:
	_seat_all_fragments()
	GameState.save_state.persistent.fragments["fragment_03"].state = (
		ModelEnums.FragmentState.RELEASED
	)
	EventBus.fragment_seated.emit("fragment_05", 4)
	assert_false(FinaleService.is_finale_pending_or_running(), "four seats never start the finale")


func test_finale_fires_exactly_once() -> void:
	_seat_all_fragments()
	FinaleService.start_finale()
	assert_true(GameState.save_state.persistent.perfect_loop_completed)
	for i in 12:
		if not FinaleService.is_finale_pending_or_running():
			break
		FinaleService.advance()
	assert_false(FinaleService.is_finale_pending_or_running())
	# A reload or repeated seat event must never replay the finale.
	FinaleService.start_finale()
	assert_false(FinaleService.is_finale_pending_or_running(), "finale never re-fires")
	EventBus.fragment_seated.emit("fragment_01", 0)
	assert_false(FinaleService.is_finale_pending_or_running())
