extends GutTest

## Travel system: data-driven destinations, recommendation marks, the generic
## SpaceManager.go_to transition, and the Day 0 journal finale graduation.

const TEST_SAVE := "user://test_travel_save.json"
const TEST_TEMP := "user://test_travel_save.tmp"

var _loaded_paths: Array[String] = []


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("travel-test-player")
	DayClock.reset()
	TutorialService.load_script_file()
	SpaceManager.current_space = SpaceManager.Space.SHOP
	SpaceManager._on_title = false
	SpaceManager.set_loader(_record_load)
	_loaded_paths.clear()


func after_each() -> void:
	SpaceManager.set_loader(Callable())
	SpaceManager.current_space = SpaceManager.Space.SHOP
	SpaceManager._on_title = true
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _record_load(path: String) -> void:
	_loaded_paths.append(path)


func test_destinations_load_from_data() -> void:
	var travel := TravelService.new()
	assert_eq(travel.destinations().size(), 2)
	assert_eq(travel.space_for("mall"), SpaceManager.Space.MALL)
	assert_eq(travel.space_for("shop"), SpaceManager.Space.YARD)
	assert_eq(travel.space_for("nowhere"), -1)


func test_available_excludes_the_current_space() -> void:
	var travel := TravelService.new()
	SpaceManager.current_space = SpaceManager.Space.MALL
	var available := travel.available_from(SpaceManager.current_space)
	for destination in available:
		assert_ne(str(destination.get("space")), "MALL")


func test_pending_meet_marks_the_destination() -> void:
	var travel := TravelService.new()
	assert_false(travel.is_recommended("mall"))
	GameState.save_state.loop.pending_meets.append(
		{"uid": "obj_x", "buyer_id": "collector", "price": 50, "destination_id": "mall"}
	)
	assert_true(travel.is_recommended("mall"))


func test_tutorial_step_marks_the_target_space() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.save_state.persistent.tutorial_step = "board_tricycle"
	var travel := TravelService.new()
	assert_true(travel.is_recommended("mall"), "The tutorial ride step points at the mall")


func test_go_to_mall_loads_the_mall_scene() -> void:
	watch_signals(SpaceManager)
	SpaceManager.go_to(SpaceManager.Space.MALL)
	assert_eq(SpaceManager.current_space, SpaceManager.Space.MALL)
	assert_eq(_loaded_paths, ["res://scenes/mall/Mall.tscn"] as Array[String])
	assert_signal_emitted(SpaceManager, "space_changed")
	# Duplicate transition is guarded.
	SpaceManager.go_to(SpaceManager.Space.MALL)
	assert_eq(_loaded_paths.size(), 1)


func test_finale_only_runs_on_the_journal_step() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.save_state.persistent.tutorial_step = "intro_greeting"
	assert_false(TutorialService.run_finale())


func test_finale_blackout_graduates_to_day1() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.new_run(4242)
	GameState.save_state.persistent.tutorial_step = "journal_finale"
	assert_true(TutorialService.run_finale())
	await wait_seconds(3.0)
	assert_true(
		GameState.save_state.persistent.tutorial_completed,
		"The blackout graduates the tutorial at full darkness"
	)
	assert_eq(SpaceManager.current_space, SpaceManager.Space.SHOP)
	assert_true(
		GameState.save_state.loop.tool_items.has("soft_cloth"),
		"Graduation granted the starting kit"
	)