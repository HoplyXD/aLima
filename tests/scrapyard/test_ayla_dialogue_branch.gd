extends GutTest

## Headless tests for the Ayla interaction branch: empty scrap -> dialogue,
## non-empty scrap -> hand-off.

const YARD_SCENE := preload("res://scenes/scrapyard/Scrapyard.tscn")

var _yard: Node3D


func before_each() -> void:
	GameState.initialize("ayla-branch-test")
	DayClock.reset()
	DayClock.seconds_per_hour = 1.0
	_yard = YARD_SCENE.instantiate()
	add_child_autofree(_yard)
	await wait_physics_frames(1)


func after_each() -> void:
	DayClock.reset()


func test_empty_scrap_opens_dialogue_not_handoff() -> void:
	GameState.save_state.loop.scrap_pool.clear()

	_yard._open_handoff()

	assert_true(_yard._dialogue_box.visible, "dialogue should open when scrap pool is empty")
	assert_false(
		_yard._handoff_screen.visible, "hand-off should stay closed when scrap pool is empty"
	)
	assert_true(_yard._overlay_open, "overlay mode should be active")


func test_non_empty_scrap_opens_handoff_not_dialogue() -> void:
	GameState.save_state.loop.scrap_pool = {"blue": 2, "green": 1}

	_yard._open_handoff()

	assert_false(_yard._dialogue_box.visible, "dialogue should not open when carrying scrap")
	assert_true(_yard._handoff_screen.visible, "hand-off should open when carrying scrap")
	assert_true(_yard._overlay_open, "overlay mode should be active")


func test_dialogue_uses_authored_yard_empty_lines() -> void:
	GameState.save_state.loop.scrap_pool.clear()
	var route := DataRepository.singleton().get_route("scavenger")
	assert_not_null(route, "scavenger route should exist")

	_yard._open_handoff()

	var lines: Array = _yard._dialogue_box._lines
	assert_gt(lines.size(), 0, "yard_empty should contain at least one line")
	var first: Variant = lines[0]
	assert_true(first is Dictionary or first is String, "authored line should be a dict or string")
