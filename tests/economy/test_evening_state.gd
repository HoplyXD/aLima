extends GutTest
## EveningService: the mandatory end-of-day state (P14.5/P14.7, EVE-R1..R5, §4-N).
## Covers the day-close handoff, plan commit advancement, the Day 5 reset partition,
## and tool repair/replace upkeep. Drives the DayClock the same way the loop tests do.

const TEST_SAVE := "user://test_evening_save.json"
const TEST_TEMP := "user://test_evening_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("evening-player")
	GameState.set_debug_seed_override(777)
	DayClock.reset()
	DayClock.seconds_per_hour = 1.0
	EveningService.interactive = true


func after_each() -> void:
	EveningService.interactive = false
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _close_current_day() -> void:
	DayClock.tick(DayClock.seconds_per_hour * 14.0)


func _add_owned_tool(uid: String, tool_id: String, durability: int, max_durability: int) -> void:
	var inst := ToolInstance.new()
	inst.uid = uid
	inst.tool_id = tool_id
	inst.durability = durability
	inst.max_durability = max_durability
	GameState.save_state.loop.owned_tools.append(inst.to_dictionary())


func _owned_count(tool_id: String) -> int:
	var n := 0
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == tool_id:
			n += 1
	return n


# --- Day-close handoff (EVE-R1) ----------------------------------------------


func test_day_close_enters_evening_and_holds_advancement() -> void:
	DayClock.start_day(1)
	watch_signals(EventBus)
	_close_current_day()
	assert_true(EveningService.is_in_evening(), "the day closes into the evening state")
	assert_eq(EveningService.pending_day(), 1)
	assert_eq(DayClock.get_day(), 1, "the day does not advance until the evening is committed")
	assert_signal_emitted(EventBus, "evening_started")


func test_commit_plan_advances_the_day() -> void:
	DayClock.start_day(1)
	_close_current_day()
	watch_signals(EventBus)
	var result := EveningService.commit_plan("plan_rest")
	assert_true(result.ok)
	assert_false(EveningService.is_in_evening())
	assert_eq(DayClock.get_day(), 2, "committing the evening advances to the next day (EVE-R5)")
	assert_signal_emitted(EventBus, "evening_plan_committed")
	assert_eq(GameState.save_state.loop.evening_plan.get("plan_id"), "plan_rest")


func test_commit_is_idempotent() -> void:
	DayClock.start_day(1)
	_close_current_day()
	assert_true(EveningService.commit_plan("plan_rest").ok)
	assert_false(EveningService.commit_plan("plan_rest").ok, "a second commit is a no-op")


# --- Non-interactive mode keeps the old behaviour ----------------------------


func test_non_interactive_close_advances_inline() -> void:
	EveningService.interactive = false
	DayClock.start_day(1)
	_close_current_day()
	assert_false(EveningService.is_in_evening())
	assert_eq(DayClock.get_day(), 2, "headless/auto mode advances exactly as before")


# --- Day 5 reset partition (EVE-R5, SAVE-R7, §4-A) ---------------------------


func test_day5_commit_resets_loop_but_preserves_persistent() -> void:
	DayClock.start_day(5)
	GameState.save_state.loop.money = 500
	GameState.save_state.loop.disposition_log.append({"uid": "x", "disposition": "SELL"})
	GameState.save_state.loop.listings.append({"instance_uid": "x"})
	GameState.save_state.persistent.returns.append({"template_id": "rusted_tin"})
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")
	var loop_before := GameState.loop_index

	_close_current_day()
	assert_true(EveningService.is_in_evening(), "Day 5 also ends through the evening")
	EveningService.commit_plan("plan_rest")

	assert_eq(GameState.loop_index, loop_before + 1, "Day 5 commit performs the loop reset")
	assert_eq(DayClock.get_day(), 1)
	assert_eq(GameState.save_state.loop.money, 0, "loop money resets")
	assert_eq(
		GameState.save_state.loop.disposition_log.size(), 0, "loop disposition log clears (P14.6)"
	)
	assert_eq(GameState.save_state.loop.listings.size(), 0, "loop listings clear (P14.6)")
	assert_true(
		GameState.save_state.persistent.returns.size() >= 1, "returns persist across the reset"
	)
	assert_true(
		GameState.save_state.persistent.techniques_learned.has("pendant_cleaning"),
		"learned knowledge persists"
	)


# --- Upkeep: repair / replace (EVE-R3) ---------------------------------------


func test_repair_restores_durability_for_a_cost() -> void:
	_add_owned_tool("stain_lifter#1", "stain_lifter", 4, 10)
	GameState.save_state.loop.money = 100
	var needing := EveningService.tools_needing_upkeep()
	assert_eq(needing.size(), 1, "a worn finite tool needs upkeep")

	var result := EveningService.repair_tool("stain_lifter#1")
	assert_true(result.ok)
	assert_lt(GameState.save_state.loop.money, 100, "repair costs money")
	var repaired: ToolInstance = null
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == "stain_lifter#1":
			repaired = ToolInstance.from_dictionary(raw)
	assert_eq(repaired.durability, repaired.max_durability, "the tool is back to full durability")
	assert_eq(GameState.save_state.loop.upkeep_actions.size(), 1, "upkeep is logged for the summary")


func test_replace_swaps_a_broken_tool_for_a_fresh_one() -> void:
	_add_owned_tool("stain_lifter#1", "stain_lifter", 0, 10)  # broken
	GameState.save_state.loop.money = 100

	var result := EveningService.replace_tool("stain_lifter#1")
	assert_true(result.ok)
	assert_lt(GameState.save_state.loop.money, 100, "replacement costs money")
	assert_eq(_owned_count("stain_lifter"), 1, "the broken instance is swapped for one fresh one")
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == "stain_lifter":
			var fresh := ToolInstance.from_dictionary(raw)
			assert_eq(fresh.durability, fresh.max_durability, "the replacement is full durability")
			assert_ne(fresh.uid, "stain_lifter#1", "it is a new instance")
