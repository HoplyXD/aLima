class_name ContentManifestValidator
## Validates the full-game ContentManifest (P12.3, PRD CONTENT-R2).
##
## One-pass error accumulation in the existing DataRepository style: every
## violation is appended to a shared ValidationResult and the validator never
## fails fast. Enforces structural shape, the §4-M count floor (with an in-logic
## tamper guard), the PRD §23 decision gates, the artifact-lock packet gate, and
## reference integrity against DataRepository collections and the provenance /
## source / review record trees.

const SCHEMA_VERSION: int = 1

## Statuses that count as an unresolved (blocking) team decision.
const PENDING_PREFIX: String = "PENDING"

## The CLAUDE.md §4-M / README content floor. Re-asserted against the manifest's
## declared minimums so a manifest cannot quietly lower a requirement below the
## promised GDD parity. Precedent: DataRepository.REQUIRED_EVENT_IDS.
const GDD_FLOOR: Dictionary = {
	"object_templates": 30,
	"restoration_interactions": 9,
	"carrier_candidates": 15,
	"compatible_candidates_per_fragment": 3,
	"counterfeits": 6,
	"temporal_echoes": 15,
	"mystery_pages": 10,
	"route_beats_per_route": 3,
	"buyer_personas": 6,
	"named_events": 8,
	"fragment_fact_cards": 5,
	"assembled_records": 1,
	"gold_discoveries": 5,
}

## Manifest content categories whose IDs must resolve to a loaded DataRepository
## collection. Categories authored in later phases (echoes, counterfeits, ...)
## have no collection yet and are gated only by counts + the deferred flag.
const REPO_COLLECTIONS: Dictionary = {
	"object_templates": "scrap_object_templates",
	"buyer_personas": "buyer_personas",
	"named_events": "event_definitions",
}

var manifest_path: String = "res://data/content-manifest.json"
var decisions_path: String = "res://data/design/decisions.json"
var artifact_packet_dir: String = "res://data/artifacts/packets"
var provenance_dir: String = "res://docs/provenance"
var source_dir: String = "res://docs/sources"
var review_dir: String = "res://docs/reviews"

## Optional loaded repository for cross-reference integrity. When null, repo
## reference checks are skipped (counts and gates still run).
var repo: DataRepository = null


func _init() -> void:
	pass


## Loads and validates the manifest, accumulating every error into result.
func validate(result: ValidationResult = ValidationResult.new()) -> ValidationResult:
	var doc: Variant = _read_json(manifest_path, result)
	if doc == null:
		return result
	var manifest := ContentManifest.from_dictionary(doc)
	manifest.validate(result, manifest_path)

	_validate_counts(manifest, result)
	_validate_decisions(manifest, result)
	_validate_artifact_packet(manifest, result)
	_validate_repo_references(manifest, result)
	_validate_record_references(manifest, result)
	return result


## actual >= declared.min (unless deferred), and declared.min >= GDD floor.
func _validate_counts(manifest: ContentManifest, result: ValidationResult) -> void:
	for category in GDD_FLOOR.keys():
		if not manifest.requirements.has(category):
			result.add_field_error(
				manifest_path,
				manifest.id,
				"requirements",
				"manifest omits required category '%s'" % category
			)
			continue
		var declared_min := manifest.required_min(category)
		var floor_value: int = GDD_FLOOR[category]
		if declared_min < floor_value:
			result.add_field_error(
				manifest_path,
				manifest.id,
				"requirements.%s.min" % category,
				(
					"declared min %d is below the GDD floor %d"
					% [declared_min, floor_value]
				)
			)
		var deferred := manifest.deferred_to_phase(category)
		if deferred.is_empty():
			var actual := manifest.content_ids(category).size()
			if actual < declared_min:
				result.add_field_error(
					manifest_path,
					manifest.id,
					"content.%s" % category,
					"insufficient count: %d authored, %d required" % [actual, declared_min]
				)


## Every referenced decision must exist and be RESOLVED. A PENDING decision keeps
## the manifest failing so the blocker is loud (CLAUDE.md §4-M, PRD §23).
func _validate_decisions(manifest: ContentManifest, result: ValidationResult) -> void:
	var statuses := _load_decision_statuses(result)
	for decision_id in manifest.decision_refs:
		if not statuses.has(decision_id):
			result.add_field_error(
				manifest_path,
				manifest.id,
				"decision_refs",
				"unknown design decision '%s'" % decision_id
			)
			continue
		var status: String = statuses[decision_id]
		if status.begins_with(PENDING_PREFIX):
			result.add_field_error(
				decisions_path,
				decision_id,
				"status",
				"design decision '%s' is unresolved (%s)" % [decision_id, status]
			)


## The artifact-lock packet must exist and be RESOLVED with a full five-component
## packet, sources, reviewers, and an approval date (P12.1, ASSET-R5/R7).
func _validate_artifact_packet(manifest: ContentManifest, result: ValidationResult) -> void:
	if manifest.artifact_packet_ref.is_empty():
		return
	var packet_path := artifact_packet_dir.path_join("%s.json" % manifest.artifact_packet_ref)
	var packet: Variant = _read_json(packet_path, result)
	if packet == null:
		return
	var status := ModelUtils.as_string(packet.get("status"))
	if status.begins_with(PENDING_PREFIX):
		result.add_field_error(
			packet_path,
			manifest.artifact_packet_ref,
			"status",
			"artifact lock is unresolved (%s)" % status
		)
		return
	var artifact := ModelUtils.as_dictionary(packet.get("artifact"))
	if ModelUtils.as_string(artifact.get("id")).is_empty():
		result.add_field_error(
			packet_path, manifest.artifact_packet_ref, "artifact.id", "locked artifact has no id"
		)
	var components := packet.get("natural_components", [])
	if not components is Array or components.size() != 5:
		result.add_field_error(
			packet_path,
			manifest.artifact_packet_ref,
			"natural_components",
			"expected exactly 5 natural components"
		)
	else:
		for component in components:
			var comp := ModelUtils.as_dictionary(component)
			if ModelUtils.as_string(comp.get("id")).is_empty():
				result.add_field_error(
					packet_path,
					manifest.artifact_packet_ref,
					"natural_components",
					"a natural component has no id"
				)
	if ModelUtils.as_string_array(packet.get("source_refs")).is_empty():
		result.add_field_error(
			packet_path,
			manifest.artifact_packet_ref,
			"source_refs",
			"a locked artifact must cite at least one verified source"
		)
	if ModelUtils.as_string_array(packet.get("reviewer_refs")).is_empty():
		result.add_field_error(
			packet_path,
			manifest.artifact_packet_ref,
			"reviewer_refs",
			"a locked artifact must name at least one cultural reviewer"
		)
	if ModelUtils.as_string(packet.get("approval_date")).is_empty():
		result.add_field_error(
			packet_path, manifest.artifact_packet_ref, "approval_date", "approval_date is missing"
		)


## Content IDs for categories with a loaded collection must resolve to a record.
func _validate_repo_references(manifest: ContentManifest, result: ValidationResult) -> void:
	if repo == null:
		return
	for category in REPO_COLLECTIONS.keys():
		var collection: Dictionary = repo.get(REPO_COLLECTIONS[category])
		for entry_id in manifest.content_ids(category):
			if not collection.has(entry_id):
				result.add_field_error(
					manifest_path,
					manifest.id,
					"content.%s" % category,
					"unknown %s reference '%s'" % [category, entry_id]
				)


## Provenance / source / review references must resolve to a committed record
## file. Empty ref lists are allowed only while the artifact lock is PENDING.
func _validate_record_references(manifest: ContentManifest, result: ValidationResult) -> void:
	_require_records(manifest, manifest.provenance_refs, provenance_dir, "provenance_refs", result)
	_require_records(manifest, manifest.source_refs, source_dir, "source_refs", result)
	_require_records(manifest, manifest.review_refs, review_dir, "review_refs", result)


func _require_records(
	manifest: ContentManifest,
	refs: Array[String],
	dir_path: String,
	field: String,
	result: ValidationResult
) -> void:
	if refs.is_empty():
		result.add_field_error(
			manifest_path, manifest.id, field, "no %s records declared" % field
		)
		return
	for ref in refs:
		var record_path := dir_path.path_join("%s.md" % ref)
		if not FileAccess.file_exists(record_path):
			result.add_field_error(
				manifest_path,
				manifest.id,
				field,
				"missing record file for '%s' (expected %s)" % [ref, record_path]
			)


func _load_decision_statuses(result: ValidationResult) -> Dictionary:
	var statuses: Dictionary = {}
	var doc: Variant = _read_json(decisions_path, result)
	if doc == null:
		return statuses
	var items := doc.get("items", [])
	if not items is Array:
		result.add_field_error(decisions_path, "", "items", "expected an array")
		return statuses
	for item in items:
		if not item is Dictionary:
			continue
		var decision_id := ModelUtils.as_string(item.get("id"))
		if decision_id.is_empty():
			continue
		statuses[decision_id] = ModelUtils.as_string(item.get("status"))
	return statuses


## Reads a JSON object with a schema_version gate, mirroring DataRepository.
func _read_json(file_path: String, result: ValidationResult) -> Variant:
	if not FileAccess.file_exists(file_path):
		result.add_error("Could not read file: %s" % file_path)
		return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		result.add_error(
			"Could not read file: %s (error %d)" % [file_path, FileAccess.get_open_error()]
		)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		result.add_error("JSON root must be an object with schema_version: %s" % file_path)
		return null
	var doc: Dictionary = parsed
	if not doc.has("schema_version"):
		result.add_error("Missing schema_version in %s" % file_path)
		return null
	var version := ModelUtils.as_int(doc["schema_version"])
	if version != SCHEMA_VERSION:
		result.add_error(
			(
				"Unsupported schema version %d in %s (expected %d)"
				% [version, file_path, SCHEMA_VERSION]
			)
		)
		return null
	return doc
