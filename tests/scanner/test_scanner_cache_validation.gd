extends GutTest

## Cache coverage, transport boundary, and validation tests for the scanner
## (P7.2, P7.5).

const TEST_SAVE := "user://test_scanner_cache_save.json"
const TEST_TEMP := "user://test_scanner_cache_save.tmp"
const TEST_DATA := "user://test_scanner_cache_data"

var _repo: DataRepository
var _service: ScannerService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("scanner-cache-test-player")
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
# Cache coverage and response shape
# ---------------------------------------------------------------------------


func test_every_slice_template_has_cache_response() -> void:
	var expected := [
		"tarnished_pendant", "rusted_tin", "cracked_photo_frame", "small_santo", "dusty_locket"
	]
	for template_id in expected:
		var entry: ScannerCacheEntry = _repo.get_scanner_cache(template_id)
		assert_not_null(entry, "cache missing for %s" % template_id)
		assert_eq(entry.template_id, template_id)


func test_cached_response_parses_into_shared_response_model() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN)
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	assert_eq(result.status, ScannerResult.Status.SUCCESS)
	var response := result.response
	assert_true(response is ScannerResponse)
	assert_false(response.type.is_empty())
	assert_false(response.period.is_empty())
	assert_false(response.materials.is_empty())
	assert_false(response.condition_note.is_empty())
	assert_true(response.price_range_max >= response.price_range_min)


func test_promoted_carrier_receives_ordinary_template_response() -> void:
	var inst := _make_instance("tarnished_pendant", ModelEnums.ObjState.CLEAN, true)
	var result := _service.scan(inst)
	assert_true(result.is_ok())
	assert_eq(result.response.type, "pendant")
	assert_false(result.response.request_id.contains("fragment"))


# ---------------------------------------------------------------------------
# Transport boundary
# ---------------------------------------------------------------------------


func test_cache_and_http_transport_return_same_response_type() -> void:
	var cache := ScannerCacheTransport.new(_repo)
	var http := ScannerHttpTransport.new("http://localhost:3000")
	var request := ScannerRequest.new()
	request.template_id = "tarnished_pendant"
	request.request_id = "test"
	var cache_result := cache.submit(request)
	var http_result := http.submit(request)
	assert_true(cache_result.get("response") is ScannerResponse)
	# HTTP stub returns an error, but still returns a ScannerResponse.
	assert_true(http_result.get("response") is ScannerResponse)


# ---------------------------------------------------------------------------
# Validation errors
# ---------------------------------------------------------------------------


func test_duplicate_cache_ids_fail_validation() -> void:
	var repo := _broken_repository_with_duplicate_cache()
	var result := repo.get_validation_result()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result.errors(), "duplicate"))


func test_unknown_template_reference_fails_validation() -> void:
	var repo := _broken_repository_with_unknown_cache_template()
	var result := repo.get_validation_result()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result.errors(), "unknown template"))


func test_malformed_required_fields_fail_validation() -> void:
	var entry := _make_cache_entry(
		{"type": "", "period": "x", "materials": [], "price_range": [0, 0]}
	)
	var result := entry.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result.errors(), "type is required"))
	assert_true(_errors_contain(result.errors(), "materials are required"))


func test_invalid_price_range_fails_validation() -> void:
	var entry := _make_cache_entry({"price_range": [300, 100]})
	var result := entry.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result.errors(), "invalid price range"))


func test_invalid_source_reference_fails_validation() -> void:
	var entry := _make_cache_entry({"source_references": [{"status": "mystery"}]})
	var result := entry.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result.errors(), "verified or unverified"))


# ---------------------------------------------------------------------------
# Missing / malformed cache
# ---------------------------------------------------------------------------


func test_missing_cache_produces_controlled_error() -> void:
	var inst := _make_instance("missing_template", ModelEnums.ObjState.CLEAN)
	var result := _service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.MISSING_CACHE)
	assert_false(result.response.transport_error.is_empty())


func test_malformed_cache_does_not_crash_or_invent_response() -> void:
	var repo := _repo_with_malformed_cache()
	var service := ScannerService.new(ScannerCacheTransport.new(repo))
	var inst := _make_instance("bad_template", ModelEnums.ObjState.CLEAN)
	var result := service.scan(inst)
	assert_eq(result.status, ScannerResult.Status.MALFORMED_RESPONSE)
	assert_false(result.response.ok)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_cache_entry(response_overrides: Dictionary) -> ScannerCacheEntry:
	var base := {
		"type": "test",
		"period": "test",
		"materials": ["a"],
		"markings": [],
		"condition_note": "test",
		"cultural_relevance": "test",
		"price_range": [1, 2],
		"modification_signs": [],
		"confidence": "uncertain",
		"source_references": [{"status": "unverified", "note": "dev"}],
	}
	for key in response_overrides.keys():
		base[key] = response_overrides[key]
	var data := {"id": "test_template", "template_id": "test_template", "response": base}
	return ScannerCacheEntry.from_dictionary(data)


func _broken_repository_with_duplicate_cache() -> DataRepository:
	var repo := DataRepository.new()
	repo._validation = ValidationResult.new()
	repo.scrap_object_templates["test_template"] = _make_dummy_template("test_template")
	var entry := ScannerCacheEntry.from_dictionary(
		{"id": "test_template", "template_id": "test_template", "response": _valid_response()}
	)
	repo.scanner_cache_entries["test_template"] = entry
	repo._add_record(repo.scanner_cache_entries, "test_template", entry, "test", "scanner_cache")
	repo._validate_cross_references()
	return repo


func _broken_repository_with_unknown_cache_template() -> DataRepository:
	var repo := DataRepository.new()
	repo._validation = ValidationResult.new()
	var entry := ScannerCacheEntry.from_dictionary(
		{"id": "ghost_template", "template_id": "ghost_template", "response": _valid_response()}
	)
	repo.scanner_cache_entries["ghost_template"] = entry
	repo._validate_cross_references()
	return repo


func _repo_with_malformed_cache() -> DataRepository:
	var repo := DataRepository.new()
	repo._validation = ValidationResult.new()
	repo.scrap_object_templates["bad_template"] = _make_dummy_template("bad_template")
	var entry := (
		ScannerCacheEntry
		. from_dictionary(
			{
				"id": "bad_template",
				"template_id": "bad_template",
				"response": {"type": "", "period": "", "materials": [], "price_range": [0, 0]},
			}
		)
	)
	repo.scanner_cache_entries["bad_template"] = entry
	return repo


func _make_dummy_template(id: String) -> ScrapObjectTemplate:
	return (
		ScrapObjectTemplate
		. from_dictionary(
			{
				"id": id,
				"display_name": "Dummy",
				"category": "test",
				"base_rarity": "white",
				"weight_range": [1.0, 2.0],
				"materials": ["a"],
				"tags": ["test"],
				"is_openable": false,
				"base_value_range": [1, 2],
				"can_hold_temporal_echo": false,
			}
		)
	)


func _valid_response() -> Dictionary:
	return {
		"type": "test",
		"period": "test",
		"materials": ["a"],
		"markings": [],
		"condition_note": "test",
		"cultural_relevance": "test",
		"price_range": [1, 2],
		"modification_signs": [],
		"confidence": "uncertain",
		"source_references": [{"status": "unverified", "note": "dev"}],
	}


func _errors_contain(errors: Array[String], snippet: String) -> bool:
	for err in errors:
		if err.find(snippet) >= 0:
			return true
	return false


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
