extends GutTest
## Workbench loadout: at most 10 owned tools load into the bench, plus a selected
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


func test_add_to_workbench_enforces_max_ten() -> void:
	var uids := _grant(12)
	var loaded := 0
	for uid in uids:
		if _tools.add_to_workbench(uid):
			loaded += 1
	assert_eq(loaded, 10, "only ten tools fit on the bench")
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 10)


func test_set_workbench_keeps_at_most_ten_owned() -> void:
	var uids := _grant(12)
	var ok := _tools.set_workbench(uids)
	assert_false(ok, "set returns false when it had to drop overflow")
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 10)


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


func test_remove_and_restore_target() -> void:
	var uids := _grant(2)
	_tools.add_to_workbench(uids[0])
	_tools.add_to_workbench(uids[1])
	_tools.remove_from_workbench(uids[0])
	assert_eq(GameState.save_state.loop.workbench_tools.size(), 1)

	_tools.set_restore_target("obj_42")
	assert_eq(_tools.get_restore_target(), "obj_42")
