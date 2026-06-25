extends GutTest
## Storage screen: pause ownership, choosing the restore target, and loading tools
## into the bench (max 5) through the UI seams.

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


func _add_restored_inventory(uid: String, template_id: String, value: int) -> void:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = template_id
	inst.state = ModelEnums.ObjState.CLEAN
	inst.condition = 90.0
	inst.value = value
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
	var inst := _tools.grant_tool("solvent")  # auto-equips onto the bench
	var screen := await _open_screen()
	assert_true(
		GameState.save_state.loop.workbench_tools.has(inst.uid), "a granted tool auto-equips"
	)

	screen.toggle_tool(inst.uid)
	assert_false(GameState.save_state.loop.workbench_tools.has(inst.uid), "toggling unloads it")

	screen.toggle_tool(inst.uid)
	assert_true(
		GameState.save_state.loop.workbench_tools.has(inst.uid), "toggling again reloads it"
	)


func test_auto_equip_never_loads_more_than_eight() -> void:
	for i in range(10):
		_tools.grant_tool("solvent")
	await _open_screen()
	assert_eq(
		GameState.save_state.loop.workbench_tools.size(), 8, "auto-equip caps the bench at eight"
	)


func test_open_renders_all_three_tabs_without_error() -> void:
	_add_inventory("art_1", "rusted_tin")  # artifact tab
	_add_inventory("quest_1", "auntie_photo_faded")  # key items (quest artifact)
	GameState.save_state.persistent.fragments["fragment_01"] = _released_fragment()

	var screen := await _open_screen()  # builds Artifacts / Tools / Key Items

	assert_true(screen.owns_pause(), "screen opened and rendered")


func test_sell_restored_artifact_credits_money_and_removes_it() -> void:
	GameState.save_state.loop.money = 100
	_add_restored_inventory("art_clean", "rusted_tin", 75)
	var screen := await _open_screen()

	screen.sell_artifact("art_clean")

	assert_eq(GameState.save_state.loop.money, 175, "sale credits the assessed value")
	assert_false(_inventory_has("art_clean"), "the sold artifact leaves storage")


func test_sell_ignores_unrestored_artifact() -> void:
	GameState.save_state.loop.money = 100
	_add_inventory("art_dirty", "rusted_tin")  # state DIRTY
	var screen := await _open_screen()

	screen.sell_artifact("art_dirty")

	assert_eq(GameState.save_state.loop.money, 100, "a dirty artifact cannot be quick-sold")
	assert_true(_inventory_has("art_dirty"), "it stays in storage")


func test_request_restore_sets_target_and_emits_signal() -> void:
	_add_inventory("art_1", "rusted_tin")
	var screen := await _open_screen()
	watch_signals(screen)

	screen.request_restore("art_1")

	assert_eq(GameState.save_state.loop.restore_target_uid, "art_1", "restore target is chosen")
	assert_signal_emitted_with_parameters(screen, "restore_requested", ["art_1"])


func test_drag_equip_then_unequip_via_drop_handlers() -> void:
	var inst := _tools.grant_tool("solvent")  # auto-equipped
	var screen := await _open_screen()
	_tools.remove_from_workbench(inst.uid)  # start unequipped to exercise the equip drop

	screen._on_equip_drop({"kind": "storage_tool", "uid": inst.uid, "from_equipped": false})
	assert_true(GameState.save_state.loop.workbench_tools.has(inst.uid), "dropping equips the tool")

	screen._on_unequip_drop({"kind": "storage_tool", "uid": inst.uid, "from_equipped": true})
	assert_false(
		GameState.save_state.loop.workbench_tools.has(inst.uid),
		"dragging out of the bench unequips"
	)


func test_tool_detail_lists_the_conditions_it_treats() -> void:
	var screen := await _open_screen()
	# solvent treats tape residue (an accretion) per the surface-condition catalog.
	var treated := screen._conditions_treated_by("solvent")
	assert_gt(treated.size(), 0, "solvent should treat at least one catalogued condition")
	var ids: Array = []
	for c in treated:
		ids.append((c as SurfaceCondition).id)
	assert_true(ids.has("tape_residue"), "solvent treats tape residue")


func _inventory_has(uid: String) -> bool:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return true
	return false


func _released_fragment() -> Fragment:
	var fragment := Fragment.new()
	fragment.id = "fragment_01"
	fragment.master_artifact_id = "master_artifact_demo"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = 0
	fragment.state = ModelEnums.FragmentState.RELEASED
	fragment.echo_set_ref = "demo_echo_set"
	return fragment
