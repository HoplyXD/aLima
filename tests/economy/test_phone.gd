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
	MarketplaceService._on_loop_reset(0)  # clear any buyer ghosts so tests don't pollute
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _open_phone() -> Phone:
	var phone: Phone = PHONE_SCENE.instantiate()
	add_child_autofree(phone)
	await wait_physics_frames(1)
	phone.open()
	return phone


func test_opens_on_home_without_pausing() -> void:
	# The phone no longer pauses the clock (only dialogue + the pause menu do), so time
	# keeps running while you browse and new buyers can arrive.
	assert_false(DayClock.is_paused())
	var phone := await _open_phone()
	assert_false(phone.owns_pause(), "the phone does not own a clock pause")
	assert_false(DayClock.is_paused(), "time keeps running while the phone is open")
	assert_eq(phone.get_current_app(), "", "phone opens on the home screen")


func test_open_and_back_to_home() -> void:
	var phone := await _open_phone()
	phone.open_app("marketplace")
	assert_eq(phone.get_current_app(), "marketplace")
	phone.show_home()
	assert_eq(phone.get_current_app(), "", "Home returns to the app grid")


func test_buying_in_tools_shop_app_deducts_and_ships() -> void:
	var phone := await _open_phone()
	phone.open_app("tools_shop")

	phone.buy("stain_lifter")  # cost 60, ship_hours 2

	assert_eq(GameState.save_state.loop.money, 240)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 1)
	assert_eq(_tools.get_owned_tools().size(), 0, "not delivered yet")


func test_close_leaves_clock_running() -> void:
	var phone := await _open_phone()
	phone.close()
	assert_false(phone.owns_pause())
	assert_false(DayClock.is_paused(), "the phone never paused the clock")


func _add_clean_item(uid: String, value: int = 200) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.condition = 85
	inst.state = ModelEnums.ObjState.CLEAN
	inst.value = value
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func test_marketplace_sell_flow_accepts_an_offer() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")
	var before := GameState.save_state.loop.money

	phone.accept_offer()

	assert_gt(GameState.save_state.loop.money, before, "accepting pays out")
	assert_eq(MarketplaceService.get_sellable().size(), 0, "the item was sold")


func test_marketplace_walk_keeps_the_item() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("reseller")

	phone.haggle_walk()

	assert_eq(MarketplaceService.get_sellable().size(), 1, "walking away keeps the item")
