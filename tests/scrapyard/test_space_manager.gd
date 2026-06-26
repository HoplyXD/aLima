extends GutTest

## Headless tests for the SpaceManager two-space transition state machine.
##
## All real scene loads are replaced with a recording stub so the suite exercises
## state transitions, the single-loaded invariant, and clock continuity without
## loading actual scenes.

const SpaceManagerScript := preload("res://scripts/core/space_manager.gd")

var _manager: SpaceManager
var _loaded_paths: Array[String]


func before_each() -> void:
	# Reset the production autoload to a known state and give it a fake loader.
	SpaceManager.current_space = SpaceManager.Space.SHOP
	SpaceManager._on_title = true
	SpaceManager.set_loader(_record_load)
	_loaded_paths.clear()

	# The clock must be clean so clock-continuity assertions are meaningful.
	DayClock.reset()
	DayClock.seconds_per_hour = 1.0


func after_each() -> void:
	SpaceManager.set_loader(Callable())
	DayClock.reset()


func test_initial_state_is_shop_on_title() -> void:
	assert_eq(SpaceManager.current_space, SpaceManager.Space.SHOP, "default space is shop")


func test_go_to_yard_loads_yard_scene() -> void:
	SpaceManager.go_to_yard()
	assert_eq(SpaceManager.current_space, SpaceManager.Space.YARD)
	assert_eq(_loaded_paths.size(), 1)
	assert_eq(_loaded_paths[0], SpaceManager.YARD_SCENE)


func test_go_to_shop_from_yard_loads_shop_scene() -> void:
	SpaceManager.go_to_yard()
	_loaded_paths.clear()
	SpaceManager.go_to_shop()
	assert_eq(SpaceManager.current_space, SpaceManager.Space.SHOP)
	assert_eq(_loaded_paths.size(), 1)
	assert_eq(_loaded_paths[0], SpaceManager.SHOP_SCENE)


func test_duplicate_yard_transition_is_guarded() -> void:
	SpaceManager.go_to_yard()
	_loaded_paths.clear()
	SpaceManager.go_to_yard()
	assert_eq(SpaceManager.current_space, SpaceManager.Space.YARD)
	assert_eq(_loaded_paths.size(), 0, "duplicate yard transition is rejected")


func test_duplicate_shop_transition_from_game_is_guarded() -> void:
	SpaceManager.go_to_yard()
	SpaceManager.go_to_shop()
	_loaded_paths.clear()
	SpaceManager.go_to_shop()
	assert_eq(SpaceManager.current_space, SpaceManager.Space.SHOP)
	assert_eq(_loaded_paths.size(), 0, "duplicate shop transition is rejected")


func test_return_to_title_loads_title_and_resets_clock() -> void:
	SpaceManager.go_to_yard()
	DayClock.running = true
	_loaded_paths.clear()
	SpaceManager.return_to_title()
	assert_eq(_loaded_paths.size(), 1)
	assert_eq(_loaded_paths[0], SpaceManager.TITLE_SCENE)
	assert_false(DayClock.running, "returning to title stops the clock")
	assert_eq(DayClock.get_day(), 1)
	assert_eq(DayClock.get_hour(), 7)


func test_clock_keeps_running_across_transition() -> void:
	DayClock.start_day(1)
	DayClock.running = true
	var owners_before := DayClock.pause_owner_count()
	var hour_before := DayClock.get_hour()

	SpaceManager.go_to_yard()

	assert_eq(DayClock.pause_owner_count(), owners_before, "transition never requests a pause")
	assert_true(DayClock.running, "clock stays running after transitioning to yard")
	DayClock.tick(DayClock.seconds_per_hour)
	assert_eq(DayClock.get_hour(), hour_before + 1, "clock advances across the transition")


func _record_load(path: String) -> void:
	_loaded_paths.append(path)
