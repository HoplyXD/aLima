extends GutTest

## Tests for FragmentService (Phase 10): the LOCKED -> RELEASED transition, its
## idempotence, persistence + repo mirroring, and persistent -> repo sync. Seating
## (RELEASED -> SEATED) is owned by SeatingService and not retested here.

const TEST_SAVE := "user://test_fragment_service_save.json"
const TEST_TEMP := "user://test_fragment_service_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("fragment-service-test")


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	# release_fragment mirrors onto the repo; restore authored state so it never leaks.
	_repo.load_from_filesystem()


func test_fragment_01_starts_locked_from_authored_data() -> void:
	assert_true(FragmentService.is_locked("fragment_01"), "fragment_01 starts LOCKED (no handoff)")
	assert_false(FragmentService.is_released("fragment_01"))


func test_release_transitions_locked_to_released() -> void:
	watch_signals(EventBus)
	var ok := FragmentService.release_fragment("fragment_01", "test")
	assert_true(ok, "A locked fragment releases")
	assert_true(FragmentService.is_released("fragment_01"))
	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.RELEASED
	)
	assert_signal_emitted_with_parameters(EventBus, "fragment_released", ["fragment_01"])


func test_release_mirrors_state_onto_repo_for_spawn_director() -> void:
	FragmentService.release_fragment("fragment_01")
	# The Spawn Director reads repo state; the mirror keeps it consistent.
	assert_eq(_repo.get_fragment("fragment_01").state, ModelEnums.FragmentState.RELEASED)


func test_release_persists_across_reload() -> void:
	FragmentService.release_fragment("fragment_01")
	var loaded := SaveService.load_game()
	assert_true(loaded.ok)
	assert_true(FragmentService.is_released("fragment_01"), "Release survives a reload")


func test_release_is_idempotent() -> void:
	assert_true(FragmentService.release_fragment("fragment_01"))
	assert_false(
		FragmentService.release_fragment("fragment_01"),
		"Re-releasing a released fragment is a no-op"
	)


func test_seated_fragment_is_not_re_released() -> void:
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.SEATED
	)
	assert_false(
		FragmentService.release_fragment("fragment_01"), "A seated fragment never re-releases"
	)
	assert_true(FragmentService.is_seated("fragment_01"))


func test_unknown_fragment_release_is_safe() -> void:
	assert_false(FragmentService.release_fragment("fragment_does_not_exist"))


func test_sync_repo_from_persistent_reflects_runtime_state() -> void:
	GameState.save_state.persistent.fragments["fragment_02"].state = (
		ModelEnums.FragmentState.RELEASED
	)
	GameState.save_state.persistent.fragments["fragment_03"].state = (
		ModelEnums.FragmentState.SEATED
	)
	FragmentService.sync_repo_from_persistent()
	assert_eq(_repo.get_fragment("fragment_02").state, ModelEnums.FragmentState.RELEASED)
	assert_eq(_repo.get_fragment("fragment_03").state, ModelEnums.FragmentState.SEATED)
