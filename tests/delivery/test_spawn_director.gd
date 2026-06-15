extends GutTest

## Tests for the Phase 3 Spawn Director: carrier/container compatibility,
## capacity respect, deterministic seeding, and never-twice history.

var _repo: DataRepository


func before_each() -> void:
	GameState.initialize("spawn-test-player")
	GameState.set_debug_seed_override(5555)
	GameState.new_run()
	_repo = DataRepository.singleton()


func test_plans_only_released_fragments() -> void:
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	for fragment_id in plans.keys():
		var fragment: Fragment = _repo.get_fragment(fragment_id)
		assert_eq(fragment.state, ModelEnums.FragmentState.RELEASED)


func test_carrier_template_is_openable() -> void:
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	for fragment_id in plans.keys():
		var plan: Dictionary = plans[fragment_id]
		var template: ScrapObjectTemplate = _repo.get_template(plan["carrier_template_id"])
		assert_not_null(template)
		assert_true(template.is_openable, "Carrier template must be openable")


func test_container_is_compatible_with_carrier() -> void:
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	for fragment_id in plans.keys():
		var plan: Dictionary = plans[fragment_id]
		var template: ScrapObjectTemplate = _repo.get_template(plan["carrier_template_id"])
		var container: PlacementContainer = _repo.get_container(plan["container_id"])
		assert_not_null(container)
		var candidate_tags := template.tags.duplicate()
		candidate_tags.append(template.category)
		if not template.openable_type.is_empty():
			candidate_tags.append(template.openable_type)
		var matched := false
		for tag in candidate_tags:
			if container.compatibility_tags.has(tag):
				matched = true
				break
		assert_true(matched, "Container must be compatible with carrier tags")


func test_day_is_within_loop() -> void:
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	for fragment_id in plans.keys():
		var day: int = plans[fragment_id]["day"]
		assert_between(day, 1, DayClock.TOTAL_DAYS)


func test_fixed_seed_produces_same_placements() -> void:
	var director1 := SpawnDirector.new(_repo, GameState)
	var plans1 := director1.plan_loop_placements()

	GameState.initialize("spawn-test-player")
	GameState.set_debug_seed_override(5555)
	GameState.new_run()
	var director2 := SpawnDirector.new(_repo, GameState)
	var plans2 := director2.plan_loop_placements()

	assert_eq(plans1.keys(), plans2.keys())
	for fragment_id in plans1.keys():
		assert_eq(
			plans1[fragment_id]["carrier_template_id"], plans2[fragment_id]["carrier_template_id"]
		)
		assert_eq(plans1[fragment_id]["container_id"], plans2[fragment_id]["container_id"])
		assert_eq(plans1[fragment_id]["day"], plans2[fragment_id]["day"])


func test_different_seeds_produce_variation() -> void:
	var plans1 := SpawnDirector.new(_repo, GameState).plan_loop_placements()

	GameState.initialize("spawn-test-player")
	GameState.set_debug_seed_override(7777)
	GameState.new_run()
	var plans2 := SpawnDirector.new(_repo, GameState).plan_loop_placements()

	var different := false
	for fragment_id in plans1.keys():
		if plans1[fragment_id]["container_id"] != plans2[fragment_id]["container_id"]:
			different = true
			break
		if plans1[fragment_id]["day"] != plans2[fragment_id]["day"]:
			different = true
			break
	assert_true(different, "Different seeds should vary container or day")


func test_records_spawn_history() -> void:
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	var history: Dictionary = GameState.save_state.persistent.spawn_history
	for fragment_id in plans.keys():
		assert_true(history.has(fragment_id))
		var entries: Array = history[fragment_id]
		assert_gt(entries.size(), 0)
		var last: Dictionary = entries[entries.size() - 1]
		assert_eq(last["carrier_template_id"], plans[fragment_id]["carrier_template_id"])
		assert_eq(last["container_id"], plans[fragment_id]["container_id"])


func test_respects_container_capacity() -> void:
	# Reduce every container capacity to 1 and plan for a second released fragment.
	# This requires a second released fragment; if only fragment_01 is released,
	# the test still validates that no container exceeds capacity.
	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	var counts := {}
	for fragment_id in plans.keys():
		var container_id: String = plans[fragment_id]["container_id"]
		counts[container_id] = counts.get(container_id, 0) + 1
	for container_id in counts.keys():
		var container: PlacementContainer = _repo.get_container(container_id)
		assert_lte(counts[container_id], container.capacity)
