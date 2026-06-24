extends GutTest

## Tests for the ContentManifest model + ContentManifestValidator (P12.3/P12.4).
##
## Strategy (per the agreed CI design): assert the validator's BEHAVIOR against
## temp fixtures — a fully accepted manifest passes; a deliberately broken /
## incomplete manifest fails with specific, field-named, one-pass-accumulated
## errors — and separately assert that the REAL committed manifest is currently
## blocked by PENDING_TEAM_DECISION (a passing test that expects failure). This
## keeps the full GUT suite green while the live blocker stays loud.

const TEMP_ROOT: String = "user://test_content_manifest"

# Content that already exists in the repository (must match data/buyers + events).
const REAL_BUYERS: Array[String] = [
	"collector",
	"reseller",
	"student",
	"gift",
	"hobbyist",
	"appraiser",
	"tourist",
	"lola",
	"suspicious",
]
const REAL_EVENTS: Array[String] = [
	"rush_delivery",
	"sudden_brownout",
	"community_request",
	"suspicious_antique",
	"rare_buyer_alert",
	"mystery_box",
	"rainy_day_leak",
	"tool_breakdown",
]

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()
	_make_dir(TEMP_ROOT)
	_make_dir(TEMP_ROOT.path_join("packets"))
	_make_dir(TEMP_ROOT.path_join("provenance"))
	_make_dir(TEMP_ROOT.path_join("sources"))
	_make_dir(TEMP_ROOT.path_join("reviews"))


func after_each() -> void:
	_cleanup(TEMP_ROOT)


# --- Model structural validation ------------------------------------------

func test_model_round_trip_preserves_fields() -> void:
	var manifest := ContentManifest.from_dictionary(_accepted_manifest_dict())
	var round := ContentManifest.from_dictionary(manifest.to_dictionary())
	assert_eq(round.id, manifest.id)
	assert_eq(round.required_min("buyer_personas"), 6)
	assert_eq(round.content_ids("buyer_personas").size(), REAL_BUYERS.size())
	assert_eq(round.decision_refs.size(), manifest.decision_refs.size())


func test_model_flags_placeholder_content_id() -> void:
	var data := _accepted_manifest_dict()
	data["content"]["counterfeits"] = ["PLACEHOLDER_counterfeit"]
	var manifest := ContentManifest.from_dictionary(data)
	var result := manifest.validate()
	assert_false(result.is_valid())
	assert_true(_contains(result.errors(), "placeholder production id"))


# --- Validator: accepted manifest -----------------------------------------

func test_accepted_fixture_passes() -> void:
	var validator := _validator_for(
		_accepted_manifest_dict(), _resolved_decisions(), _resolved_packet()
	)
	var result := validator.validate()
	assert_true(result.is_valid(), "Accepted manifest should pass: %s" % str(result.errors()))


# --- Validator: broken / incomplete manifest ------------------------------

func test_broken_fixture_fails_with_named_errors() -> void:
	var manifest := _accepted_manifest_dict()
	# 1. Drop a non-deferred count below its minimum.
	manifest["content"]["buyer_personas"] = ["collector", "reseller"]
	# 2. Break a repository reference.
	manifest["content"]["named_events"] = REAL_EVENTS.duplicate()
	manifest["content"]["named_events"].append("not_a_real_event")
	# 3. Inject a placeholder production id.
	manifest["content"]["counterfeits"] = ["TODO_counterfeit_01"]

	# 4. Leave one design decision unresolved.
	var decisions := _resolved_decisions()
	decisions["items"][0]["status"] = "PENDING_TEAM_DECISION"

	var validator := _validator_for(manifest, decisions, _resolved_packet())
	var result := validator.validate()
	var errors := result.errors()

	assert_false(result.is_valid())
	assert_gt(errors.size(), 1, "Errors must accumulate in one pass: %s" % str(errors))
	assert_true(_contains(errors, "insufficient count"), "names dropped count")
	assert_true(_contains(errors, "unknown named_events reference"), "names broken ref")
	assert_true(_contains(errors, "placeholder production id"), "names placeholder id")
	assert_true(_contains(errors, "unresolved"), "names PENDING decision")


func test_lowered_requirement_below_gdd_floor_fails() -> void:
	var manifest := _accepted_manifest_dict()
	manifest["requirements"]["object_templates"]["min"] = 5
	var validator := _validator_for(manifest, _resolved_decisions(), _resolved_packet())
	var result := validator.validate()
	assert_false(result.is_valid())
	assert_true(_contains(result.errors(), "below the GDD floor"))


func test_omitted_required_category_fails() -> void:
	var manifest := _accepted_manifest_dict()
	manifest["requirements"].erase("temporal_echoes")
	var validator := _validator_for(manifest, _resolved_decisions(), _resolved_packet())
	var result := validator.validate()
	assert_false(result.is_valid())
	assert_true(_contains(result.errors(), "omits required category 'temporal_echoes'"))


func test_pending_artifact_packet_fails() -> void:
	var packet := _resolved_packet()
	packet["status"] = "PENDING_TEAM_DECISION"
	var validator := _validator_for(_accepted_manifest_dict(), _resolved_decisions(), packet)
	var result := validator.validate()
	assert_false(result.is_valid())
	assert_true(_contains(result.errors(), "artifact lock is unresolved"))


func test_missing_provenance_records_fail() -> void:
	var manifest := _accepted_manifest_dict()
	manifest["provenance_refs"] = []
	var validator := _validator_for(manifest, _resolved_decisions(), _resolved_packet())
	var result := validator.validate()
	assert_false(result.is_valid())
	assert_true(_contains(result.errors(), "no provenance_refs records declared"))


# --- Live manifest: must be blocked by PENDING ----------------------------

func test_live_manifest_is_blocked_by_pending() -> void:
	# Uses the real committed paths. The manifest is committed in a PENDING state,
	# so it must fail validation, and the failure must name an unresolved decision
	# or the unresolved artifact lock.
	var validator := ContentManifestValidator.new()
	validator.repo = _repo
	var result := validator.validate()
	assert_false(result.is_valid(), "Live manifest must stay blocked while PENDING")
	assert_true(
		_contains(result.errors(), "unresolved"),
		"Live blocker must name a PENDING decision/artifact: %s" % str(result.errors())
	)


# --- Fixture builders ------------------------------------------------------

func _validator_for(
	manifest: Dictionary, decisions: Dictionary, packet: Dictionary
) -> ContentManifestValidator:
	_write_json(TEMP_ROOT.path_join("content-manifest.json"), manifest)
	_write_json(TEMP_ROOT.path_join("decisions.json"), decisions)
	var packet_ref: String = manifest["artifact_packet_ref"]
	_write_json(TEMP_ROOT.path_join("packets").path_join("%s.json" % packet_ref), packet)
	for ref in manifest.get("provenance_refs", []):
		_write_record(TEMP_ROOT.path_join("provenance").path_join("%s.md" % ref))
	for ref in manifest.get("source_refs", []):
		_write_record(TEMP_ROOT.path_join("sources").path_join("%s.md" % ref))
	for ref in manifest.get("review_refs", []):
		_write_record(TEMP_ROOT.path_join("reviews").path_join("%s.md" % ref))

	var validator := ContentManifestValidator.new()
	validator.manifest_path = TEMP_ROOT.path_join("content-manifest.json")
	validator.decisions_path = TEMP_ROOT.path_join("decisions.json")
	validator.artifact_packet_dir = TEMP_ROOT.path_join("packets")
	validator.provenance_dir = TEMP_ROOT.path_join("provenance")
	validator.source_dir = TEMP_ROOT.path_join("sources")
	validator.review_dir = TEMP_ROOT.path_join("reviews")
	validator.repo = _repo
	return validator


func _accepted_manifest_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "content_manifest",
		"requirements": {
			"object_templates": {"min": 30, "deferred_to_phase": "13"},
			"restoration_interactions": {"min": 9, "deferred_to_phase": "13"},
			"carrier_candidates": {"min": 15, "deferred_to_phase": "14"},
			"compatible_candidates_per_fragment": {"min": 3, "deferred_to_phase": "14"},
			"counterfeits": {"min": 6, "deferred_to_phase": "13"},
			"temporal_echoes": {"min": 15, "deferred_to_phase": "15"},
			"mystery_pages": {"min": 10, "deferred_to_phase": "15"},
			"route_beats_per_route": {"min": 3, "deferred_to_phase": "16"},
			"buyer_personas": {"min": 6, "deferred_to_phase": ""},
			"named_events": {"min": 8, "deferred_to_phase": ""},
			"fragment_fact_cards": {"min": 5, "deferred_to_phase": "17"},
			"assembled_records": {"min": 1, "deferred_to_phase": "17"},
			"gold_discoveries": {"min": 5, "deferred_to_phase": "17"},
		},
		"content": {
			"buyer_personas": REAL_BUYERS.duplicate(),
			"named_events": REAL_EVENTS.duplicate(),
			"counterfeits": [],
		},
		"artifact_packet_ref": "artifact_lock",
		"decision_refs": ["D_alpha", "D_beta"],
		"provenance_refs": ["artifact_provenance"],
		"source_refs": ["artifact_sources"],
		"review_refs": ["cultural_review"],
	}


func _resolved_decisions() -> Dictionary:
	return {
		"schema_version": 1,
		"items": [
			{"id": "D_alpha", "status": "RESOLVED"},
			{"id": "D_beta", "status": "RESOLVED"},
		],
	}


func _resolved_packet() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "artifact_lock",
		"status": "RESOLVED",
		"artifact": {"id": "locked_artifact_demo", "display_name": "Locked Demo"},
		"natural_components": [
			{"slot_index": 0, "id": "component_0"},
			{"slot_index": 1, "id": "component_1"},
			{"slot_index": 2, "id": "component_2"},
			{"slot_index": 3, "id": "component_3"},
			{"slot_index": 4, "id": "component_4"},
		],
		"source_refs": ["artifact_sources"],
		"folklore_labels": ["oral_tradition"],
		"reviewer_refs": ["cultural_review"],
		"approval_date": "2026-06-25",
	}


# --- File helpers ----------------------------------------------------------

func _make_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _write_record(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("# Record stub\n")
	f.close()


func _cleanup(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.include_navigational = false
	dir.list_dir_begin()
	var item := dir.get_next()
	while not item.is_empty():
		var full := root.path_join(item)
		if dir.current_is_dir():
			_cleanup(full)
			DirAccess.remove_absolute(full)
		else:
			DirAccess.remove_absolute(full)
		item = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(root)


func _contains(errors: Array[String], snippet: String) -> bool:
	for err in errors:
		if err.find(snippet) >= 0:
			return true
	return false
