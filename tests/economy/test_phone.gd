extends GutTest
## The phone scene: home/app navigation, pause ownership, and buying through the
## Marketplace app.

const PHONE_SCENE := preload("res://scenes/ui/phone.tscn")
const TEST_SAVE := "user://test_phone_save.json"
const TEST_TEMP := "user://test_phone_save.tmp"

var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("phone-player")
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


func _open_phone() -> Phone:
	var phone: Phone = PHONE_SCENE.instantiate()
	add_child_autofree(phone)
	await wait_physics_frames(1)
	phone.open()
	return phone


func test_opens_on_home_and_pauses() -> void:
	assert_false(DayClock.is_paused())
	var phone := await _open_phone()
	assert_true(phone.owns_pause())
	assert_true(DayClock.is_paused())
	assert_eq(phone.get_current_app(), "", "phone opens on the home screen")


func test_open_and_back_to_home() -> void:
	var phone := await _open_phone()
	phone.open_app("marketplace")
	assert_eq(phone.get_current_app(), "marketplace")
	phone.show_home()
	assert_eq(phone.get_current_app(), "", "Home returns to the app grid")


func test_buying_in_marketplace_app_deducts_and_ships() -> void:
	var phone := await _open_phone()
	phone.open_app("marketplace")

	phone.buy("stain_lifter")  # cost 60, ship_hours 2

	assert_eq(GameState.save_state.loop.money, 240)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 1)
	assert_eq(_tools.get_owned_tools().size(), 0, "not delivered yet")


func test_close_releases_pause() -> void:
	var phone := await _open_phone()
	phone.close()
	assert_false(phone.owns_pause())
	assert_false(DayClock.is_paused())
