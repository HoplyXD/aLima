extends GutTest

## Tests for RouteService: the intro/return dialogue branch, mutual-exclusion
## visit gating, and fragment-seating -> route-completion -> reward wiring. Route
## progress lives in PersistentState, so it must survive the loop reset.


func before_each() -> void:
	# Start each case from clean persistent state on the live autoload.
	GameState.initialize("test-player")


func test_met_flag_drives_intro_then_return() -> void:
	var route := DataRepository.singleton().get_route("auntie")
	assert_false(RouteService.is_met("auntie"), "Auntie is unmet at the start")
	assert_eq(RouteService.dialogue_key(route, 1), "intro", "Unmet plays the intro set")

	RouteService.mark_met("auntie")
	assert_true(RouteService.is_met("auntie"), "mark_met records the meeting")
	assert_eq(RouteService.dialogue_key(route, 1), "return", "Met plays the return set")


func test_met_and_completed_survive_loop_reset() -> void:
	RouteService.mark_met("auntie")
	RouteService.mark_completed("scavenger")
	GameState.reset_loop_state()
	assert_true(RouteService.is_met("auntie"), "Met flag persists across the loop reset")
	assert_true(RouteService.is_completed("scavenger"), "Completion persists across the loop reset")


func test_shared_slot_defaults_to_scavenger_until_auntie_completed() -> void:
	# Day 2, 13:00 is the artisan/scavenger shared window.
	var first := RouteService.resolve_visitor(2, 13)
	assert_not_null(first, "Someone answers the shared afternoon slot")
	assert_eq(first.id, "scavenger", "Scavenger holds the slot while the auntie route is open")

	RouteService.mark_completed("auntie")
	var second := RouteService.resolve_visitor(2, 13)
	assert_eq(second.id, "artisan", "The artisan displaces the scavenger once auntie is complete")


func test_no_visitor_outside_any_window() -> void:
	# 07:00 Day 1 is before the earliest window (archeologist at 08:00).
	assert_null(RouteService.resolve_visitor(1, 7), "No one is scheduled at opening")


func test_seating_a_fragment_completes_its_route_and_grants_rewards() -> void:
	watch_signals(EventBus)
	# fragment_01 is owned by the auntie route (data/artifacts); rewards: safe_code, drawer_clue.
	RouteService._on_fragment_seated("fragment_01", 0)

	assert_true(RouteService.is_completed("auntie"), "Seating the fragment completes its route")
	assert_true(
		GameState.save_state.persistent.safe_code_known, "safe_code reward unlocks the safe code"
	)
	assert_true(
		GameState.save_state.persistent.story_clues.has("drawer_clue"),
		"drawer_clue reward is recorded as a story clue"
	)
	assert_signal_emitted_with_parameters(EventBus, "route_completed", ["auntie"])


func test_completing_scavenger_grants_archeologist_lead() -> void:
	RouteService.mark_completed("scavenger")
	assert_true(RouteService.has_lead("archeologist_lead"), "Scavenger reward grants the lead")
