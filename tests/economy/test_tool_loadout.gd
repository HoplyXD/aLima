extends GutTest
## Workbench loadout: at most 5 owned tools load into the bench, plus a selected
## restore target.

const TEST_SAVE := "user://test_loadout_save.json"
const TEST_TEMP := "user://test_loadout_save.tmp"

var _repo: DataRepository
var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("loadout-player")
	GameState.new_run()
	_tools = ToolService.new(GameState, _repo)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant(n: int) -> Array[String]:
	var uids: Array[String] = []
	for i in range(n):
		uids.append(_tools.grant_tool("solvent").uid)
	return uids


func test_add_to_workbench_enforces_max_eight() -> void:
	var uids := _grant(10)
	var loaded := 0
	for uid in uids:
		if _tools.add_to_workbench(uid):
			loaded += 1
	assert_eq(loaded, 8, "only eight tools fit on the bench")
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 8)


func test_set_workbench_keeps_at_most_eight_owned() -> void:
	var uids := _grant(10)
	var ok := _tools.set_workbench(uids)
	assert_false(ok, "set returns false when it had to drop overflow")
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 8)


func test_cannot_load_unowned_tool() -> void:
	assert_false(_tools.add_to_workbench("ghost#999"))
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 0)


func test_loadout_returns_usable_loaded_instances() -> void:
	var uids := _grant(3)
	for uid in uids:
		_tools.add_to_workbench(uid)
	assert_eq(_tools.get_workbench_loadout().size(), 3)

	# Break one; it drops out of the usable loadout.
	for raw in GameState.save_state.loop.owned_tools:
		if raw.get("uid") == uids[0]:
			raw["durability"] = 0
	assert_eq(_tools.get_workbench_loadout().size(), 2)


# Tools auto-equip on grant, so these slot tests set the bench explicitly for a
# deterministic starting layout (the granted tools stay owned either way).
func _set_bench(uids: Array) -> void:
	var typed: Array[String] = []
	for u in uids:
		typed.append(ModelUtils.as_string(u))
	GameState.save_state.loop.workbench_tools = typed


func test_equip_to_empty_slot_pins_to_that_slot() -> void:
	var uids := _grant(2)
	_set_bench([])
	assert_true(_tools.equip_to_slot(uids[0], 0))
	assert_true(_tools.equip_to_slot(uids[1], 3))  # pinned to slot 3, slots 1-2 stay empty
	assert_eq(GameState.save_state.loop.workbench_tools, [uids[0], "", "", uids[1]])


func test_equip_to_occupied_slot_replaces_only_that_tool() -> void:
	var uids := _grant(3)
	var replacement := _tools.grant_tool("solvent").uid
	_set_bench([uids[0], uids[1], uids[2]])  # replacement is owned but off the bench

	# Drop the replacement onto slot 1: only slot 1 changes, the rest stay put.
	assert_true(_tools.equip_to_slot(replacement, 1))
	assert_eq(GameState.save_state.loop.workbench_tools, [uids[0], replacement, uids[2]])


func test_replacing_on_a_full_bench_keeps_it_full() -> void:
	var uids := _grant(8)
	var replacement := _tools.grant_tool("solvent").uid
	_set_bench(uids)  # bench full; replacement owned but unequipped

	assert_true(_tools.equip_to_slot(replacement, 2), "dropping onto an occupied slot replaces it")
	var wb: Array = GameState.save_state.loop.workbench_tools
	assert_eq(wb.size(), 8, "bench stays full, nothing else dropped off")
	assert_eq(wb[2], replacement)
	assert_false(wb.has(uids[2]), "the displaced tool left the bench")


func test_equip_to_slot_swaps_two_equipped_tools() -> void:
	var uids := _grant(3)
	_set_bench([uids[0], uids[1], uids[2]])

	assert_true(_tools.equip_to_slot(uids[2], 0))  # move slot-2 tool onto slot 0
	assert_eq(GameState.save_state.loop.workbench_tools, [uids[2], uids[1], uids[0]])


func test_equip_to_slot_rejects_unowned_tool() -> void:
	assert_false(_tools.equip_to_slot("ghost#999", 0))
	assert_false(GameState.save_state.loop.workbench_tools.has("ghost#999"))


func test_remove_and_restore_target() -> void:
	var uids := _grant(2)
	_tools.add_to_workbench(uids[0])
	_tools.add_to_workbench(uids[1])
	_tools.remove_from_workbench(uids[0])
	# Slot 0 is now empty but slot 1 keeps its tool (fixed slots, no shift-left).
	assert_eq(GameState.save_state.loop.workbench_tools, ["", uids[1]])

	_tools.set_restore_target("obj_42")
	assert_eq(_tools.get_restore_target(), "obj_42")
