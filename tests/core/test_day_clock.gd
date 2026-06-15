extends GutTest

## Unit tests for the reusable DayClock (CLOCK-R1, R2, R5). Each test drives a
## fresh, isolated instance via tick() with `running` left false, so progression
## is deterministic and independent of real time and the autoload.

const DayClockScript := preload("res://scripts/core/day_clock.gd")

var _clock


func before_each() -> void:
	_clock = DayClockScript.new()
	add_child_autofree(_clock)


# --- Progression --------------------------------------------------------------


func test_starts_day_at_seven_am() -> void:
	_clock.start_day(1)
	assert_eq(_clock.get_day(), 1)
	assert_eq(_clock.get_hour(), 7)
	assert_eq(_clock.get_minute(), 0)


func test_minute_progression_at_default_rate() -> void:
	_clock.seconds_per_hour = 60.0
	_clock.start_day(1)
	_clock.tick(30.0)
	assert_eq(_clock.get_hour(), 7)
	assert_eq(_clock.get_minute(), 30)
	_clock.tick(30.0)
	assert_eq(_clock.get_hour(), 8)
	assert_eq(_clock.get_minute(), 0)


func test_debug_speed_advances_one_hour_per_tenth_second() -> void:
	_clock.seconds_per_hour = 0.1
	_clock.start_day(1)
	_clock.tick(0.1)
	assert_eq(_clock.get_hour(), 8)
	_clock.tick(0.1)
	assert_eq(_clock.get_hour(), 9)


# --- Exactly-once transitions / boundary --------------------------------------


func test_full_day_emits_each_hour_once_and_closes_at_twenty() -> void:
	_clock.seconds_per_hour = 1.0
	watch_signals(_clock)
	_clock.start_day(1)  # emits day_changed(1) + hour_changed(1, 7)
	_clock.tick(13.5)  # advance the remaining 13 in-game hours to the 20:00 close
	# hour_changed fires for hours 7..19 inclusive (13), never for 20.
	assert_signal_emit_count(_clock, "hour_changed", 13)
	assert_signal_emit_count(_clock, "day_changed", 1)
	assert_signal_emit_count(_clock, "day_closed", 1)
	assert_true(_clock.is_closed())
	assert_eq(_clock.get_hour(), 20)


func test_large_delta_does_not_skip_or_duplicate_transitions() -> void:
	_clock.seconds_per_hour = 1.0
	watch_signals(_clock)
	_clock.start_day(1)
	_clock.tick(1000.0)  # one huge frame: must stop at 20:00, not run past
	assert_signal_emit_count(_clock, "hour_changed", 13)
	assert_signal_emit_count(_clock, "day_closed", 1)
	assert_eq(_clock.get_hour(), 20)
	# Ticking again while closed is a no-op; day_closed is not re-emitted.
	_clock.tick(1000.0)
	assert_signal_emit_count(_clock, "day_closed", 1)


func test_start_day_resumes_next_day_at_seven() -> void:
	_clock.seconds_per_hour = 1.0
	_clock.start_day(1)
	_clock.tick(14.0)
	assert_true(_clock.is_closed())
	watch_signals(_clock)
	_clock.start_day(2)
	assert_eq(_clock.get_day(), 2)
	assert_eq(_clock.get_hour(), 7)
	assert_false(_clock.is_closed())
	assert_signal_emit_count(_clock, "day_changed", 1)
	assert_signal_emit_count(_clock, "hour_changed", 1)


# --- Pause ownership (CLOCK-R5) ----------------------------------------------


func test_two_owners_release_independently() -> void:
	_clock.running = true
	_clock.start_day(1)
	assert_true(_clock.is_running())

	_clock.request_pause("a")
	assert_true(_clock.is_paused())
	assert_false(_clock.is_running())

	_clock.request_pause("b")
	_clock.release_pause("a")
	assert_true(_clock.is_paused(), "Clock stays paused while owner 'b' holds it")

	_clock.release_pause("b")
	assert_false(_clock.is_paused())
	assert_true(_clock.is_running())


func test_pause_changed_fires_only_on_edges() -> void:
	watch_signals(_clock)
	_clock.request_pause("a")  # empty -> paused edge
	_clock.request_pause("b")  # no edge
	_clock.release_pause("a")  # no edge
	_clock.release_pause("b")  # paused -> empty edge
	assert_signal_emit_count(_clock, "pause_changed", 2)


func test_paused_clock_does_not_advance() -> void:
	_clock.seconds_per_hour = 1.0
	_clock.start_day(1)
	_clock.request_pause("a")
	_clock.tick(5.0)
	assert_eq(_clock.get_hour(), 7, "Paused clock must not advance")


func test_duplicate_acquire_from_same_owner_is_idempotent() -> void:
	_clock.request_pause("a")
	_clock.request_pause("a")
	assert_eq(_clock.pause_owner_count(), 1)
	_clock.release_pause("a")
	assert_false(_clock.is_paused(), "A single release clears a duplicated acquire")


func test_release_unknown_owner_is_harmless() -> void:
	_clock.release_pause("ghost")  # nothing held: no-op
	assert_false(_clock.is_paused())
	_clock.request_pause("a")
	_clock.release_pause("ghost")  # unknown owner must not drop owner 'a'
	assert_true(_clock.is_paused())
	assert_eq(_clock.pause_owner_count(), 1)
