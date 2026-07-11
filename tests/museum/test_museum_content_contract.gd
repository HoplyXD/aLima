extends GutTest
## Tests for the museum content contract: counts, source_ref presence,
## verification-status rules, and source-resolution gating (§4-L, CONTENT-R9).


func test_live_museum_records_meet_phase_16_counts() -> void:
	var result := MuseumContentValidator.validate_file("res://data/museum/museum_records.json")
	assert_true(result.valid, "Contract must be structurally valid: " + ", ".join(result.errors))
	assert_eq(result.errors.size(), 0)


func test_pending_records_are_allowed_without_source_file() -> void:
	var data := {
		"schema_version": 1,
		"records":
		[
			{
				"id": "test_pending",
				"record_type": "gold_discovery",
				"subject_ref": "",
				"title": "Test pending",
				"fact_card": "SOURCE VERIFICATION PENDING — test.",
				"source_ref": "planned_source",
				"verification_status": "source-verification-pending"
			}
		]
	}
	var result := MuseumContentValidator.validate_data(data, "", true)
	assert_true(result.valid)
	assert_eq(result.errors.size(), 0)
	assert_true(result.warnings.size() > 0, "pending status should produce a warning")


func test_verified_record_requires_source_file() -> void:
	var data := {
		"schema_version": 1,
		"records":
		[
			{
				"id": "test_verified_no_source",
				"record_type": "gold_discovery",
				"subject_ref": "",
				"title": "Test verified",
				"fact_card": "A verified fact.",
				"source_ref": "definitely_missing_source",
				"verification_status": "verified"
			}
		]
	}
	var result := MuseumContentValidator.validate_data(data, "", true)
	assert_false(result.valid)
	assert_true(
		result.errors.any(func(e: String) -> bool: return e.contains("does not resolve")),
		"verified record must resolve its source file"
	)


func test_verified_record_cannot_have_pending_placeholder_text() -> void:
	var data := {
		"schema_version": 1,
		"records":
		[
			{
				"id": "test_verified_pending_text",
				"record_type": "gold_discovery",
				"subject_ref": "",
				"title": "Test verified text",
				"fact_card": "SOURCE VERIFICATION PENDING — should not be marked verified.",
				"source_ref": "pending",
				"verification_status": "verified"
			}
		]
	}
	var result := MuseumContentValidator.validate_data(data, "", true)
	assert_false(result.valid)
	assert_true(
		result.errors.any(func(e: String) -> bool: return e.contains("pending placeholder"))
	)


func test_duplicate_record_ids_fail() -> void:
	var data := {
		"schema_version": 1,
		"records":
		[
			{
				"id": "dup",
				"record_type": "gold_discovery",
				"fact_card": "One.",
				"source_ref": "s1",
				"verification_status": "source-verification-pending"
			},
			{
				"id": "dup",
				"record_type": "gold_discovery",
				"fact_card": "Two.",
				"source_ref": "s2",
				"verification_status": "source-verification-pending"
			}
		]
	}
	var result := MuseumContentValidator.validate_data(data, "", true)
	assert_false(result.valid)
	assert_true(result.errors.any(func(e: String) -> bool: return e.contains("Duplicate")))
