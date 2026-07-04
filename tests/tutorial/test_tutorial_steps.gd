extends GutTest

## Day 0 step engine (TUT): authored completion signals advance exactly one
## step, grants hand over the condition-matched starter tools idempotently,
## and Ayla's sort is instant while the clock is frozen.

const TEST_SAVE := "user://test_tutorial_steps_save.json"
const TEST_TEMP := "user://test_tutorial_steps_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("tutorial-steps-test")
	DayClock.reset()
	TutorialService.load_script_file()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _arm_fresh_save() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.new_run(4242)
	LoopController.begin_session()


func test_scrap_handoff_completes_the_greeting_step() -> void:
	_arm_fresh_save()
	assert_eq(TutorialService.current_step_id(), "intro_greeting")
	EventBus.scrap_submitted.emit({"white": 1})
	assert_eq(TutorialService.current_step_id(), "head_inside")


func test_wrong_signal_does_not_advance() -> void:
	_arm_fresh_save()
	EventBus.triage_completed.emit([] as Array[String], [] as Array[String])
	assert_eq(TutorialService.current_step_id(), "intro_greeting")


func test_wrong_space_does_not_advance() -> void:
	_arm_fresh_save()
	TutorialService.advance_to("head_inside")
	SpaceManager.space_changed.emit(SpaceManager.Space.MALL)
	assert_eq(TutorialService.current_step_id(), "head_inside")


func test_signals_are_ignored_outside_the_tutorial() -> void:
	GameState.new_run(4242)
	var step_before := TutorialService.current_step_id()
	SpaceManager.space_changed.emit(SpaceManager.Space.YARD)
	assert_eq(TutorialService.current_step_id(), step_before)


func test_forage_and_triage_chain_grants_starter_tools() -> void:
	_arm_fresh_save()
	EventBus.scrap_submitted.emit({"white": 2})
	SpaceManager.space_changed.emit(SpaceManager.Space.SHOP)
	assert_eq(TutorialService.current_step_id(), "triage_delivery")

	assert_false(
		GameState.save_state.loop.tool_items.has("soft_brush"),
		"Starter tools arrive with the restoration step, not before"
	)
	EventBus.triage_completed.emit([] as Array[String], [] as Array[String])
	assert_eq(TutorialService.current_step_id(), "restoration_intro")
	assert_true(
		GameState.save_state.loop.tool_items.has("soft_brush"),
		"Dust's cleaning tool is handed over"
	)
	assert_true(
		GameState.save_state.loop.tool_items.has("damp_cloth"),
		"Grime's cleaning tool is handed over"
	)


func test_step_grants_are_idempotent_on_resume() -> void:
	_arm_fresh_save()
	TutorialService.advance_to("restoration_intro")
	LoopController.begin_session()  # re-entry re-applies grants
	var count := 0
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == "soft_brush":
			count += 1
	assert_eq(count, 1, "Re-applying a step's grants never duplicates a tool instance")


func test_full_signal_chain_reaches_the_finale() -> void:
	_arm_fresh_save()
	EventBus.scrap_submitted.emit({})  # grab scrap + hand to Ayla
	SpaceManager.space_changed.emit(SpaceManager.Space.SHOP)  # head inside
	EventBus.triage_completed.emit([] as Array[String], [] as Array[String])
	EventBus.restoration_opened.emit("uid_1")
	EventBus.restoration_completed.emit("uid_1", 1.0, "soft_brush")
	EventBus.scanner_verdict_committed.emit("uid_1", "AUTHENTIC")
	EventBus.meet_scheduled.emit("uid_1", "mysterious_buyer", "mall")
	assert_eq(TutorialService.current_step_id(), "ride_to_mall")
	SpaceManager.space_changed.emit(SpaceManager.Space.YARD)  # step outside
	assert_eq(TutorialService.current_step_id(), "board_tricycle")
	SpaceManager.space_changed.emit(SpaceManager.Space.MALL)  # ride out
	assert_eq(TutorialService.current_step_id(), "deliver_to_buyer")
	EventBus.meet_handoff_completed.emit("uid_1", "mysterious_buyer", 100, "mall")
	SpaceManager.space_changed.emit(SpaceManager.Space.YARD)  # ride home
	SpaceManager.space_changed.emit(SpaceManager.Space.SHOP)  # walk back in
	assert_eq(TutorialService.current_step_id(), "journal_finale")


func test_tutorial_sort_is_instant() -> void:
	_arm_fresh_save()
	GameState.save_state.loop.scrap_pool = {"white": 3}
	assert_true(AylaService.submit_scrap({"white": 2}))
	assert_true(AylaService.is_sort_ready(), "Day 0 sort completes immediately (0 hours)")


func test_normal_sort_still_takes_an_hour() -> void:
	GameState.new_run(4242)
	GameState.save_state.loop.scrap_pool = {"white": 3}
	assert_true(AylaService.submit_scrap({"white": 2}))
	assert_false(
		AylaService.is_sort_ready(),
		"Outside Day 0 the sort still needs the authored in-game hour"
	)
