extends GutTest
## Tests for BookViewport pause ownership and lifecycle.

const VIEWPORT_SCENE := preload("res://scenes/Book/BookViewport.tscn")


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()


func _open_viewport() -> BookViewport:
	var viewport: BookViewport = VIEWPORT_SCENE.instantiate()
	add_child_autofree(viewport)
	viewport.open()
	return viewport


func test_open_requests_journal_pause() -> void:
	assert_false(DayClock.is_paused(), "Clock starts unpaused")
	var viewport := _open_viewport()
	assert_true(viewport.owns_pause(), "Viewport should own the journal pause")
	assert_true(DayClock.is_paused(), "Clock should pause when journal opens")


func test_close_releases_journal_pause() -> void:
	var viewport := _open_viewport()
	assert_true(DayClock.is_paused())
	viewport.close()
	assert_false(DayClock.is_paused(), "Clock should resume when journal closes")
	assert_false(viewport.owns_pause(), "Viewport should no longer own pause")


func test_pause_composes_with_other_owners() -> void:
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	var viewport := _open_viewport()
	assert_true(DayClock.is_paused())
	assert_true(viewport.owns_pause())

	viewport.close()
	assert_true(DayClock.is_paused(), "Dialogue pause should survive journal close")
	assert_false(viewport.owns_pause())

	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
	assert_false(DayClock.is_paused())
