extends GutTest

## Day 0 gating (TUT): a newly created save enters the clockless tutorial, a
## migrated/normal save never does, graduation lands on Day 1 of the same loop
## with the starting kit, and quitting mid-Day-0 resumes at the persisted step.

const TEST_SAVE := "user://test_tutorial_save.json"
const TEST_TEMP := "user://test_tutorial_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("tutorial-test-player")
	DayClock.reset()
	DayClock.seconds_per_hour = 1.0
	TutorialService.load_script_file()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


## Puts the in-memory save into the newly-created-file state the title screen arms.
func _arm_fresh_save() -> void:
	GameState.save_state.persistent.player_name = "Tester"
	GameState.save_state.persistent.tutorial_completed = false
	GameState.new_run(4242)


func test_initialize_defaults_to_no_tutorial() -> void:
	assert_false(
		TutorialService.is_tutorial_active(),
		"Plain sessions/tests default to normal play; only New Game arms Day 0"
	)


func test_fresh_save_enters_day0_with_frozen_clock() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	assert_false(DayClock.running, "Day 0 never starts the clock")
	assert_true(DayClock.has_pause_owner(DayClock.PAUSE_TUTORIAL), "Tutorial pause is held")
	assert_eq(
		GameState.save_state.persistent.tutorial_step,
		TutorialService.first_step_id(),
		"A fresh save starts on the first authored step"
	)
	DayClock.tick(1000.0)
	assert_eq(DayClock.get_day(), 1, "Ticks can never advance a Day 0 clock")
	assert_false(DayClock.is_closed())


func test_begin_session_is_idempotent_during_day0() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	TutorialService.advance()
	var step := TutorialService.current_step_id()
	LoopController.begin_session()
	assert_eq(TutorialService.current_step_id(), step, "Re-entry keeps the persisted step")


func test_completed_save_starts_the_normal_day_loop() -> void:
	GameState.new_run(4242)
	LoopController.begin_session()
	assert_true(DayClock.running, "Normal sessions start the clock exactly as before")
	assert_eq(DayClock.get_day(), 1)
	assert_eq(DayClock.get_hour(), 7)


func test_advance_to_persists_step_across_reload() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	TutorialService.advance_to("triage_delivery")
	# Simulate quit + relaunch: fresh state, then load the slot.
	GameState.initialize("someone-else")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, load_result.get("error", ""))
	assert_true(TutorialService.is_tutorial_active(), "Mid-Day-0 save resumes the tutorial")
	assert_eq(GameState.save_state.persistent.tutorial_step, "triage_delivery")
	LoopController.begin_session()
	assert_eq(
		TutorialService.current_step_id(),
		"triage_delivery",
		"begin_session resumes the persisted step, not the first one"
	)


func test_advance_to_rejects_unknown_step() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	var before := TutorialService.current_step_id()
	TutorialService.advance_to("nonsense_step")
	assert_eq(TutorialService.current_step_id(), before)


func test_step_order_follows_authored_script() -> void:
	assert_eq(TutorialService.first_step_id(), "intro_greeting")
	assert_eq(TutorialService.next_step_id("intro_greeting"), "head_inside")
	assert_eq(TutorialService.next_step_id("journal_finale"), "", "Last step has no successor")
	assert_eq(TutorialService.next_step_id("bogus"), "")


func test_complete_tutorial_graduates_to_day1_same_loop() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	GameState.save_state.loop.money = 999  # Day 0 earnings are wiped by graduation
	var loop_before := GameState.loop_index
	watch_signals(EventBus)
	LoopController.complete_tutorial()

	assert_true(GameState.save_state.persistent.tutorial_completed)
	assert_eq(GameState.save_state.persistent.tutorial_step, "")
	assert_eq(GameState.loop_index, loop_before, "Graduation stays on the same first loop")
	assert_eq(GameState.save_state.loop.money, 0, "Loop-scoped Day 0 state is cleared")
	assert_false(DayClock.has_pause_owner(DayClock.PAUSE_TUTORIAL))
	assert_signal_emit_count(EventBus, "loop_reset", 1)
	assert_true(
		GameState.save_state.loop.tool_items.has("soft_cloth"),
		"Graduation grants the normal starting kit"
	)
	assert_true(FileAccess.file_exists(TEST_SAVE), "Graduation saves atomically")

	# The next session is a normal Day 1.
	LoopController.begin_session()
	assert_true(DayClock.running)
	assert_eq(DayClock.get_day(), 1)
	assert_eq(DayClock.get_hour(), 7)


func test_complete_tutorial_is_idempotent() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	LoopController.complete_tutorial()
	watch_signals(EventBus)
	LoopController.complete_tutorial()
	assert_signal_emit_count(EventBus, "loop_reset", 0, "A second graduation is a no-op")


func test_skip_uses_the_same_graduation_path() -> void:
	_arm_fresh_save()
	LoopController.begin_session()
	watch_signals(TutorialService)
	TutorialService.skip()
	assert_true(GameState.save_state.persistent.tutorial_completed)
	assert_signal_emit_count(TutorialService, "tutorial_finished", 1)
	assert_true(GameState.save_state.loop.tool_items.has("soft_cloth"))


func test_day5_loop_reset_still_works_after_graduation() -> void:
	GameState.new_run(4242)
	LoopController.begin_session()
	DayClock.start_day(5)
	var loop_before := GameState.loop_index
	DayClock.tick(DayClock.seconds_per_hour * 14.0)
	assert_eq(DayClock.get_day(), 1, "Day 5 close still loops back to Day 1")
	assert_eq(GameState.loop_index, loop_before + 1)
	assert_true(
		GameState.save_state.persistent.tutorial_completed,
		"Loop reset never re-arms Day 0"
	)
