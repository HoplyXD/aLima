extends "res://tests/discovery/spawn_director/spawn_director_test_base.gd"
## Phase 5 Spawn Director tests for never-twice history, soft reset, persistence,
## save/load, deterministic audit logs, and the three-seed demo.


func test_three_sequential_runs_do_not_repeat_pair() -> void:
	var seeds: Array[int] = [10007, 50021, 90001]
	var pairs: Array[String] = []
	for seed in seeds:
		GameState.initialize("phase5-test-player")
		GameState.set_debug_seed_override(seed)
		GameState.new_run()
		_grant_starting_kit()
		var plan := _plan()
		pairs.append(_pair_for(plan))

	assert_ne(pairs[0], pairs[1])
	assert_ne(pairs[1], pairs[2])
	assert_ne(pairs[0], pairs[2])


func test_older_pairs_remain_excluded_before_exhaustion() -> void:
	var forbidden_pairs := ["tarnished_pendant|pile_left", "dusty_locket|pile_center"]
	for pair in forbidden_pairs:
		var parts: PackedStringArray = pair.split("|")
		GameState.save_state.persistent.spawn_history["fragment_01"] = (
			GameState.save_state.persistent.spawn_history.get("fragment_01", [])
		)
		(
			GameState
			. save_state
			. persistent
			. spawn_history["fragment_01"]
			. append(
				{
					"loop": 1,
					"seed": 0,
					"fragment_id": "fragment_01",
					"carrier_template_id": parts[0],
					"carrier_instance_id": "",
					"container_id": parts[1],
					"day": 1,
					"soft_reset": false,
				}
			)
		)

	var plan := _plan()
	assert_false(forbidden_pairs.has(_pair_for(plan)))


func test_exhaustion_triggers_soft_reset() -> void:
	var director := _make_director()
	var eligible_pairs: Array[String] = []
	for c in _eligible_candidates(director):
		eligible_pairs.append(c.pair_key())
	assert_gt(eligible_pairs.size(), 1)

	var history: Array = GameState.save_state.persistent.spawn_history.get("fragment_01", [])
	for i in range(eligible_pairs.size()):
		var parts: PackedStringArray = eligible_pairs[i].split("|")
		(
			history
			. append(
				{
					"loop": i,
					"seed": 0,
					"fragment_id": "fragment_01",
					"carrier_template_id": parts[0],
					"carrier_instance_id": "",
					"container_id": parts[1],
					"day": 1,
					"soft_reset": false,
				}
			)
		)
	GameState.save_state.persistent.spawn_history["fragment_01"] = history

	var plan := _make_director().plan_fragment_placement("fragment_01")
	assert_true(plan["soft_reset"], "Soft reset should be recorded when pairs are exhausted")


func test_soft_reset_forbids_most_recent_pair() -> void:
	var director := _make_director()
	var eligible_pairs: Array[String] = []
	for c in _eligible_candidates(director):
		eligible_pairs.append(c.pair_key())
	assert_gt(eligible_pairs.size(), 1)

	var history: Array = []
	for pair in eligible_pairs:
		var parts: PackedStringArray = pair.split("|")
		(
			history
			. append(
				{
					"loop": history.size(),
					"seed": 0,
					"fragment_id": "fragment_01",
					"carrier_template_id": parts[0],
					"carrier_instance_id": "",
					"container_id": parts[1],
					"day": 1,
					"soft_reset": false,
				}
			)
		)
	GameState.save_state.persistent.spawn_history["fragment_01"] = history

	var most_recent := eligible_pairs[eligible_pairs.size() - 1]
	var plan := _make_director().plan_fragment_placement("fragment_01")
	assert_ne(_pair_for(plan), most_recent)
	assert_true(plan["soft_reset"])


func test_soft_reset_never_bypasses_hard_filters() -> void:
	# Fill history with an invalid pair (Safe without code) to force exhaustion,
	# then confirm the Safe is still not selected.
	var history: Array = [
		{
			"loop": 1,
			"seed": 0,
			"fragment_id": "fragment_01",
			"carrier_template_id": "tarnished_pendant",
			"carrier_instance_id": "",
			"container_id": "safe",
			"day": 1,
			"soft_reset": false,
		}
	]
	GameState.save_state.persistent.spawn_history["fragment_01"] = history
	var plan := _plan()
	assert_ne(plan["container_id"], "safe")


func test_persistent_history_survives_loop_reset_and_save_load() -> void:
	var director := _make_director()
	director.plan_loop_placements()
	var history_before: Array = GameState.save_state.persistent.spawn_history.get("fragment_01", [])
	assert_gt(history_before.size(), 0)
	var pair := (
		"%s|%s" % [history_before[0]["carrier_template_id"], history_before[0]["container_id"]]
	)

	GameState.save_state.reset_loop_state()
	GameState.new_run()
	_grant_starting_kit()

	var result := SaveService.save_game()
	assert_true(result.ok)
	var loaded := SaveService.load_game()
	assert_true(loaded.ok)

	var history: Array = GameState.save_state.persistent.spawn_history.get("fragment_01", [])
	assert_gt(history.size(), 0)
	var last: Dictionary = history[history.size() - 1]
	assert_eq("%s|%s" % [last["carrier_template_id"], last["container_id"]], pair)


func test_seeded_audit_logs_are_reproducible() -> void:
	var director1 := _make_director()
	var plan1 := director1.plan_fragment_placement("fragment_01")
	var audit1: Dictionary = director1.get_last_audit_log()

	GameState.initialize("phase5-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_kit()
	var director2 := _make_director()
	director2.plan_fragment_placement("fragment_01")
	var audit2: Dictionary = director2.get_last_audit_log()

	assert_eq(audit1["selected_carrier_template"], audit2["selected_carrier_template"])
	assert_eq(audit1["selected_container"], audit2["selected_container"])
	assert_eq(audit1["selected_day"], audit2["selected_day"])
	assert_eq(audit1["eligible_count"], audit2["eligible_count"])


func test_no_candidate_failure_leaves_state_unchanged() -> void:
	# Make every candidate invalid by removing all tools. Save and restore the
	# global starting kit so other tests are not affected.
	var saved_tool_ids: Array = _repo.starting_kit.get("tool_ids", []).duplicate()
	GameState.save_state.loop.tool_items.clear()
	GameState.save_state.persistent.legacy_items.clear()
	_repo.starting_kit["tool_ids"] = []
	var placements_before := GameState.save_state.loop.current_carrier_placements.duplicate(true)
	var plan := _plan()
	_repo.starting_kit["tool_ids"] = saved_tool_ids
	assert_true(plan.is_empty())
	assert_eq(GameState.save_state.loop.current_carrier_placements.size(), placements_before.size())


func test_three_run_demo_retains_history() -> void:
	var seeds: Array[int] = [90001, 90002, 90003]
	var logs := _make_director().run_three_seed_demo("phase5-demo-player", "fragment_01", seeds)
	assert_eq(logs.size(), 3)
	var history: Array = GameState.save_state.persistent.spawn_history.get("fragment_01", [])
	assert_eq(history.size(), 3)
	for i in range(logs.size()):
		assert_eq(logs[i]["run_seed"], seeds[i])
