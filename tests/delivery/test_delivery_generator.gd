extends GutTest

## Tests for DeliveryGenerator (P3.1): weighted template selection, batch bounds,
## unique instance IDs, deterministic fixed-seed generation, carrier injection,
## and carrier identity preservation.

const TEST_SAVE := "user://test_delivery_save.json"
const TEST_TEMP := "user://test_delivery_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("delivery-test-player")
	DayClock.reset()
	_repo = DataRepository.singleton()
	_release_fragment_01()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	# Restore authored fragment state (fragment_01 starts LOCKED; the Auntie route
	# releases it at runtime, Phase 10) so this suite never leaks RELEASED into others.
	_repo.load_from_filesystem()


## fragment_01 is released by the Auntie route at runtime; these carrier-injection
## tests need it RELEASED up front, so release it in both the repo (the Spawn
## Director's source) and persistent state.
func _release_fragment_01() -> void:
	_repo.get_fragment("fragment_01").state = ModelEnums.FragmentState.RELEASED
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.RELEASED
	)


func _make_generator() -> DeliveryGenerator:
	return DeliveryGenerator.new(_repo, GameState)


func test_batch_size_within_configured_bounds() -> void:
	var cfg := _repo.get_delivery_config()
	var generator := _make_generator()
	for day in range(1, 6):
		var delivery := generator.generate_day_delivery(day)
		assert_between(delivery.size(), cfg.batch_min, cfg.batch_max)


func test_delivered_instances_carry_random_conditions() -> void:
	GameState.set_debug_seed_override(2024)
	GameState.new_run()
	var delivery := _make_generator().generate_day_delivery(1)
	assert_gt(delivery.size(), 0, "a delivery was generated")
	for inst in delivery:
		assert_gt(inst.spawned_decals.size(), 0, "every delivered artifact has random conditions")
		# Each spawned condition names a real cleaning tool from the catalog.
		for decal in inst.get_spawned_decals():
			assert_false(decal.required_tool.is_empty(), "the condition names a treating tool")
			assert_not_null(_repo.get_tool(decal.required_tool), "the tool exists")


func test_fixed_seed_produces_repeatable_delivery() -> void:
	GameState.set_debug_seed_override(12345)
	GameState.new_run()

	var generator1 := _make_generator()
	var first := generator1.generate_day_delivery(1)
	var first_ids := _uids_of(first)

	# Same seed, same loop -> identical batch.
	GameState.initialize("delivery-test-player")
	GameState.set_debug_seed_override(12345)
	GameState.new_run()
	var generator2 := _make_generator()
	var second := generator2.generate_day_delivery(1)
	var second_ids := _uids_of(second)

	assert_eq(first_ids, second_ids)


func test_different_seeds_produce_different_deliveries() -> void:
	GameState.set_debug_seed_override(11111)
	GameState.new_run()
	var delivery_a := _make_generator().generate_day_delivery(1)

	GameState.initialize("delivery-test-player")
	GameState.set_debug_seed_override(22222)
	GameState.new_run()
	var delivery_b := _make_generator().generate_day_delivery(1)

	assert_ne(_uids_of(delivery_a), _uids_of(delivery_b))


func test_weight_distribution_respects_rarity_weights() -> void:
	# white (40) should clearly outnumber blue (18) over many runs. We count by EFFECTIVE
	# rarity rather than one hardcoded template id (the Brass Hand Bell that used to be the
	# white sample is now banned as a rust/tarnish common). refresh() re-registers the
	# scene-only common artifacts (Cup/Plate/wood_pipe) so the common tier is populated even
	# after this suite's repo reloads.
	preload("res://scripts/restoration/artifact_catalog.gd").refresh()
	var white_count := 0
	var blue_count := 0
	for seed in range(50):
		GameState.initialize("delivery-test-player")
		GameState.set_debug_seed_override(seed)
		GameState.new_run()
		var delivery := _make_generator().generate_day_delivery(1)
		for inst in delivery:
			var tmpl := _repo.get_template(inst.template_id)
			if tmpl == null:
				continue
			if tmpl.base_rarity == ModelEnums.Rarity.WHITE:
				white_count += 1
			elif tmpl.base_rarity == ModelEnums.Rarity.BLUE:
				blue_count += 1
	assert_gt(white_count, 0)
	assert_gt(blue_count, 0)
	assert_gt(white_count, blue_count, "Higher-weighted rarities should appear more often")


func test_unique_instance_ids_across_batches() -> void:
	var seen := {}
	for loop in range(3):
		GameState.initialize("delivery-test-player")
		GameState.set_debug_seed_override(loop)
		GameState.new_run()
		for day in range(1, 6):
			var delivery := _make_generator().generate_day_delivery(day)
			for inst in delivery:
				assert_false(seen.has(inst.uid), "UID collision for %s" % inst.uid)
				seen[inst.uid] = true


func test_unique_instance_ids_across_repeated_morning_deliveries() -> void:
	# Reproduces the bug where a second Morning Delivery on the same day reused
	# UIDs from the first batch because each ShopController call creates a fresh
	# DeliveryGenerator with a reset counter.
	GameState.set_debug_seed_override(7777)
	GameState.new_run()

	var first := _make_generator().generate_day_delivery(1)
	var first_ids := _uids_of(first)
	for inst in first:
		GameState.save_state.loop.inventory.append(inst.to_dictionary())

	var second := _make_generator().generate_day_delivery(1)
	var second_ids := _uids_of(second)
	for uid in second_ids:
		assert_false(
			first_ids.has(uid), "Second delivery reused UID %s already present in inventory" % uid
		)


func test_due_carrier_injected_on_assigned_day() -> void:
	GameState.set_debug_seed_override(7777)
	GameState.new_run()

	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	assert_true(plans.has("fragment_01"))

	var plan: Dictionary = plans["fragment_01"]
	var assigned_day: int = plan["day"]
	var generator := _make_generator()
	var delivery := generator.generate_day_delivery(assigned_day)

	var found := false
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			found = true
			break
	assert_true(found, "Carrier for fragment_01 must appear on assigned day %d" % assigned_day)

	# Other days must not contain the carrier.
	for day in range(1, 6):
		if day == assigned_day:
			continue
		var other := _make_generator().generate_day_delivery(day)
		for inst in other:
			assert_false(
				inst.is_carrier and inst.fragment_id == "fragment_01",
				"Carrier must not appear before its assigned day"
			)


func test_carrier_retains_ordinary_template_identity() -> void:
	GameState.set_debug_seed_override(8888)
	GameState.new_run()

	var director := SpawnDirector.new(_repo, GameState)
	var plans := director.plan_loop_placements()
	var plan: Dictionary = plans["fragment_01"]
	var template: ScrapObjectTemplate = _repo.get_template(plan["carrier_template_id"])

	var generator := _make_generator()
	var delivery := generator.generate_day_delivery(plan["day"])

	var carrier: ObjectInstance = null
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			carrier = inst
			break
	assert_not_null(carrier)
	assert_eq(carrier.template_id, template.id)
	assert_eq(carrier.is_carrier, true)
	assert_eq(carrier.contents, ModelEnums.OpenResult.FRAGMENT)


func test_invalid_anchor_falls_back_to_compatible_anchor() -> void:
	GameState.set_debug_seed_override(9999)
	GameState.new_run()

	GameState.save_state.loop.current_carrier_placements["fragment_01"] = {
		"fragment_id": "fragment_01",
		"carrier_template_id": "tarnished_pendant",
		"carrier_instance_id": "",
		"container_id": "nonexistent_container",
		"day": 1,
		"soft_reset": false,
	}

	var delivery := _make_generator().generate_day_delivery(1)
	var carrier: ObjectInstance = null
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			carrier = inst
			break
	assert_not_null(carrier)
	assert_ne(carrier.assigned_anchor_id, "nonexistent_container")
	var container: PlacementContainer = _repo.get_container(carrier.assigned_anchor_id)
	assert_not_null(container)


func test_full_anchor_falls_back_to_compatible_anchor() -> void:
	GameState.set_debug_seed_override(1010)
	GameState.new_run()

	# Force pile_left to report zero capacity so the carrier must fall back.
	var container: PlacementContainer = _repo.get_container("pile_left")
	container.capacity = 0

	var plan := {
		"fragment_id": "fragment_01",
		"carrier_template_id": "tarnished_pendant",
		"carrier_instance_id": "",
		"container_id": "pile_left",
		"day": 1,
		"soft_reset": false,
	}
	GameState.save_state.loop.current_carrier_placements["fragment_01"] = plan

	var delivery := _make_generator().generate_day_delivery(1)
	var carrier: ObjectInstance = null
	for inst in delivery:
		if inst.is_carrier and inst.fragment_id == "fragment_01":
			carrier = inst
			break
	assert_not_null(carrier)
	assert_ne(carrier.assigned_anchor_id, "pile_left", "Full anchor must fall back")


func _uids_of(instances: Array[ObjectInstance]) -> Array[String]:
	var out: Array[String] = []
	for inst in instances:
		out.append(inst.uid)
	return out


func test_common_rust_tarnish_artifacts_excluded_from_pool() -> void:
	# The Brass Hand Bell / Rusted Tin are white but need the rust path (Wire Brush /
	# tin_pry); with only the early tools they could never reach the bench, so they must
	# never enter the random delivery pool. This also covers future rust/tarnish commons.
	GameState.save_state.persistent.tutorial_completed = true  # disable the Day 0 whitelist
	var generator := _make_generator()
	# The helper flags the rust/tarnish path (Wire Brush / tin_pry).
	assert_true(generator._needs_rust_tarnish(_repo.get_template("brass_hand_bell")))
	assert_true(generator._needs_rust_tarnish(_repo.get_template("rusted_tin")))
	# Neither reported common ever appears in any rarity bucket of the delivery pool, and
	# no white template that needs the rust path survives the filter.
	var groups := generator._group_templates_by_rarity()
	for rarity in groups.keys():
		for template in groups[rarity]:
			assert_ne(str(template.id), "brass_hand_bell", "bell is banned from the pool")
			assert_ne(str(template.id), "rusted_tin", "rusted tin is banned from the pool")
			var is_white := generator._effective_rarity(template) == ModelEnums.Rarity.WHITE
			assert_false(
				is_white and generator._needs_rust_tarnish(template),
				"%s (white rust/tarnish) must be excluded" % template.id
			)
