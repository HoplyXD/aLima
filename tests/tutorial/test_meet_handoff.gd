extends GutTest

## Meet-to-collect sales (TUT / meet-to-sell groundwork): a Day 0 sale defers
## payment into loop.pending_meets, the handoff pays exactly once, and normal
## (non-tutorial) sales are untouched.

const TEST_SAVE := "user://test_meet_save.json"
const TEST_TEMP := "user://test_meet_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("meet-test-player")
	DayClock.reset()
	TutorialService.load_script_file()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_restored_item(uid: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.state = ModelEnums.ObjState.CLEAN
	inst.condition = 100.0
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func test_tutorial_sale_defers_payment_to_the_meet() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	_add_restored_item("obj_meet_1")
	watch_signals(EventBus)

	var result := MarketplaceService.complete_sale("obj_meet_1", 120, "mysterious_buyer")
	assert_true(result.ok, result.get("error", ""))
	assert_true(result.get("meet_required", false))
	assert_eq(result.get("destination_id"), "mall")
	assert_eq(GameState.save_state.loop.money, 0, "Payment waits for the handoff")
	assert_eq(MarketplaceService.pending_meets_for("mall").size(), 1)
	assert_signal_emit_count(EventBus, "meet_scheduled", 1)
	assert_signal_emit_count(EventBus, "sale_completed", 0)

	var handoff := MarketplaceService.complete_meet_handoff("obj_meet_1")
	assert_true(handoff.ok)
	assert_eq(GameState.save_state.loop.money, 120)
	assert_eq(MarketplaceService.pending_meets_for("mall").size(), 0)
	assert_signal_emit_count(EventBus, "sale_completed", 1)
	assert_signal_emit_count(EventBus, "meet_handoff_completed", 1)

	# A second handoff for the same uid is a no-op.
	var again := MarketplaceService.complete_meet_handoff("obj_meet_1")
	assert_false(again.ok)
	assert_eq(GameState.save_state.loop.money, 120)


func test_normal_sale_still_pays_immediately() -> void:
	_add_restored_item("obj_meet_2")
	watch_signals(EventBus)
	var result := MarketplaceService.complete_sale("obj_meet_2", 90, "collector")
	assert_true(result.ok, result.get("error", ""))
	assert_false(result.get("meet_required", false))
	assert_eq(GameState.save_state.loop.money, 90)
	assert_signal_emit_count(EventBus, "sale_completed", 1)


func test_pending_meets_survive_a_save_round_trip() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	_add_restored_item("obj_meet_3")
	MarketplaceService.complete_sale("obj_meet_3", 75, "mysterious_buyer")

	GameState.initialize("someone-else")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, load_result.get("error", ""))
	assert_eq(MarketplaceService.pending_meets_for("mall").size(), 1)


func test_loop_reset_clears_pending_meets() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	_add_restored_item("obj_meet_4")
	MarketplaceService.complete_sale("obj_meet_4", 75, "mysterious_buyer")
	GameState.reset_loop_state()
	assert_eq(MarketplaceService.pending_meets_for("mall").size(), 0)
