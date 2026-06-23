extends GutTest

## Tests for EventDirector's event queries, marketplace availability, and the
## brownout/flashlight/leak restoration-condition modifiers.

const TEST_SAVE := "user://test_event_director_save.json"
const TEST_TEMP := "user://test_event_director_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("event-director-player")
	GameState.new_run()
	EventDirector.enable_debug_force()


func after_each() -> void:
	EventDirector.disable_debug_force()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func test_marketplace_unavailable_during_brownout() -> void:
	assert_true(EventDirector.is_marketplace_available(), "marketplace is available normally")
	assert_true(EventDirector.force_event("sudden_brownout"), "brownout can be forced in tests")
	assert_false(EventDirector.is_marketplace_available(), "brownout knocks out the marketplace")


func test_brownout_multiplier_is_reduced_when_flashlight_off() -> void:
	assert_true(EventDirector.force_event("sudden_brownout"))
	GameState.save_state.loop.flashlight_on = false
	assert_eq(
		EventDirector.get_restoration_condition_multiplier(),
		0.8,
		"brownout penalty applies when flashlight is off"
	)


func test_brownout_multiplier_is_cancelled_when_flashlight_on() -> void:
	assert_true(EventDirector.force_event("sudden_brownout"))
	GameState.save_state.loop.flashlight_on = true
	assert_eq(
		EventDirector.get_restoration_condition_multiplier(),
		1.0,
		"flashlight cancels the brownout darkness penalty"
	)


func test_leak_multiplier_still_applies_when_flashlight_on() -> void:
	assert_true(EventDirector.force_event("rainy_day_leak"))
	GameState.save_state.loop.flashlight_on = true
	assert_eq(
		EventDirector.get_restoration_condition_multiplier(),
		0.8,
		"flashlight does not remove rainy-day leak/damp penalties"
	)


func test_brownout_and_leak_stack_to_the_strongest_penalty() -> void:
	assert_true(EventDirector.force_event("sudden_brownout"))
	assert_true(EventDirector.force_event("rainy_day_leak"))
	GameState.save_state.loop.flashlight_on = true
	assert_eq(
		EventDirector.get_restoration_condition_multiplier(),
		0.8,
		"leak penalty remains even when brownout penalty is cancelled"
	)


func test_light_source_active_reads_flashlight_state() -> void:
	GameState.save_state.loop.flashlight_on = false
	assert_false(EventDirector.is_light_source_active())
	GameState.save_state.loop.flashlight_on = true
	assert_true(EventDirector.is_light_source_active())
