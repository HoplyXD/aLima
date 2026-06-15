extends GutTest

## Tests for the ScannerScreen UI: pause ownership, verdict selection, states,
## and that closing the scanner does not resume a clock paused by another owner.

const TEST_SAVE := "user://test_scanner_screen_save.json"
const TEST_TEMP := "user://test_scanner_screen_save.tmp"
const SCREEN_SCENE := preload("res://scenes/ui/scanner_screen.tscn")

var _screen: ScannerScreen


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("scanner-screen-test-player")
	GameState.set_debug_seed_override(5678)
	GameState.new_run()
	DayClock.reset()
	_screen = SCREEN_SCENE.instantiate()
	add_child_autofree(_screen)
	await wait_physics_frames(1)


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.close()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_instance(template_id: String, state: int) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = "ui_%s_01" % template_id
	inst.condition = 100.0 if state == ModelEnums.ObjState.CLEAN else 0.0
	inst.state = state
	inst.storage_cost = 1
	return inst


func test_screen_acquires_scanner_pause_on_open() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_screen.open(inst)
	await wait_physics_frames(1)
	assert_true(DayClock.is_paused())
	assert_true(DayClock.pause_owner_count() >= 1)


func test_screen_releases_only_its_pause_on_close() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	_screen.open(inst)
	await wait_physics_frames(1)
	assert_true(DayClock.is_paused())
	_screen.close()
	await wait_physics_frames(1)
	assert_true(DayClock.is_paused(), "Dialogue pause must remain after scanner closes")
	assert_eq(DayClock.pause_owner_count(), 1)
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)


func test_no_verdict_selected_initially() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_screen.open(inst)
	await wait_physics_frames(1)
	assert_eq(_screen.get_selected_verdict(), ModelEnums.Verdict.UNKNOWN)
	assert_true(_screen.get_confirm_button().disabled)


func test_all_four_verdict_buttons_can_be_selected() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_screen.open(inst)
	await wait_physics_frames(1)
	for verdict in [
		ModelEnums.Verdict.AUTHENTIC,
		ModelEnums.Verdict.REPLICA,
		ModelEnums.Verdict.MODIFIED,
		ModelEnums.Verdict.UNCERTAIN
	]:
		_screen.select_verdict(verdict)
		assert_eq(_screen.get_selected_verdict(), verdict)
		assert_false(_screen.get_confirm_button().disabled)


func test_confirm_stores_verdict_and_disables_confirm() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_screen.open(inst)
	await wait_physics_frames(1)
	_screen.select_verdict(ModelEnums.Verdict.MODIFIED)
	_screen.confirm_verdict()
	await wait_physics_frames(1)
	assert_true(_screen.get_confirm_button().disabled)
	var refreshed := ObjectInstance.from_dictionary(GameState.save_state.loop.inventory[0])
	assert_eq(refreshed.authenticity, ModelEnums.Verdict.MODIFIED)


func test_loading_success_and_error_states_render_safely() -> void:
	var clean := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_screen.open(clean)
	await wait_physics_frames(1)
	assert_true(_screen.get_status_label().text.length() > 0)
	assert_true(_screen.get_content().get_child_count() > 0)

	var missing := _make_instance("ghost_template", ModelEnums.ObjState.CLEAN)
	_screen.open(missing)
	await wait_physics_frames(1)
	assert_true(_screen.get_status_label().text.length() > 0)
	assert_false(_screen.get_verdict_section().visible)
