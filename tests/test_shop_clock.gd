extends GutTest

## Integration tests for the Shop's clock PRESENTATION and dialogue pause ownership
## on top of the real DayClock. The clock simulation (progression, exactly-once
## transitions, 20:00 boundary, debug speed) is unit-tested in
## tests/core/test_day_clock.gd; the loop reset in tests/core/test_loop_controller.gd.
## Here we only verify the HUD reflects DayClock state and that dialogue freezes /
## resumes shop time through the DayClock pause-ownership API.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")

var _shop: Node3D
var _hud: ShopHud
var _clock: Label


func before_each() -> void:
	_shop = SHOP_SCENE.instantiate()
	add_child_autofree(_shop)
	await wait_physics_frames(1)
	_hud = _shop.get_node("HUD")
	_clock = _shop.get_node("%ClockLabel")
	# Disable the auto-driver so the display is exercised deterministically from
	# explicit DayClock.tick() calls rather than real-frame time.
	DayClock.running = false
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()


func test_starts_at_seven_am() -> void:
	_shop._update_clock_display()
	assert_eq(_clock.text, "7:00 AM")


func test_display_reflects_clock_minutes() -> void:
	DayClock.seconds_per_hour = 60.0
	DayClock.start_day(1)
	DayClock.tick(30.0)
	_shop._update_clock_display()
	assert_eq(_clock.text, "7:30 AM")
	DayClock.tick(30.0)
	_shop._update_clock_display()
	assert_eq(_clock.text, "8:00 AM")


func test_minute_progresses_through_single_minute_ticks() -> void:
	DayClock.seconds_per_hour = 60.0
	DayClock.start_day(1)
	for i in range(5):
		_shop._update_clock_display()
		assert_eq(_clock.text, "7:%02d AM" % i)
		DayClock.tick(1.0)
	_shop._update_clock_display()
	assert_eq(_clock.text, "7:05 AM")


func test_day_label_reflects_clock_day() -> void:
	DayClock.start_day(3)
	_shop._update_clock_display()
	var day_label: Label = _shop.get_node("%DayLabel")
	assert_eq(day_label.text, "Day 3 of 5")


func test_format_uses_am_pm() -> void:
	_hud.set_time(20, 30)
	assert_eq(_clock.text, "8:30 PM")
	_hud.set_time(12, 5)
	assert_eq(_clock.text, "12:05 PM")
	_hud.set_time(0, 0)
	assert_eq(_clock.text, "12:00 AM")
	_hud.set_time(7, 0)
	assert_eq(_clock.text, "7:00 AM")


func test_dialogue_pauses_and_resumes_via_pause_ownership() -> void:
	DayClock.running = true
	DayClock.start_day(1)
	assert_true(_shop.is_day_running(), "Clock runs when the shop opens")

	_shop._open_dialogue(["A quick test line."], false)
	await wait_physics_frames(1)
	assert_false(_shop.is_day_running(), "Dialogue freezes the clock")
	assert_true(DayClock.is_paused())

	_shop._on_dialogue_finished()
	assert_true(_shop.is_day_running(), "Clock resumes after dialogue")
	assert_false(DayClock.is_paused())
