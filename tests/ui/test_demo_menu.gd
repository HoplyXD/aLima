extends GutTest

## Tests for the DemoMenu (Phase 10, P10.6): seed selection, debug fragment release
## through the real Spawn Director, the three-seed placement demo, and the two-step
## save-clear confirmation. These controls are debug-only and edit no production data.

const TEST_SAVE := "user://test_demo_menu_save.json"
const TEST_TEMP := "user://test_demo_menu_save.tmp"

var _repo: DataRepository
var _menu: DemoMenu


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("demo-menu-test")
	_menu = DemoMenu.new()
	add_child_autofree(_menu)


func after_each() -> void:
	if _menu != null and _menu.visible:
		_menu.close()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	_repo.load_from_filesystem()


func test_apply_seed_sets_debug_override() -> void:
	_menu.open()
	_menu._seed_field.text = "54321"
	_menu.apply_seed()
	assert_eq(GameState.debug_seed_override, 54321)


func test_release_route_fragment_uses_spawn_director() -> void:
	_menu.open()
	var plan := _menu.release_route_fragment()
	assert_true(FragmentService.is_released("fragment_01"), "Debug release frees the fragment")
	assert_false(plan.is_empty(), "The Spawn Director produced a placement")
	assert_false(plan.get("carrier_template_id", "").is_empty(), "Placed inside a promoted carrier")


func test_placement_demo_returns_three_variations() -> void:
	_menu.open()
	var logs := _menu.run_placement_demo()
	assert_eq(logs.size(), 3, "Three seeded placements are produced")
	for log in logs:
		assert_false(str(log.get("selected_carrier_template", "")).is_empty())
		assert_false(str(log.get("selected_container", "")).is_empty())


func test_clear_save_requires_two_presses() -> void:
	_menu.open()
	assert_false(_menu._clear_armed)
	_menu.request_clear_save()
	assert_true(_menu._clear_armed, "First press arms the clear")
	_menu.request_clear_save()
	assert_false(_menu._clear_armed, "Second press confirms and disarms")


func test_open_and_close_manage_pause() -> void:
	_menu.open()
	assert_true(DayClock.has_pause_owner(DayClock.PAUSE_DEMO))
	_menu.close()
	assert_false(DayClock.has_pause_owner(DayClock.PAUSE_DEMO))
