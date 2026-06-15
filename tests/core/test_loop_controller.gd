extends GutTest

## Tests for LoopController (CLOCK-R2/R3, SAVE-R1/R2/R3, CLAUDE.md §4-A/B). Drives
## the DayClock autoload (to which LoopController is connected) through day closes
## and asserts the day/loop progression and the persistence split. Uses an
## isolated save path so it never touches the developer's real save.

const TEST_SAVE := "user://test_loop_save.json"
const TEST_TEMP := "user://test_loop_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("loop-test-player")
	GameState.set_debug_seed_override(4242)  # deterministic new_run seed
	DayClock.reset()
	DayClock.seconds_per_hour = 1.0


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


## Ticks well past the 13 in-game hours so the current day reaches its 20:00 close.
func _close_current_day() -> void:
	DayClock.tick(DayClock.seconds_per_hour * 14.0)


# --- Day progression ----------------------------------------------------------


func test_days_one_through_five_advance_then_reset() -> void:
	DayClock.start_day(1)
	assert_eq(DayClock.get_day(), 1)
	_close_current_day()
	assert_eq(DayClock.get_day(), 2)
	_close_current_day()
	assert_eq(DayClock.get_day(), 3)
	_close_current_day()
	assert_eq(DayClock.get_day(), 4)
	_close_current_day()
	assert_eq(DayClock.get_day(), 5)

	var loop_before := GameState.loop_index
	_close_current_day()  # Day 5 close -> loop reset
	assert_eq(DayClock.get_day(), 1)
	assert_eq(DayClock.get_hour(), 7)
	assert_eq(GameState.loop_index, loop_before + 1)


func test_normal_day_transition_mirrors_into_loop_state() -> void:
	DayClock.start_day(1)
	_close_current_day()
	assert_eq(GameState.save_state.loop.current_day, 2)
	assert_eq(GameState.save_state.loop.current_hour, 7)


func test_loop_reset_emitted_exactly_once() -> void:
	DayClock.start_day(5)
	watch_signals(EventBus)
	_close_current_day()
	assert_signal_emit_count(EventBus, "loop_reset", 1)
	assert_eq(DayClock.get_day(), 1)


# --- Persistence split (SAVE-R1/R2/R3) ---------------------------------------


func test_persistent_state_survives_reset() -> void:
	DayClock.start_day(5)
	var persistent := GameState.save_state.persistent
	persistent.techniques_learned.append("pendant_cleaning")
	persistent.spawn_history["fragment_01"] = [{"carrier_id": "obj_x", "container_id": "pile_left"}]
	var fragment := Fragment.new()
	fragment.id = "fragment_01"
	fragment.master_artifact_id = "master_artifact"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = 0
	fragment.state = ModelEnums.FragmentState.SEATED
	fragment.echo_set_ref = "demo_echo_set"
	persistent.fragments["fragment_01"] = fragment

	_close_current_day()

	var after := GameState.save_state.persistent
	assert_true(after.techniques_learned.has("pendant_cleaning"), "Techniques persist")
	assert_true(after.spawn_history.has("fragment_01"), "Spawn history persists (SAVE-R3)")
	assert_true(after.fragments.has("fragment_01"))
	assert_eq(
		after.fragments["fragment_01"].state,
		ModelEnums.FragmentState.SEATED,
		"A seated fragment never returns to RELEASED (SAVE-R2 / §4-B)"
	)


func test_every_loop_scoped_field_resets() -> void:
	DayClock.start_day(5)
	var loop := GameState.save_state.loop
	loop.money = 999
	loop.inventory.append({"uid": "obj_1"})
	loop.tool_items.append("soft_cloth")
	loop.temp_upgrades.append("upgrade_a")
	loop.marketplace_listings.append({"listing": 1})
	loop.pending_requests.append({"request": 1})
	loop.day_event_outcomes["event_a"] = "outcome_a"
	loop.current_delivery_ids.append("delivery_1")

	_close_current_day()

	var fresh := GameState.save_state.loop
	assert_eq(fresh.money, 0)
	assert_eq(fresh.inventory.size(), 0)
	assert_eq(fresh.tool_items.size(), 0)
	assert_eq(fresh.temp_upgrades.size(), 0)
	assert_eq(fresh.marketplace_listings.size(), 0)
	assert_eq(fresh.pending_requests.size(), 0)
	assert_eq(fresh.day_event_outcomes.size(), 0)
	assert_eq(fresh.current_delivery_ids.size(), 0)
	assert_eq(fresh.current_day, 1)
	assert_eq(fresh.current_hour, 7)


func test_loop_inventory_never_leaks_into_persistent() -> void:
	DayClock.start_day(5)
	GameState.save_state.loop.inventory.append({"uid": "obj_leak"})
	GameState.save_state.loop.money = 250
	_close_current_day()
	var persistent_dict := GameState.save_state.persistent.to_dictionary()
	assert_false(persistent_dict.has("inventory"), "Persistent state has no inventory partition")
	assert_false(persistent_dict.has("money"), "Persistent state has no money partition")


# --- Duplicate-signal robustness (P2.3) --------------------------------------


func test_repeated_close_signals_do_not_reset_twice() -> void:
	DayClock.start_day(5)
	var loop_before := GameState.loop_index
	_close_current_day()  # genuine close -> one reset; clock is now Day 1, not closed
	assert_eq(GameState.loop_index, loop_before + 1)

	# Stray duplicate signals after the reset (clock no longer closed) are ignored.
	DayClock.day_closed.emit(5)
	DayClock.day_closed.emit(5)
	assert_eq(GameState.loop_index, loop_before + 1, "Reset must run exactly once")

	# Continuing to tick into the new day must not trigger another reset.
	DayClock.tick(DayClock.seconds_per_hour * 5.0)
	assert_eq(GameState.loop_index, loop_before + 1)
