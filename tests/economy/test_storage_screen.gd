extends GutTest
## Storage screen: pause ownership, choosing the restore target, and loading tools
## into the bench (max 10) through the UI seams.

const SCREEN_SCENE := preload("res://scenes/ui/storage_screen.tscn")
const TEST_SAVE := "user://test_storage_save.json"
const TEST_TEMP := "user://test_storage_save.tmp"

var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("storage-player")
	GameState.new_run()
	_tools = ToolService.new(GameState, DataRepository.singleton())
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_inventory(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = template_id
	inst.state = ModelEnums.ObjState.DIRTY
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _open_screen() -> StorageScreen:
	var screen: StorageScreen = SCREEN_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.open()
	return screen


func test_open_requests_storage_pause() -> void:
	assert_false(DayClock.is_paused())
	var screen := await _open_screen()
	assert_true(screen.owns_pause())
	assert_true(DayClock.is_paused())


func test_close_releases_storage_pause() -> void:
	var screen := await _open_screen()
	screen.close()
	assert_false(screen.owns_pause())
	assert_false(DayClock.is_paused())


func test_select_artifact_sets_restore_target() -> void:
	_add_inventory("art_1", "rusted_tin")  # deliverable artifact
	var screen := await _open_screen()

	screen.select_artifact("art_1")

	assert_eq(GameState.save_state.loop.restore_target_uid, "art_1")


func test_toggle_tool_loads_and_unloads_bench() -> void:
	var inst := _tools.grant_tool("solvent")
	var screen := await _open_screen()

	screen.toggle_tool(inst.uid)
	assert_true(GameState.save_state.loop.workbench_tools.has(inst.uid), "tool loads into bench")

	screen.toggle_tool(inst.uid)
	assert_false(GameState.save_state.loop.workbench_tools.has(inst.uid), "second toggle unloads it")


func test_bench_load_respects_max_ten() -> void:
	var uids: Array[String] = []
	for i in range(11):
		uids.append(_tools.grant_tool("solvent").uid)
	var screen := await _open_screen()

	for uid in uids:
		screen.toggle_tool(uid)

	assert_eq(GameState.save_state.loop.workbench_tools.size(), 10, "never more than ten on the bench")


func test_open_renders_all_three_tabs_without_error() -> void:
	_add_inventory("art_1", "rusted_tin")  # artifact tab
	_add_inventory("quest_1", "auntie_photo_faded")  # key items (quest artifact)
	GameState.save_state.persistent.fragments["fragment_01"] = _released_fragment()

	var screen := await _open_screen()  # builds Artifacts / Tools / Key Items

	assert_true(screen.owns_pause(), "screen opened and rendered")


func _released_fragment() -> Fragment:
	var fragment := Fragment.new()
	fragment.id = "fragment_01"
	fragment.master_artifact_id = "master_artifact_demo"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = 0
	fragment.state = ModelEnums.FragmentState.RELEASED
	fragment.echo_set_ref = "demo_echo_set"
	return fragment
