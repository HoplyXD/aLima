extends GutTest

## Pause-menu Skip Tutorial (TUT): visible only during Day 0, confirm-gated,
## and its end state matches playing Day 0 through (flags + starting kit +
## normal Day 1 session).

const TEST_SAVE := "user://test_pause_skip_save.json"
const TEST_TEMP := "user://test_pause_skip_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("pause-skip-test")
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()
	PauseMenu.close()
	SpaceManager.set_loader(Callable())
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _arm_fresh_save() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.new_run(4242)
	LoopController.begin_session()


func test_button_visible_only_during_day0() -> void:
	_arm_fresh_save()
	PauseMenu.open()
	assert_true(PauseMenu._skip_tutorial_button.visible, "Day 0 offers Skip Tutorial")
	PauseMenu.close()

	LoopController.complete_tutorial()
	PauseMenu.open()
	assert_false(
		PauseMenu._skip_tutorial_button.visible, "A graduated save never offers the skip"
	)


func test_button_press_asks_for_confirmation_first() -> void:
	_arm_fresh_save()
	PauseMenu.open()
	PauseMenu._on_skip_tutorial_pressed()
	assert_false(
		GameState.save_state.persistent.tutorial_completed,
		"Pressing the button alone must not skip; the confirm dialog decides"
	)


func test_confirmed_skip_matches_played_graduation() -> void:
	_arm_fresh_save()
	# Route SpaceManager through a no-op loader so the shop reload is harmless here.
	SpaceManager.set_loader(func(_path: String) -> void: pass)
	PauseMenu.open()
	PauseMenu._on_skip_tutorial_confirmed()

	assert_true(GameState.save_state.persistent.tutorial_completed)
	assert_eq(GameState.save_state.persistent.tutorial_step, "")
	assert_true(
		GameState.save_state.loop.tool_items.has("soft_cloth"),
		"Skip grants the same starting kit as playing Day 0"
	)
	assert_false(PauseMenu.is_open(), "The menu closes after skipping")
	assert_false(DayClock.has_pause_owner(DayClock.PAUSE_TUTORIAL))

	# The follow-up session is a normal Day 1.
	LoopController.begin_session()
	assert_true(DayClock.running)
	assert_eq(DayClock.get_day(), 1)
