extends GutTest

## Focused tests for the placeholder Shop clock's minute-level display.
## Covers: H:MM AM/PM formatting, minute progression derived from seconds_per_hour,
## dialogue pause/resume without skipping elapsed partial-hour time, and the
## existing day/loop wrap behavior.

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
	# Stop automatic _process so tests can tick the clock deterministically.
	_shop.set_process(false)


func test_starts_at_seven_am() -> void:
	assert_eq(_clock.text, "7:00 AM")


func test_minute_progression_at_default_rate() -> void:
	_shop.seconds_per_hour = 60.0
	_shop._advance_clock(30.0)
	assert_eq(_clock.text, "7:30 AM")
	_shop._advance_clock(30.0)
	assert_eq(_clock.text, "8:00 AM")


func test_minute_progresses_through_single_minute_ticks() -> void:
	_shop.seconds_per_hour = 60.0
	for i in range(5):
		assert_eq(_clock.text, "7:%02d AM" % i)
		_shop._advance_clock(1.0)
	assert_eq(_clock.text, "7:05 AM")


func test_arbitrary_rate_derives_minutes() -> void:
	_shop.seconds_per_hour = 30.0
	_shop._advance_clock(15.0)
	assert_eq(_clock.text, "7:30 AM")


func test_format_uses_am_pm() -> void:
	_hud.set_time(20, 30)
	assert_eq(_clock.text, "8:30 PM")
	_hud.set_time(12, 5)
	assert_eq(_clock.text, "12:05 PM")
	_hud.set_time(0, 0)
	assert_eq(_clock.text, "12:00 AM")
	_hud.set_time(7, 0)
	assert_eq(_clock.text, "7:00 AM")


func test_dialogue_freezes_partial_minute_progress() -> void:
	_shop.seconds_per_hour = 60.0
	_shop._advance_clock(30.0)
	assert_eq(_clock.text, "7:30 AM")

	_shop._clock_paused = true
	_shop._advance_clock(15.0)  # Should not advance while paused.
	assert_eq(_clock.text, "7:30 AM")

	_shop._clock_paused = false
	_shop._advance_clock(15.0)
	assert_eq(_clock.text, "7:45 AM")


func test_dialogue_lifecycle_pauses_and_resumes_day_running() -> void:
	assert_true(_shop.is_day_running(), "Clock runs when the shop opens")

	_shop._open_dialogue(["A quick test line."], false)
	await wait_physics_frames(1)
	assert_false(_shop.is_day_running(), "Clock pauses while a visitor talks")

	_shop._on_dialogue_finished()
	assert_true(_shop.is_day_running(), "Clock resumes after dialogue")


func test_day_wraps_after_end_hour() -> void:
	_shop._day = 1
	_shop._hour = 20
	_shop._hour_elapsed = 0.0
	_shop.seconds_per_hour = 1.0
	_shop._advance_clock(1.0)
	assert_eq(_shop._day, 2)
	assert_eq(_shop._hour, 7)
	assert_eq(_clock.text, "7:00 AM")


func test_loop_wraps_after_day_five() -> void:
	_shop._day = 5
	_shop._hour = 20
	_shop._hour_elapsed = 0.0
	_shop.seconds_per_hour = 1.0
	_shop._advance_clock(1.0)
	assert_eq(_shop._day, 1)
	assert_eq(_clock.text, "7:00 AM")
