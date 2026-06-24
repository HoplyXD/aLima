extends GutTest

## Tests for RestorationService and the clean/open state machine (P4).
## Covers tool consequences, the clean gate, clasp opening, result resolution,
## instance isolation, persistence, and pause ownership.

const TEST_SAVE := "user://test_restoration_save.json"
const TEST_TEMP := "user://test_restoration_save.tmp"

var _repo: DataRepository
var _service: RestorationService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("restoration-test-player")
	GameState.set_debug_seed_override(7777)
	GameState.new_run()
	_repo = DataRepository.singleton()
	_service = RestorationService.new()
	_grant_starting_tools()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_starting_tools() -> void:
	GameState.save_state.loop.tool_items.append("soft_cloth")
	GameState.save_state.loop.tool_items.append("rust_brush")
	GameState.save_state.persistent.legacy_items.append("soft_cloth")
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")


func _add_instance(inst: ObjectInstance) -> void:
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _make_pendant(
	uid: String, is_carrier: bool = false, contents: int = ModelEnums.OpenResult.EMPTY
) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.is_carrier = is_carrier
	inst.fragment_id = "fragment_01" if is_carrier else ""
	inst.contents = contents
	inst.value = 120
	inst.storage_cost = 1
	return inst


func _make_tin(uid: String, contents: int = ModelEnums.OpenResult.EMPTY) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = "rusted_tin"
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.contents = contents
	inst.value = 10
	inst.storage_cost = 2
	return inst


## The shared-inventory rule: a non-openable artifact whose conditions are authored in its
## scene (no data decals) — like the Oton Death Mask — must still be a bench object, so an
## item delivered into storage can actually be restored. Regression for it showing in
## storage but missing from the restoration bench.
func test_authored_scene_artifact_is_restorable_without_data_decals() -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "oton_death_mask"  # is_openable=false, no data decals; scene-authored
	inst.uid = "oton_test"
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.storage_cost = 2
	inst.value = 800
	_add_instance(inst)

	var ids: Array[String] = []
	for restorable in _service.get_restorable_instances():
		ids.append(restorable.uid)
	assert_has(ids, "oton_test", "an authored-scene artifact appears on the bench, not just storage")


func test_instance_with_spawned_conditions_cleans_to_clean() -> void:
	GameState.save_state.loop.tool_items.append("soft_brush")  # treats dust
	var inst := _make_pendant("cond_pendant")
	inst.spawned_decals = [
		{"id": "dust_0", "type": "dust", "color": "#C9C2B0", "required_tool": "soft_brush"},
		{"id": "rust_1", "type": "rust", "color": "#B5511E", "required_tool": "rust_brush"},
	]
	_add_instance(inst)
	var template := _repo.get_template("tarnished_pendant")

	assert_true(
		_service.instance_is_decal_based(inst, template), "spawned conditions make it decal-based"
	)
	assert_eq(_service.effective_decals(inst, template).size(), 2)

	var r1 := _service.clean_decal("cond_pendant", "dust_0", "soft_brush")
	assert_true(r1.removed, "the matching tool removes the dust condition")
	assert_false(r1.reached_clean, "one condition still remains")

	var r2 := _service.clean_decal("cond_pendant", "rust_1", "rust_brush")
	assert_true(r2.reached_clean, "removing the last condition reaches CLEAN")
	assert_eq(
		_service.find_instance_by_id("cond_pendant").state,
		ModelEnums.ObjState.CLEAN,
		"the artifact is now clean"
	)


func test_bench_follows_loadout_once_instances_exist() -> void:
	# Id-set-only tools (no durability instances) still show via the legacy fallback.
	assert_gt(_service.get_workbench_tools().size(), 0, "id-set tools show via fallback")

	# Granting a durability instance auto-equips it; the bench now follows the loadout.
	var tools := ToolService.new(GameState, _repo)
	var inst := tools.grant_tool("rust_brush")
	var ids: Array = []
	for tool in _service.get_workbench_tools():
		ids.append(tool.id)
	assert_true(ids.has("rust_brush"), "an auto-equipped instance shows on the bench")

	# Removing it from the bench keeps it gone — no fallback re-adds it.
	tools.remove_from_workbench(inst.uid)
	assert_eq(_service.get_workbench_tools().size(), 0, "an emptied loadout shows no tools")


func _reload_state() -> void:
	SaveService.save_game()
	GameState.initialize("other-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Load should succeed: %s" % load_result.get("error", ""))
	_service = RestorationService.new()


func test_dirty_openables_reject_open_including_carrier() -> void:
	var ordinary := _make_pendant("pendant_01")
	var carrier := _make_pendant("carrier_01", true, ModelEnums.OpenResult.FRAGMENT)
	_add_instance(ordinary)
	_add_instance(carrier)

	var ordinary_result := _service.open_clasp("pendant_01")
	assert_false(ordinary_result.ok)
	assert_true(ordinary_result.error.find("dirty") >= 0)

	var carrier_result := _service.open_clasp("carrier_01")
	assert_false(carrier_result.ok)
	assert_true(carrier_result.error.find("dirty") >= 0)
	assert_eq(_service.find_instance_by_id("carrier_01").state, ModelEnums.ObjState.DIRTY)


func test_compatible_tool_deterministically_reaches_clean() -> void:
	var inst := _make_pendant("pendant_02")
	_add_instance(inst)
	var reached := false
	for i in range(10):
		var result := _service.apply_tool("pendant_02", "soft_cloth")
		assert_true(result.ok)
		if result.reached_clean:
			reached = true
			break
	assert_true(reached, "Correct tool must reach CLEAN within authored bounds")
	assert_eq(_service.find_instance_by_id("pendant_02").state, ModelEnums.ObjState.CLEAN)


func test_condition_remains_within_zero_to_one_hundred() -> void:
	var inst := _make_pendant("pendant_03")
	_add_instance(inst)
	for i in range(10):
		_service.apply_tool("pendant_03", "rust_brush")
	var damaged := _service.find_instance_by_id("pendant_03")
	assert_eq(damaged.condition, 0.0, "Condition must be clamped at 0")

	for i in range(10):
		_service.apply_tool("pendant_03", "soft_cloth")
	var cleaned := _service.find_instance_by_id("pendant_03")
	assert_true(cleaned.condition <= 100.0, "Condition must be clamped at the completion threshold")


func test_correct_tool_modifies_value_within_authored_bounds() -> void:
	var inst := _make_pendant("pendant_04")
	_add_instance(inst)
	var result := _service.apply_tool("pendant_04", "soft_cloth")
	assert_true(result.ok)
	assert_true(result.compatible)
	var after := _service.find_instance_by_id("pendant_04")
	assert_true(after.value >= 120, "Value must not fall below the template minimum")
	assert_true(after.value <= 280, "Value must not exceed the template maximum")


func test_wrong_tool_records_persistent_instance_damage() -> void:
	var inst := _make_pendant("pendant_05")
	inst.condition = 50.0
	inst.value = 200
	_add_instance(inst)
	var before_condition := inst.condition
	var before_value := inst.value
	var result := _service.apply_tool("pendant_05", "rust_brush")
	assert_true(result.ok)
	assert_false(result.compatible)
	var after := _service.find_instance_by_id("pendant_05")
	assert_gt(after.recorded_damage, 0, "Wrong tool must record damage")
	assert_lt(after.condition, before_condition, "Wrong tool must lower condition")
	assert_lt(after.value, before_value, "Wrong tool must lower value")


func test_wrong_tool_feedback_is_distinguishable() -> void:
	var inst := _make_pendant("pendant_06")
	_add_instance(inst)
	var wrong := _service.apply_tool("pendant_06", "rust_brush")
	var right := _service.apply_tool("pendant_06", "soft_cloth")
	assert_false(wrong.compatible)
	assert_true(right.compatible)
	assert_false(wrong.feedback.is_empty())
	assert_false(right.feedback.is_empty())
	assert_ne(wrong.feedback, right.feedback, "Feedback must distinguish wrong-tool use")


func test_damage_survives_serialization_round_trips() -> void:
	var inst := _make_pendant("pendant_07")
	_add_instance(inst)
	_service.apply_tool("pendant_07", "rust_brush")
	var before_save := _service.find_instance_by_id("pendant_07").recorded_damage
	_reload_state()
	var after_load := _service.find_instance_by_id("pendant_07")
	assert_not_null(after_load)
	assert_eq(after_load.recorded_damage, before_save, "Damage must survive save/load")


func test_restoration_changes_only_the_selected_instance() -> void:
	var a := _make_pendant("pendant_a")
	var b := _make_pendant("pendant_b")
	_add_instance(a)
	_add_instance(b)
	_service.apply_tool("pendant_a", "soft_cloth")
	var after_a := _service.find_instance_by_id("pendant_a")
	var after_b := _service.find_instance_by_id("pendant_b")
	assert_gt(after_a.condition, 0.0)
	assert_eq(after_b.condition, 0.0)
	assert_eq(after_b.recorded_damage, 0)


func test_clean_pendant_can_open() -> void:
	var inst := _make_pendant("pendant_08")
	_add_instance(inst)
	while _service.find_instance_by_id("pendant_08").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("pendant_08", "soft_cloth")
	var result := _service.open_clasp("pendant_08")
	assert_true(result.ok)
	assert_eq(_service.find_instance_by_id("pendant_08").state, ModelEnums.ObjState.OPEN)


func test_clasp_interaction_is_distinct_from_cleaning_completion() -> void:
	var inst := _make_pendant("pendant_09")
	_add_instance(inst)
	while _service.find_instance_by_id("pendant_09").state == ModelEnums.ObjState.DIRTY:
		var r := _service.apply_tool("pendant_09", "soft_cloth")
		assert_false(
			(
				r.state_changed
				and _service.find_instance_by_id("pendant_09").state == ModelEnums.ObjState.OPEN
			)
		)
	assert_eq(_service.find_instance_by_id("pendant_09").state, ModelEnums.ObjState.CLEAN)
	_service.open_clasp("pendant_09")
	assert_eq(_service.find_instance_by_id("pendant_09").state, ModelEnums.ObjState.OPEN)


func test_opening_is_single_use_and_idempotent() -> void:
	var inst := _make_pendant("pendant_10", true, ModelEnums.OpenResult.FRAGMENT)
	_add_instance(inst)
	while _service.find_instance_by_id("pendant_10").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("pendant_10", "soft_cloth")
	var first := _service.open_clasp("pendant_10")
	assert_true(first.ok)
	assert_eq(first.result, ModelEnums.OpenResult.FRAGMENT)
	var second := _service.open_clasp("pendant_10")
	assert_false(second.ok)
	assert_true(second.error.find("Already") >= 0)


func test_only_carrier_produces_fragment_and_retains_template_identity() -> void:
	var ordinary := _make_pendant("ordinary_01", false, ModelEnums.OpenResult.EMPTY)
	var carrier := _make_pendant("carrier_03", true, ModelEnums.OpenResult.FRAGMENT)
	_add_instance(ordinary)
	_add_instance(carrier)
	while _service.find_instance_by_id("ordinary_01").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("ordinary_01", "soft_cloth")
	while _service.find_instance_by_id("carrier_03").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("carrier_03", "soft_cloth")

	assert_eq(_service.open_clasp("ordinary_01").result, ModelEnums.OpenResult.EMPTY)
	assert_eq(_service.open_clasp("carrier_03").result, ModelEnums.OpenResult.FRAGMENT)

	var template: ScrapObjectTemplate = _repo.get_template(carrier.template_id)
	assert_eq(carrier.template_id, "tarnished_pendant")
	assert_eq(template.openable_type, "pendant")
	assert_false(template.can_hold_temporal_echo)


func test_empty_temporal_echo_and_fragment_resolve_correctly() -> void:
	var empty := _make_pendant("res_empty", false, ModelEnums.OpenResult.EMPTY)
	var echo := _make_tin("res_echo", ModelEnums.OpenResult.TEMPORAL_ECHO)
	var fragment := _make_pendant("res_fragment", true, ModelEnums.OpenResult.FRAGMENT)
	_add_instance(empty)
	_add_instance(echo)
	_add_instance(fragment)

	while _service.find_instance_by_id("res_empty").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("res_empty", "soft_cloth")
	while _service.find_instance_by_id("res_echo").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("res_echo", "rust_brush")
	while _service.find_instance_by_id("res_fragment").state == ModelEnums.ObjState.DIRTY:
		_service.apply_tool("res_fragment", "soft_cloth")

	assert_eq(_service.open_clasp("res_empty").result, ModelEnums.OpenResult.EMPTY)
	assert_eq(_service.open_clasp("res_echo").result, ModelEnums.OpenResult.TEMPORAL_ECHO)
	assert_eq(_service.open_clasp("res_fragment").result, ModelEnums.OpenResult.FRAGMENT)


func test_recycled_or_unavailable_instances_cannot_enter_restoration() -> void:
	var result_tool := _service.apply_tool("missing_uid", "soft_cloth")
	assert_false(result_tool.ok)
	assert_true(result_tool.feedback.find("not found") >= 0)

	var result_open := _service.open_clasp("missing_uid")
	assert_false(result_open.ok)
	assert_true(result_open.error.find("not found") >= 0)


func test_restoration_pause_does_not_resume_clock_held_by_another_owner() -> void:
	DayClock.reset()
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	DayClock.request_pause(DayClock.PAUSE_RESTORATION)
	assert_true(DayClock.is_paused())
	DayClock.release_pause(DayClock.PAUSE_RESTORATION)
	assert_true(DayClock.is_paused(), "Releasing restoration must not resume a dialogue-held clock")
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
	assert_false(DayClock.is_paused())


func test_invalid_tool_reference_fails_repository_validation() -> void:
	var repo := DataRepository.new()
	var load_result := repo.load_from_filesystem()
	assert_true(load_result.is_valid())
	var bad_template: ScrapObjectTemplate = repo.scrap_object_templates["tarnished_pendant"]
	bad_template.required_clean_tool = "nonexistent_tool"
	repo._validate_cross_references()
	assert_false(repo.get_validation_result().is_valid())
	assert_true(_errors_contain(repo.get_validation_result(), "unknown tool"))


func test_invalid_technique_reference_fails_repository_validation() -> void:
	var repo := DataRepository.new()
	var load_result := repo.load_from_filesystem()
	assert_true(load_result.is_valid())
	repo.starting_kit["technique_ids"] = ["nonexistent_technique"]
	repo._validate_cross_references()
	assert_false(repo.get_validation_result().is_valid())
	assert_true(_errors_contain(repo.get_validation_result(), "unknown technique"))


func _errors_contain(result: ValidationResult, snippet: String) -> bool:
	for err in result.errors():
		if err.find(snippet) >= 0:
			return true
	return false
