extends GutTest

## Tests for GameState: initialization, persistent/loop split, and reset.


func before_each() -> void:
	GameState.initialize("test-player")


func test_initializes_with_player_id() -> void:
	assert_eq(GameState.player_id, "test-player")
	assert_eq(GameState.loop_index, 0)


func test_persistent_and_loop_state_are_separate() -> void:
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")
	GameState.save_state.loop.money = 300
	assert_eq(GameState.save_state.persistent.techniques_learned.size(), 1)
	assert_eq(GameState.save_state.loop.money, 300)


func test_reset_loop_state_keeps_persistent() -> void:
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")
	GameState.save_state.loop.money = 300
	GameState.save_state.loop.current_day = 4
	GameState.reset_loop_state()
	assert_eq(GameState.save_state.persistent.techniques_learned.size(), 1)
	assert_eq(GameState.save_state.loop.money, 0)
	assert_eq(GameState.save_state.loop.current_day, 1)


func test_new_run_increments_loop_index_and_sets_seed() -> void:
	GameState.new_run(12345)
	assert_eq(GameState.loop_index, 1)
	assert_eq(GameState.run_seed, 12345)


func test_debug_seed_override_is_used() -> void:
	GameState.set_debug_seed_override(99999)
	GameState.new_run()
	assert_eq(GameState.run_seed, 99999)


func test_flashlight_resets_with_loop_state() -> void:
	GameState.save_state.loop.flashlight_on = true
	GameState.reset_loop_state()
	assert_false(GameState.save_state.loop.flashlight_on, "flashlight_on resets with LoopState")
