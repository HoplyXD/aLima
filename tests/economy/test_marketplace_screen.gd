extends GutTest
## The phone Marketplace screen: pause ownership and buying through the UI seam.

const SCREEN_SCENE := preload("res://scenes/ui/marketplace_screen.tscn")
const TEST_SAVE := "user://test_market_screen_save.json"
const TEST_TEMP := "user://test_market_screen_save.tmp"

var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("market-screen-player")
	GameState.new_run()
	GameState.save_state.loop.money = 300
	GameState.save_state.loop.current_day = 1
	GameState.save_state.loop.current_hour = 7
	_tools = ToolService.new(GameState, DataRepository.singleton())
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _open_screen() -> MarketplaceScreen:
	var screen: MarketplaceScreen = SCREEN_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(1)
	screen.open()
	return screen


func test_open_requests_phone_pause() -> void:
	assert_false(DayClock.is_paused())
	var screen := await _open_screen()
	assert_true(screen.owns_pause(), "screen should own the phone pause")
	assert_true(DayClock.is_paused(), "shop time pauses while the phone is open")


func test_close_releases_phone_pause() -> void:
	var screen := await _open_screen()
	screen.close()
	assert_false(screen.owns_pause())
	assert_false(DayClock.is_paused())


func test_buying_through_the_screen_deducts_money_and_ships() -> void:
	var screen := await _open_screen()

	screen.buy("stain_lifter")  # cost 60, ship_hours 2

	assert_eq(GameState.save_state.loop.money, 240)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 1)
	# Not delivered yet.
	assert_eq(_tools.get_owned_tools().size(), 0)


func test_phone_pause_composes_with_dialogue() -> void:
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	var screen := await _open_screen()
	screen.close()
	assert_true(DayClock.is_paused(), "dialogue pause survives the phone closing")
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
	assert_false(DayClock.is_paused())
