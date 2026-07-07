extends GutTest
## The hidden-fragment hunt (team decision 2026-07-07): SpawnDirector hunt-spot
## planning (availability hard filter, day windows, never-twice with soft
## reset), HuntService orchestration on release/reset/find, and EchoController
## hunt-mode validity + heartbeat gating.

const TEST_SAVE := "user://test_hunt_save.json"
const TEST_TEMP := "user://test_hunt_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("hunt-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_release("fragment_01")


func after_each() -> void:
	EchoController.clear_hunt_target()
	_repo.load_from_filesystem()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _release(fragment_id: String) -> void:
	_repo.get_fragment(fragment_id).state = ModelEnums.FragmentState.RELEASED
	GameState.save_state.persistent.fragments[fragment_id].state = (
		ModelEnums.FragmentState.RELEASED
	)


func _director() -> SpawnDirector:
	return SpawnDirector.new(_repo, GameState)


# --- Authored data -------------------------------------------------------------


func test_hiding_spots_load_and_validate() -> void:
	assert_gt(_repo.hiding_spots.size(), 10, "authored hiding spots load")
	for spot in _repo.get_hiding_spots_sorted():
		var result: ValidationResult = spot.validate()
		assert_true(result.is_valid(), "spot '%s' validates" % spot.id)


func test_spot_availability_and_day_windows() -> void:
	var dump_spot: HidingSpot = _repo.get_hiding_spot("dump_heap_west")
	assert_not_null(dump_spot)
	var persistent := GameState.save_state.persistent
	assert_false(dump_spot.is_available(persistent), "locked dump site spot unavailable")
	persistent.unlocked_locations.append("dump_site")
	assert_true(dump_spot.is_available(persistent), "unlocked dump site spot available")
	assert_true(dump_spot.is_open_on_day(0), "loop-start planning accepts windowed spots")
	assert_true(dump_spot.is_open_on_day(3), "open inside the day window")
	assert_false(dump_spot.is_open_on_day(5), "closed outside the day window")
	var yard_spot: HidingSpot = _repo.get_hiding_spot("yard_tarp_north")
	assert_true(yard_spot.is_available(persistent))
	assert_true(yard_spot.is_open_on_day(5), "yard spots have no day window")


# --- Planning: hard filters ------------------------------------------------------


func test_plan_never_lands_in_locked_location() -> void:
	var director := _director()
	var plan := director.plan_hunt_spot("fragment_01")
	assert_false(plan.is_empty(), "a plan lands")
	assert_true(
		plan["location"] == "yard" or plan["location"] == "shop",
		"locked dump site / forbidden zone are excluded (got '%s')" % plan["location"]
	)
	var audit := director.get_last_audit_log()
	var found_requirement_reject := false
	for rejected in audit.get("rejected_spots", []):
		if rejected.get("reason") == "requirement_unmet":
			found_requirement_reject = true
	assert_true(found_requirement_reject, "locked spots are rejected as requirement_unmet")


func test_mid_loop_release_respects_day_window() -> void:
	GameState.save_state.persistent.unlocked_locations.append("dump_site")
	# Day 5: the dump site is closed (open days 3-4), so even unlocked spots there
	# must be rejected — a same-day release must stay reachable today.
	for i in 20:
		var director := _director()
		var plan := director.plan_hunt_spot("fragment_01", 5)
		assert_false(plan.is_empty())
		assert_ne(plan["location"], "dump_site", "day-windowed location excluded on day 5")
		assert_ne(plan["location"], "forbidden_zone")


func test_occupied_spots_are_excluded() -> void:
	var occupied := {}
	var open_spot := ""
	for spot in _repo.get_hiding_spots_sorted():
		if spot.location == "yard" or spot.location == "shop":
			if open_spot.is_empty():
				open_spot = spot.id
			else:
				occupied[spot.id] = true
	var plan := _director().plan_hunt_spot("fragment_01", 0, occupied)
	assert_false(plan.is_empty(), "the single open spot is planned")
	assert_eq(plan["spot_id"], open_spot)


# --- Planning: never-twice + soft reset -------------------------------------------


func test_never_twice_until_exhausted_then_soft_reset() -> void:
	var available := 0
	for spot in _repo.get_hiding_spots_sorted():
		if spot.location == "yard" or spot.location == "shop":
			available += 1
	var used := {}
	var last_spot := ""
	for i in available:
		var plan := _director().plan_hunt_spot("fragment_01")
		assert_false(plan.is_empty(), "plan %d lands" % i)
		assert_false(used.has(plan["spot_id"]), "spot '%s' never repeats" % plan["spot_id"])
		assert_false(bool(plan.get("soft_reset", false)), "no soft reset while spots remain")
		used[plan["spot_id"]] = true
		last_spot = plan["spot_id"]
	# Every available spot has been used once: the next plan soft-resets but still
	# avoids the most recent spot (documented deadlock avoidance).
	var reset_plan := _director().plan_hunt_spot("fragment_01")
	assert_false(reset_plan.is_empty(), "soft reset keeps the hunt winnable")
	assert_true(bool(reset_plan.get("soft_reset", false)), "soft reset is flagged")
	assert_ne(reset_plan["spot_id"], last_spot, "most recent spot stays forbidden")


func test_history_records_spot_entries() -> void:
	var plan := _director().plan_hunt_spot("fragment_01")
	var history: Array = GameState.save_state.persistent.spawn_history.get("fragment_01", [])
	assert_gt(history.size(), 0, "hunt history recorded")
	var last: Dictionary = history[history.size() - 1]
	assert_eq(last.get("spot_id"), plan["spot_id"])
	assert_eq(last.get("location"), plan["location"])
	assert_true(last.has("seed"), "audit trail keeps the run seed")


# --- Loop planning + HuntService ---------------------------------------------------


func test_plan_hunt_spots_plans_all_released_without_collisions() -> void:
	_release("fragment_02")
	var plans := _director().plan_hunt_spots(0)
	assert_true(plans.has("fragment_01"))
	assert_true(plans.has("fragment_02"))
	assert_ne(
		plans["fragment_01"]["spot_id"],
		plans["fragment_02"]["spot_id"],
		"two hunts never share a spot"
	)


func test_plan_hunt_spots_skips_seated_and_locked() -> void:
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.SEATED
	)
	_repo.get_fragment("fragment_01").state = ModelEnums.FragmentState.SEATED
	var plans := _director().plan_hunt_spots(0)
	assert_false(plans.has("fragment_01"), "seated fragments are not hunted")
	assert_false(plans.has("fragment_03"), "locked fragments are not hunted")


func test_hunt_service_plans_on_release_signal() -> void:
	# fragment_02 goes LOCKED -> RELEASED through the real service, which emits
	# fragment_released; HuntService must plan a reachable spot immediately.
	var released := FragmentService.release_fragment("fragment_02", "hunt-test")
	assert_true(released)
	assert_true(
		GameState.save_state.loop.fragment_spots.has("fragment_02"),
		"HuntService planned a spot on release"
	)


func test_hunt_service_spots_for_location_and_mark_found() -> void:
	HuntService.ensure_planned()
	var plan: Dictionary = GameState.save_state.loop.fragment_spots.get("fragment_01", {})
	assert_false(plan.is_empty())
	var location: String = plan["location"]
	var hunts := HuntService.spots_for_location(location)
	var found := false
	for hunt in hunts:
		if hunt["fragment_id"] == "fragment_01":
			found = true
			assert_eq((hunt["spot"] as HidingSpot).id, plan["spot_id"])
	assert_true(found, "the planned hunt surfaces in its location")
	HuntService.mark_found("fragment_01")
	assert_false(
		GameState.save_state.loop.fragment_spots.has("fragment_01"),
		"finding the fragment clears the plan"
	)


# --- EchoController hunt mode ------------------------------------------------------


func test_echo_hunt_mode_valid_and_heartbeat_at_spot() -> void:
	EchoController.set_hunt_target("fragment_01")
	EchoController.set_carrier_position(Vector3.ZERO)
	EchoController.set_listener_position(Vector3.ZERO)
	for i in 60:
		EchoController.update(0.1)
	var state: Dictionary = EchoController.get_state()
	assert_true(state["valid"], "hunt target for a RELEASED fragment is valid")
	assert_eq(state["fragment_id"], "fragment_01")
	assert_gt(float(state["proximity"]), 0.9, "standing on the spot maxes proximity")
	var gains: Dictionary = state["gains"]
	assert_gt(
		float(gains.get(EchoMixer.BAND_HEARTBEAT, 0.0)),
		0.0,
		"heartbeat authorized at the true find spot"
	)


func test_echo_hunt_mode_silent_for_locked_fragment() -> void:
	EchoController.set_hunt_target("fragment_03")
	EchoController.set_carrier_position(Vector3.ZERO)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.update(0.1)
	var state: Dictionary = EchoController.get_state()
	assert_false(state["valid"], "a LOCKED fragment never sounds (silence rule)")


func test_echo_hunt_clears_on_discovery_and_seat() -> void:
	EchoController.set_hunt_target("fragment_01")
	EventBus.fragment_discovered.emit("fragment_01", "")
	var state: Dictionary = EchoController.get_state()
	assert_false(state["valid"], "discovery clears the hunt target")

	EchoController.set_hunt_target("fragment_01")
	EventBus.fragment_seated.emit("fragment_01", 0)
	state = EchoController.get_state()
	assert_false(state["valid"], "seating clears the hunt target")
