extends GutTest

## Tests for the ShowcaseScreen (Phase 10, P10.3): the scripted photograph showcase
## records the beat through RouteService (never granting a fragment itself) and the
## final beat releases the route fragment. Also covers pause ownership.

const TEST_SAVE := "user://test_showcase_save.json"
const TEST_TEMP := "user://test_showcase_save.tmp"

var _repo: DataRepository
var _screen: ShowcaseScreen


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("showcase-test")
	RouteService._visit_log.clear()
	_screen = ShowcaseScreen.new()
	add_child_autofree(_screen)


func after_each() -> void:
	if _screen != null and _screen.is_open():
		_screen.close()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	_repo.load_from_filesystem()


func _auntie() -> CharacterRoute:
	return _repo.get_route("auntie")


func _run_to_completion() -> void:
	# The showcase has three steps; advancing past the last records the beat + closes.
	_screen.advance()
	_screen.advance()
	_screen.advance()


func test_open_pauses_shop_time() -> void:
	var route := _auntie()
	_screen.open(route, route.beats[0])
	assert_true(_screen.is_open())
	assert_true(DayClock.has_pause_owner(DayClock.PAUSE_SHOWCASE), "Showcase freezes shop time")
	_screen.close()
	assert_false(DayClock.has_pause_owner(DayClock.PAUSE_SHOWCASE), "Closing releases the pause")


func test_first_beat_records_but_does_not_release() -> void:
	watch_signals(EventBus)
	var route := _auntie()
	_screen.open(route, route.beats[0])
	_run_to_completion()

	assert_true(RouteService.is_beat_complete("auntie_beat_1"))
	assert_signal_emitted_with_parameters(
		EventBus, "route_beat_completed", ["auntie", "auntie_beat_1"]
	)
	assert_true(
		FragmentService.is_locked("fragment_01"), "An early beat never releases the fragment"
	)
	assert_false(_screen.is_open(), "The showcase closes after the final step")


func test_final_beat_releases_fragment_through_route_not_handoff() -> void:
	watch_signals(EventBus)
	# Complete the gating beats first, then run the final showcase.
	RouteService.complete_beat("auntie", "auntie_beat_1")
	RouteService.complete_beat("auntie", "auntie_beat_2")
	var route := _auntie()
	_screen.open(route, route.beats[2])
	_screen.beat_completed.connect(func(_r: String, _b: String) -> void: pass)
	_run_to_completion()

	assert_true(RouteService.is_beat_complete("auntie_beat_3"))
	assert_true(FragmentService.is_released("fragment_01"), "The final beat releases the fragment")
	assert_signal_emitted_with_parameters(EventBus, "fragment_released", ["fragment_01"])
	# The fragment is released into the scrap stream, not placed in inventory here.
	assert_eq(GameState.save_state.loop.inventory.size(), 0, "No fragment is handed to the player")
