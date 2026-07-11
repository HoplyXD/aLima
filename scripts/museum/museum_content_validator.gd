class_name MuseumContentValidator
## Validates the artifact-agnostic museum content contract in
## data/museum/museum_records.json.
##
## Final museum facts are gated on verified sources (docs/sources/, §4-L) and the
## Phase 12 artifact lock. This validator enforces the structural contract and
## refuses to treat unverified AI/placeholder text as a verified source of fact.

const RECORD_TYPES: Array[String] = ["fragment_fact_card", "assembled_artifact", "gold_discovery"]
const VALID_STATUSES: Array[String] = [
	"source-verification-pending", "artifact-lock-pending", "verified"
]
const MIN_FRAGMENT_FACTS: int = 5
const MIN_GOLD_DISCOVERIES: int = 5
const EXPECTED_ASSEMBLED: int = 1


## Validates the museum records file at the given path. Returns a result dict:
## { valid: bool, errors: Array[String], warnings: Array[String] }.
static func validate_file(file_path: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if not FileAccess.file_exists(file_path):
		errors.append("Museum records file not found: %s" % file_path)
		return {"valid": false, "errors": errors, "warnings": warnings}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open museum records file: %s" % file_path)
		return {"valid": false, "errors": errors, "warnings": warnings}

	var json := JSON.new()
	var parse_err := json.parse(file.get_as_text())
	if parse_err != OK:
		errors.append("Invalid JSON in %s: %s" % [file_path, json.get_error_message()])
		return {"valid": false, "errors": errors, "warnings": warnings}

	return validate_data(json.data as Dictionary, file_path)


## Validates already-parsed museum records data. `skip_counts` is useful in
## unit tests that only exercise per-record rules.
static func validate_data(
	data: Dictionary, file_path: String = "", skip_counts: bool = false
) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if data.get("schema_version", 0) != 1:
		errors.append("schema_version must be 1")

	var records_raw = data.get("records", [])
	if not records_raw is Array:
		errors.append("'records' must be an array")
		return {"valid": false, "errors": errors, "warnings": warnings}

	var records: Array = records_raw
	if records.size() == 0:
		errors.append("'records' is empty")

	var seen_ids: Dictionary = {}
	var counts: Dictionary = {
		"fragment_fact_card": 0,
		"assembled_artifact": 0,
		"gold_discovery": 0,
	}

	for i in range(records.size()):
		var raw = records[i]
		if not raw is Dictionary:
			errors.append("Record %d is not an object" % i)
			continue
		var record: Dictionary = raw
		_validate_record(record, i, file_path, seen_ids, errors, warnings)
		var t: String = record.get("record_type", "")
		if counts.has(t):
			counts[t] += 1

	if skip_counts:
		return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}

	if counts["fragment_fact_card"] < MIN_FRAGMENT_FACTS:
		errors.append(
			(
				"Need at least %d fragment_fact_card records; found %d"
				% [MIN_FRAGMENT_FACTS, counts["fragment_fact_card"]]
			)
		)
	if counts["assembled_artifact"] < EXPECTED_ASSEMBLED:
		errors.append(
			(
				"Need at least %d assembled_artifact record; found %d"
				% [EXPECTED_ASSEMBLED, counts["assembled_artifact"]]
			)
		)
	if counts["gold_discovery"] < MIN_GOLD_DISCOVERIES:
		errors.append(
			(
				"Need at least %d gold_discovery records; found %d"
				% [MIN_GOLD_DISCOVERIES, counts["gold_discovery"]]
			)
		)

	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}


static func _validate_record(
	record: Dictionary,
	index: int,
	_seen_file_path: String,
	seen_ids: Dictionary,
	errors: Array[String],
	warnings: Array[String]
) -> void:
	var id: String = ModelUtils.as_string(record.get("id"))
	if id.is_empty():
		errors.append("Record %d is missing 'id'" % index)
	else:
		if seen_ids.has(id):
			errors.append("Duplicate museum record id '%s' at index %d" % [id, index])
		seen_ids[id] = true

	var record_type: String = ModelUtils.as_string(record.get("record_type"))
	if record_type.is_empty():
		errors.append("Record '%s' is missing 'record_type'" % id)
	elif not RECORD_TYPES.has(record_type):
		errors.append("Record '%s' has unknown record_type '%s'" % [id, record_type])

	if not record.has("source_ref") or ModelUtils.as_string(record.get("source_ref")).is_empty():
		errors.append("Record '%s' is missing 'source_ref'" % id)

	var status: String = ModelUtils.as_string(record.get("verification_status"))
	if status.is_empty():
		errors.append("Record '%s' is missing 'verification_status'" % id)
	elif not VALID_STATUSES.has(status):
		errors.append("Record '%s' has unknown verification_status '%s'" % [id, status])

	if not record.has("fact_card") or ModelUtils.as_string(record.get("fact_card")).is_empty():
		errors.append("Record '%s' is missing 'fact_card'" % id)
	else:
		var fact: String = ModelUtils.as_string(record.get("fact_card"))
		if status == "verified" and fact.contains("PENDING"):
			(
				errors
				. append(
					(
						"Record '%s' is marked verified but its fact_card still contains a pending placeholder"
						% id
					)
				)
			)

	if status == "verified":
		var source_ref: String = ModelUtils.as_string(record.get("source_ref"))
		var source_path := "res://docs/sources/%s.md" % source_ref
		if not FileAccess.file_exists(source_path):
			errors.append(
				(
					"Record '%s' is verified but source_ref '%s' does not resolve to %s"
					% [id, source_ref, source_path]
				)
			)
	else:
		warnings.append("Record '%s' is not yet verified (%s)" % [id, status])
