extends GutTest

## Tests for ScannerService request contract, eligibility, and verdict
## persistence (P7.1, P7.4, P7.5).

const TEST_SAVE := "user://test_scanner_save.json"
const TEST_TEMP := "user://test_scanner_save.tmp"
const TEST_DATA := "user://test_scanner_data"

var _repo: DataRepository
var _service: ScannerService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("scanner-test-player")
	GameState.set_debug_seed_override(1234)
	GameState.new_run()
	_repo = DataRepository.singleton()
	_service = ScannerService.new()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	_cleanup_temp_data(TEST_DATA)


func _make_instance(template_id: String, state: int, is_carrier: bool = false) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = "inst_%s_01" % template_id
	inst.condition = 100.0 if state == ModelEnums.ObjState.CLEAN else 0.0
	inst.state = state
	inst.is_carrier = is_carrier
	inst.fragment_id = "fragment_01" if is_carrier else ""
	inst.contents = ModelEnums.OpenResult.FRAGMENT if is_carrier else ModelEnums.OpenResult.EMPTY
	inst.authenticity = ModelEnums.Verdict.UNKNOWN
	inst.is_counterfeit_truth = false
	inst.storage_cost = 1
	return inst


func _add_to_inventory(inst: ObjectInstance) -> void:
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


# ---------------------------------------------------------------------------
# Request contract
# ---------------------------------------------------------------------------


func test_request_has_required_prd_fields() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	var request := _service.create_request(inst)
	assert_false(request.request_id.is_empty(), "request_id is required")
	assert_eq(request.instance_id, inst.uid)
	assert_eq(request.template_id, inst.template_id)
	assert_eq(request.condition, inst.condition)
	assert_false(request.materials.is_empty(), "materials must be present")
	assert_eq(request.language, "en")
	assert_eq(request.schema_version, 1)


func test_request_excludes_hidden_truth_fields() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN, true)
	var request := _service.create_request(inst)
	assert_false(request.request_id.contains("carrier"))
	assert_false(request.request_id.contains(inst.fragment_id))
	var request_dict := request.to_dictionary()
	assert_false(request_dict.has("is_carrier"))
	assert_false(request_dict.has("fragment_id"))
	assert_false(request_dict.has("is_counterfeit_truth"))
	assert_false(request_dict.has("contents"))


func test_request_weight_uses_template_midpoint() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	var request := _service.create_request(inst)
	var template: ScrapObjectTemplate = _repo.get_template("tarnished_pendant")
	var expected := (template.weight_range.x + template.weight_range.y) / 2.0
	assert_eq(request.weight, expected)


# ---------------------------------------------------------------------------
# Eligibility and state
# ---------------------------------------------------------------------------


func test_dirty_object_cannot_be_scanned() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.DIRTY)
	assert_false(_service.can_scan(inst))
	var result := _service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.NOT_CLEAN)


func test_clean_object_can_be_scanned() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	assert_true(_service.can_scan(inst))
	var result := _service.scan(inst)
	assert_true(result.is_ok())


func test_non_decal_openable_at_96_percent_is_scannable() -> void:
	var inst := _make_instance("dusty_locket", ModelEnums.ObjState.DIRTY)
	inst.condition = 96.0
	assert_true(_service.can_scan(inst), "a 96%%-clean openable meets the 50%% scanner threshold")
	var result := _service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.SUCCESS)


func test_dirty_non_decal_openable_below_threshold_is_blocked() -> void:
	var inst := _make_instance("dusty_locket", ModelEnums.ObjState.DIRTY)
	inst.condition = 30.0
	assert_false(
		_service.can_scan(inst), "a 30%%-clean openable is below the 50%% scanner threshold"
	)
	var result := _service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.NOT_CLEAN)


func test_scanner_message_hides_threshold() -> void:
	var inst := _make_instance("dusty_locket", ModelEnums.ObjState.DIRTY)
	inst.condition = 10.0
	var result := _service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.NOT_CLEAN)
	assert_eq(result.response.transport_error, "Too dirty to be scanned — clean it more first.")
	assert_false(result.response.transport_error.contains("%"), "message must not show a percent")
	assert_true(
		result.response.transport_error.find("[0-9]") < 0, "message must not contain digits"
	)


func test_scanner_price_derived_from_template_range() -> void:
	var inst := _make_instance("dusty_locket", ModelEnums.ObjState.CLEAN)
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	var template: ScrapObjectTemplate = _repo.get_template("dusty_locket")
	assert_eq(result.response.price_range_min, int(template.base_value_range.x))
	assert_eq(result.response.price_range_max, int(template.base_value_range.y))


func test_scanner_conditions_derived_from_spawned_decals() -> void:
	var inst := _make_instance("dusty_locket", ModelEnums.ObjState.CLEAN)
	inst.spawned_decals = [
		{"id": "dust_1", "type": "dust", "color": "#C9C2B0", "required_tool": "soft_brush"},
		{
			"id": "tarnish_1",
			"type": "tarnish",
			"color": "#4A5240",
			"required_tool": "polishing_cloth"
		}
	]
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	assert_true(result.response.markings.has("Dust"), "markings should include spawned condition")
	assert_true(
		result.response.markings.has("Tarnish"), "markings should include spawned condition"
	)
	assert_true(
		result.response.condition_note.contains("Dust"), "condition note should describe conditions"
	)


func test_scanner_output_does_not_set_authenticity() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_add_to_inventory(inst)
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	var refreshed: ObjectInstance = _service.find_instance_by_id(inst.uid)
	assert_eq(refreshed.authenticity, ModelEnums.Verdict.UNKNOWN)


# ---------------------------------------------------------------------------
# Verdict persistence
# ---------------------------------------------------------------------------


func test_all_four_verdicts_can_be_committed() -> void:
	for verdict in [
		ModelEnums.Verdict.AUTHENTIC,
		ModelEnums.Verdict.REPLICA,
		ModelEnums.Verdict.MODIFIED,
		ModelEnums.Verdict.UNCERTAIN
	]:
		GameState.initialize("scanner-test-player")
		GameState.new_run()
		var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
		_add_to_inventory(inst)
		assert_true(_service.commit_verdict(inst.uid, verdict))
		var refreshed: ObjectInstance = _service.find_instance_by_id(inst.uid)
		assert_eq(refreshed.authenticity, verdict)


func test_player_can_contradict_scanner_implication() -> void:
	var inst := _make_instance("rusted_tin", ModelEnums.ObjState.CLEAN)
	_add_to_inventory(inst)
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	# The rusted_tin cache suggests modification/low confidence; player may still call it authentic.
	assert_true(_service.commit_verdict(inst.uid, ModelEnums.Verdict.AUTHENTIC))
	var refreshed: ObjectInstance = _service.find_instance_by_id(inst.uid)
	assert_eq(refreshed.authenticity, ModelEnums.Verdict.AUTHENTIC)


func test_confirmation_is_idempotent() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_add_to_inventory(inst)
	assert_true(_service.commit_verdict(inst.uid, ModelEnums.Verdict.MODIFIED))
	var first_loop := GameState.save_state.loop.inventory.size()
	assert_true(_service.commit_verdict(inst.uid, ModelEnums.Verdict.MODIFIED))
	var record: ScannedRecord = GameState.save_state.persistent.scanned_records["tarnished_pendant"]
	assert_eq(record.verdict, ModelEnums.Verdict.MODIFIED)
	assert_eq(GameState.save_state.loop.inventory.size(), first_loop)


func test_verdict_and_scan_record_survive_save_load() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_add_to_inventory(inst)
	_service.scan(inst)
	assert_true(_service.commit_verdict(inst.uid, ModelEnums.Verdict.AUTHENTIC))
	assert_true(SaveService.save_game().ok)

	GameState.initialize("scanner-test-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, str(load_result.get("error", "load failed")))
	var record: ScannedRecord = GameState.save_state.persistent.scanned_records["tarnished_pendant"]
	assert_eq(record.verdict, ModelEnums.Verdict.AUTHENTIC)
	assert_false(record.response_snapshot.is_empty())
	assert_false(record.response_snapshot.has("is_carrier"))


func test_scanned_record_survives_loop_reset() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	_add_to_inventory(inst)
	_service.scan(inst)
	_service.commit_verdict(inst.uid, ModelEnums.Verdict.REPLICA)
	GameState.reset_loop_state()
	var record: ScannedRecord = GameState.save_state.persistent.scanned_records["tarnished_pendant"]
	assert_eq(record.verdict, ModelEnums.Verdict.REPLICA)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _cleanup_temp_data(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir != null:
		dir.include_navigational = false
		dir.list_dir_begin()
		var item := dir.get_next()
		while not item.is_empty():
			var full := root.path_join(item)
			if dir.current_is_dir():
				_cleanup_temp_data(full)
				DirAccess.remove_absolute(full)
			else:
				DirAccess.remove_absolute(full)
			item = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(root)
