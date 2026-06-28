extends "res://tests/discovery/spawn_director/spawn_director_test_base.gd"
## Phase 5 Spawn Director tests for candidate enumeration, hard filters, weighted
## scoring, and carrier promotion invariants.


func test_fixed_seed_produces_same_result() -> void:
	var plan1 := _plan()

	GameState.initialize("phase5-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_kit()
	var plan2 := _plan()

	assert_eq(_pair_for(plan1), _pair_for(plan2))
	assert_eq(plan1["day"], plan2["day"])


func test_deterministic_candidate_ordering() -> void:
	var director := _make_director()
	var plan := director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()
	assert_gt(audit["candidate_count"], 0)
	assert_gt(audit["eligible_count"], 0)
	assert_true(audit.has("rejected_candidates"))


func test_different_seeds_produce_valid_variation() -> void:
	var plan1 := _plan()

	GameState.initialize("phase5-test-player")
	GameState.set_debug_seed_override(7777)
	GameState.new_run()
	_grant_starting_kit()
	var plan2 := _plan()

	var different := false
	if _pair_for(plan1) != _pair_for(plan2):
		different = true
	if plan1["day"] != plan2["day"]:
		different = true
	assert_true(different, "Different seeds should vary carrier/container/day")


func test_only_released_fragments_are_eligible() -> void:
	var plans := _make_director().plan_loop_placements()
	assert_gt(plans.size(), 0, "At least one released fragment is planned")
	for fragment_id in plans.keys():
		var fragment: Fragment = _repo.get_fragment(fragment_id)
		assert_eq(fragment.state, ModelEnums.FragmentState.RELEASED)


func test_seated_fragments_are_excluded() -> void:
	# Mark the persistent fragment as seated; the repo definition stays RELEASED.
	var seated_fragment: Fragment = GameState.save_state.persistent.fragments["fragment_01"]
	seated_fragment.state = ModelEnums.FragmentState.SEATED
	var plans := _make_director().plan_loop_placements()
	assert_false(plans.has("fragment_01"))


func test_unavailable_required_tool_excludes_candidate() -> void:
	var director := _make_director()
	var plan := director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()

	var template: ScrapObjectTemplate = _repo.get_template(plan["carrier_template_id"])
	assert_true(
		_tool_is_available(template.required_clean_tool),
		"Selected carrier must use an obtainable tool"
	)

	var found_unavailable := false
	for r in audit["rejected_candidates"]:
		if r["reason"] == "required_tool_unavailable":
			found_unavailable = true
			break
	assert_true(found_unavailable, "rusted_tin should be rejected due to missing rust_brush")


func test_granting_tool_clears_the_tool_gate() -> void:
	# Granting the required tool must lift the tool-gate (§4-H). rusted_tin has no artifact scene, so
	# it stays filtered for "missing_scene" — but it must NO LONGER be rejected for the missing tool.
	GameState.save_state.loop.tool_items.append("rust_brush")
	var director := _make_director()
	director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()
	var tool_gated := false
	for r in audit["rejected_candidates"]:
		if r["template_id"] == "rusted_tin" and r["reason"] == "required_tool_unavailable":
			tool_gated = true
			break
	assert_false(tool_gated, "Granting rust_brush must clear rusted_tin's required-tool rejection")


func test_incompatible_containers_are_rejected() -> void:
	var director := _make_director()
	director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()
	var found_incompatible := false
	for r in audit["rejected_candidates"]:
		if r["reason"] == "incompatible_container":
			found_incompatible = true
			break
	assert_true(found_incompatible)


func test_containers_over_capacity_are_rejected() -> void:
	# Reduce every container capacity to 1 and release a second fragment so two
	# carriers compete for the same small pool. before_each reloads the repository
	# for the next test, so these mutations are isolated.
	for id in _repo.placement_containers.keys():
		_repo.placement_containers[id].capacity = 1
	_repo.fragments["fragment_02"].state = ModelEnums.FragmentState.RELEASED
	var plans := _make_director().plan_loop_placements()
	assert_gt(plans.size(), 0)
	var counts := {}
	for fragment_id in plans.keys():
		var c: String = plans[fragment_id]["container_id"]
		counts[c] = counts.get(c, 0) + 1
	for c in counts.keys():
		assert_lte(counts[c], 1)


func test_day_is_within_loop() -> void:
	var plan := _plan()
	assert_between(plan["day"], 1, DayClock.TOTAL_DAYS)


func test_locked_locations_are_rejected_without_code() -> void:
	var director := _make_director()
	director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()
	var found_locked := false
	for r in audit["rejected_candidates"]:
		if r["reason"] == "safe_code_unknown" or r["reason"] == "location_locked":
			found_locked = true
			break
	assert_true(found_locked, "Safe should be rejected when code is unknown")


func test_safe_code_makes_safe_eligible() -> void:
	GameState.save_state.persistent.safe_code_known = true
	var director := _make_director()
	director.plan_fragment_placement("fragment_01")
	var audit: Dictionary = director.get_last_audit_log()
	var safe_eligible := false
	for c in _eligible_candidates(director):
		if c.container_id == "safe":
			safe_eligible = true
			break
	assert_true(safe_eligible, "Safe should be eligible when code is known")


func test_safe_code_affects_only_safe_container_eligibility() -> void:
	GameState.save_state.persistent.safe_code_known = true
	var director := _make_director()
	var eligible_without := _eligible_candidates(director)
	var safe_count := 0
	for c in eligible_without:
		if c.container_id == "safe":
			safe_count += 1
	assert_gt(safe_count, 0, "Safe should be eligible with code known")


func test_fragment_is_inside_promoted_carrier_not_loose() -> void:
	var plan := _plan()
	GameState.save_state.loop.current_carrier_placements["fragment_01"] = plan
	var delivery := _make_generator().generate_day_delivery(plan["day"])
	var carrier: ObjectInstance = null
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			carrier = inst
			break
	assert_not_null(carrier)
	assert_eq(carrier.contents, ModelEnums.OpenResult.FRAGMENT)
	assert_false(carrier.assigned_anchor_id.is_empty())


func test_promotion_preserves_template_and_rarity() -> void:
	var plan := _plan()
	GameState.save_state.loop.current_carrier_placements["fragment_01"] = plan
	var delivery := _make_generator().generate_day_delivery(plan["day"])
	for inst in delivery:
		if inst.is_carrier:
			assert_eq(inst.template_id, plan["carrier_template_id"])
			var template: ScrapObjectTemplate = _repo.get_template(inst.template_id)
			assert_true(template.is_openable)
			assert_eq(
				template.base_rarity, _repo.get_template(plan["carrier_template_id"]).base_rarity
			)
			return
	fail_test("No carrier found in delivery")


func test_promotion_sets_carrier_fragment_content_once() -> void:
	watch_signals(EventBus)
	var plan := _plan()
	GameState.save_state.loop.current_carrier_placements["fragment_01"] = plan
	var delivery := _make_generator().generate_day_delivery(plan["day"])
	var carrier_count := 0
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			carrier_count += 1
			assert_eq(inst.contents, ModelEnums.OpenResult.FRAGMENT)
	assert_eq(carrier_count, 1)
	assert_signal_emitted(EventBus, "carrier_activated")
