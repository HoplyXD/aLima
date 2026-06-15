extends GutTest

## UI-level tests for the restoration screen: pause ownership, open/close, and
## basic input response.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")

var _shop: Node3D


func before_each() -> void:
	_shop = SHOP_SCENE.instantiate()
	add_child_autofree(_shop)
	await wait_physics_frames(1)
	DayClock.running = false
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()


func test_workbench_opens_restoration_screen_and_pauses_clock() -> void:
	DayClock.running = true
	DayClock.start_day(1)
	assert_true(_shop.is_day_running())

	var hud: ShopHud = _shop.get_node("HUD")
	hud.workbench_pressed.emit()
	await wait_physics_frames(1)

	var screen: RestorationScreen = _shop.get_node("RestorationScreen")
	assert_true(screen.visible, "Workbench opens the restoration screen")
	assert_true(DayClock.is_paused(), "Restoration screen pauses the clock")
	assert_false(_shop.is_day_running())


func test_closing_restoration_screen_releases_pause_ownership() -> void:
	DayClock.running = true
	DayClock.start_day(1)

	var hud: ShopHud = _shop.get_node("HUD")
	hud.workbench_pressed.emit()
	await wait_physics_frames(1)

	var screen: RestorationScreen = _shop.get_node("RestorationScreen")
	screen.close()
	await wait_physics_frames(1)

	assert_false(screen.visible)
	assert_false(DayClock.is_paused(), "Closing restoration releases pause ownership")
	assert_true(_shop.is_day_running())
