extends GutTest

## Tests for RouteService authored beats under the v3 revamp (story.md §16):
## ordinal completion gating, CATCH-UP scheduling (a missed beat resumes on the
## route's next visit day instead of hiding the character), unanswered-visit
## consumption at the new windows, and route-completion -> fragment RELEASED for
## routes that still hold one (the artisan; Auntie's fragment moved to the Safe).

const TEST_SAVE := "user://test_route_beats_save.json"
const TEST_TEMP := "user://test_route_beats_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("route-beats-test")
	RouteService._visit_log.clear()
	RouteService.debug_clear_forced_visit()


func after_each() -> void:
	RouteService._visit_log.clear()
	RouteService.debug_clear_forced_visit()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	# complete_beat releases the fragment (mirrors onto repo); restore authored state.
	_repo.load_from_filesystem()


# --- Beat ordinal gating ------------------------------------------------------


func test_beat_two_requires_beat_one() -> void:
	assert_false(
		RouteService.complete_beat("auntie", "auntie_beat_2"),
		"Beat 2 cannot complete before beat 1"
	)
	assert_false(RouteService.is_beat_complete("auntie_beat_2"))

	assert_true(RouteService.complete_beat("auntie", "auntie_beat_1"))
	assert_true(
		RouteService.complete_beat("auntie", "auntie_beat_2"), "Beat 2 unlocks after beat 1"
	)


func test_beat_three_requires_beat_two() -> void:
	RouteService.complete_beat("auntie", "auntie_beat_1")
	assert_false(
		RouteService.complete_beat("auntie", "auntie_beat_3"),
		"Beat 3 cannot complete before beat 2"
	)
	RouteService.complete_beat("auntie", "auntie_beat_2")
	assert_true(RouteService.complete_beat("auntie", "auntie_beat_3"))


func test_completing_a_beat_emits_and_is_idempotent() -> void:
	watch_signals(EventBus)
	assert_true(RouteService.complete_beat("auntie", "auntie_beat_1"))
	assert_signal_emitted_with_parameters(
		EventBus, "route_beat_completed", ["auntie", "auntie_beat_1"]
	)
	assert_false(
		RouteService.complete_beat("auntie", "auntie_beat_1"), "A done beat re-completes as no-op"
	)
	assert_eq(RouteService.beats_completed_count("auntie"), 1)


# --- Route completion releases (does not hand over) the fragment ---------------
# v3: Auntie's fragment comes from the Safe (holds_fragment_id is empty), so the
# artisan — who still holds fragment_02 — drives the release cases.


func test_auntie_final_beat_releases_nothing() -> void:
	watch_signals(EventBus)
	RouteService.complete_beat("auntie", "auntie_beat_1")
	RouteService.complete_beat("auntie", "auntie_beat_2")
	RouteService.complete_beat("auntie", "auntie_beat_3")
	assert_signal_not_emitted(
		EventBus, "fragment_released", "v3: her fragment waits in the Safe, not her beats"
	)
	assert_true(FragmentService.is_locked("fragment_01"))


func test_only_final_beat_releases_the_fragment() -> void:
	watch_signals(EventBus)
	RouteService.complete_beat("artisan", "artisan_beat_1")
	RouteService.complete_beat("artisan", "artisan_beat_2")
	assert_true(
		FragmentService.is_locked("fragment_02"),
		"Fragment stays LOCKED until the final beat is done"
	)

	assert_true(RouteService.complete_beat("artisan", "artisan_beat_3"))
	assert_true(FragmentService.is_released("fragment_02"), "Final beat releases the fragment")
	assert_signal_emitted_with_parameters(EventBus, "fragment_released", ["fragment_02"])


func test_released_fragment_becomes_spawn_director_eligible() -> void:
	RouteService.complete_beat("artisan", "artisan_beat_1")
	RouteService.complete_beat("artisan", "artisan_beat_2")
	RouteService.complete_beat("artisan", "artisan_beat_3")

	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	assert_true(
		plans.has("fragment_02"),
		"After release the Spawn Director plans a carrier for the fragment"
	)
	var plan: Dictionary = plans["fragment_02"]
	assert_false(plan.get("carrier_template_id", "").is_empty(), "Placed inside a promoted carrier")
	assert_false(plan.get("container_id", "").is_empty())


# --- due_beat (v3 catch-up) -----------------------------------------------------


func test_due_beat_catches_up_missed_days() -> void:
	assert_eq(str(RouteService.due_beat("auntie", 1).get("id")), "auntie_beat_1")
	# v3: a beat missed on Day 1 is still due on Day 3 (catch-up), pushing beat 2.
	assert_eq(
		str(RouteService.due_beat("auntie", 3).get("id")),
		"auntie_beat_1",
		"Day 3 presents the missed Day-1 beat"
	)
	RouteService.complete_beat("auntie", "auntie_beat_1")
	assert_eq(str(RouteService.due_beat("auntie", 3).get("id")), "auntie_beat_2")
	# A completed beat is no longer "due", and future beats wait for their day.
	assert_true(RouteService.due_beat("auntie", 1).is_empty(), "A done beat is not due again")


# --- Visit scheduling gate (v3 windows: D1/3 12-16, D5 9-16) --------------------


func test_auntie_only_in_her_window() -> void:
	assert_not_null(RouteService.resolve_visitor(1, 12), "Auntie answers at 12:00 on day 1")
	assert_eq(RouteService.resolve_visitor(1, 12).id, "auntie")
	assert_null(RouteService.resolve_visitor(1, 11), "Not before her window")
	assert_null(RouteService.resolve_visitor(1, 16), "Not at/after her window close")
	assert_null(RouteService.resolve_visitor(2, 12), "Not on a day she is not scheduled")


func test_day3_visit_catches_up_missed_beat_one() -> void:
	# v3 catch-up: she still visits on Day 3 with beat 1 unfinished — and presents it.
	var visitor := RouteService.resolve_visitor(3, 12)
	assert_not_null(visitor, "Day 3 visit happens even with beat 1 missed (catch-up)")
	assert_eq(visitor.id, "auntie")
	assert_eq(str(RouteService.due_beat("auntie", 3).get("id")), "auntie_beat_1")


func test_day5_window_opens_early() -> void:
	RouteService.complete_beat("auntie", "auntie_beat_1")
	RouteService.complete_beat("auntie", "auntie_beat_2")
	var visitor := RouteService.resolve_visitor(5, 9)
	assert_not_null(visitor, "Day 5 window opens at 09:00 (v3)")
	assert_eq(visitor.id, "auntie")
	assert_null(RouteService.resolve_visitor(3, 9), "Days 1/3 still open at noon")


# --- Unanswered-visit consumption ---------------------------------------------


func test_unanswered_window_close_consumes_the_visit() -> void:
	watch_signals(EventBus)
	# Within the window, Auntie still answers.
	assert_not_null(RouteService.resolve_visitor(1, 13), "Auntie answers within her window")
	# The clock crosses Auntie's 16:00 close on day 1 without an answer.
	EventBus.hour_changed.emit(1, 16)
	assert_signal_emitted_with_parameters(EventBus, "visit_missed", ["auntie", 1])
	assert_true(
		RouteService.is_visit_missed("auntie", 1), "The unanswered visit is recorded as missed"
	)
	assert_null(RouteService.resolve_visitor(1, 16), "The closed window no longer answers the door")


func test_missed_visit_is_announced_only_once() -> void:
	watch_signals(EventBus)
	EventBus.hour_changed.emit(1, 16)
	EventBus.hour_changed.emit(1, 16)
	assert_signal_emit_count(EventBus, "visit_missed", 1, "A consumed visit is not re-announced")


func test_answered_visit_is_not_consumed_as_missed() -> void:
	watch_signals(EventBus)
	RouteService.notify_visit_answered("auntie", 1)
	EventBus.hour_changed.emit(1, 16)
	assert_signal_not_emitted(EventBus, "visit_missed")
	assert_false(RouteService.is_visit_missed("auntie", 1))


func test_no_consumption_when_no_window_closes() -> void:
	watch_signals(EventBus)
	# Nothing is scheduled to close at 10:00 on day 1 (auntie closes 16:00).
	EventBus.hour_changed.emit(1, 10)
	assert_signal_not_emitted(EventBus, "visit_missed")
	# Auntie is not scheduled on day 2, so her visit is never consumed there.
	EventBus.hour_changed.emit(2, 16)
	assert_false(RouteService.is_visit_missed("auntie", 2))


# --- Debug override -----------------------------------------------------------


func test_debug_force_visit_overrides_window_and_gating() -> void:
	# 07:00 day 1 is before every window; the override still returns the buyer.
	RouteService.debug_force_visit("buyer")
	var visitor := RouteService.resolve_visitor(1, 7)
	assert_not_null(visitor)
	assert_eq(visitor.id, "buyer")

	RouteService.debug_clear_forced_visit()
	assert_null(
		RouteService.resolve_visitor(1, 7), "Clearing the override restores normal scheduling"
	)
