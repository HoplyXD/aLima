class_name ContentManifest
## Typed full-game content manifest (CLAUDE.md §4-M, PRD CONTENT-R1/R2).
##
## Declares the required minimum count for every content category and the named
## IDs authored so far, plus references to the artifact-lock packet, the §23
## design decisions, and the provenance / source / review records. Structural
## validation only lives here (well-formed, unique non-placeholder IDs); count
## gates, decision gates, and cross-references live in ContentManifestValidator.

## Tokens that flag an unfilled production ID. A content ID containing any of
## these (or an empty ID) fails structural validation.
const PLACEHOLDER_TOKENS: Array[String] = ["TODO", "PLACEHOLDER", "PENDING", "FIXME", "TBD"]

var schema_version: int = 0
var id: String = ""
var requirements: Dictionary = {}  ## category -> {min:int, deferred_to_phase:String}
var content: Dictionary = {}  ## category -> Array[String] of authored IDs
var artifact_packet_ref: String = ""
var decision_refs: Array[String] = []
var provenance_refs: Array[String] = []
var source_refs: Array[String] = []
var review_refs: Array[String] = []


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ContentManifest:
	var m := ContentManifest.new()
	m.schema_version = ModelUtils.as_int(data.get("schema_version"))
	m.id = ModelUtils.as_string(data.get("id"))
	m.requirements = ModelUtils.as_dictionary(data.get("requirements"))
	m.content = ModelUtils.as_dictionary(data.get("content"))
	m.artifact_packet_ref = ModelUtils.as_string(data.get("artifact_packet_ref"))
	m.decision_refs = ModelUtils.as_string_array(data.get("decision_refs"))
	m.provenance_refs = ModelUtils.as_string_array(data.get("provenance_refs"))
	m.source_refs = ModelUtils.as_string_array(data.get("source_refs"))
	m.review_refs = ModelUtils.as_string_array(data.get("review_refs"))
	return m


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"id": id,
		"requirements": requirements.duplicate(true),
		"content": content.duplicate(true),
		"artifact_packet_ref": artifact_packet_ref,
		"decision_refs": decision_refs.duplicate(),
		"provenance_refs": provenance_refs.duplicate(),
		"source_refs": source_refs.duplicate(),
		"review_refs": review_refs.duplicate(),
	}


## Returns the authored IDs for a category as a typed array (empty if absent).
func content_ids(category: String) -> Array[String]:
	return ModelUtils.as_string_array(content.get(category))


## Returns the declared minimum for a category, or -1 if no requirement exists.
func required_min(category: String) -> int:
	if not requirements.has(category):
		return -1
	return ModelUtils.as_int(ModelUtils.as_dictionary(requirements[category]).get("min"))


## Returns the phase a category is deferred to ("" when it must be met now).
func deferred_to_phase(category: String) -> String:
	if not requirements.has(category):
		return ""
	return ModelUtils.as_string(
		ModelUtils.as_dictionary(requirements[category]).get("deferred_to_phase")
	)


## Structural validation only: well-formed shape, unique non-placeholder content
## IDs, present required references. Count/decision/reference gates are enforced
## by ContentManifestValidator.
func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if requirements.is_empty():
		result.add_field_error(file_path, id, "requirements", "requirements map is empty")
	if artifact_packet_ref.is_empty():
		result.add_field_error(
			file_path, id, "artifact_packet_ref", "required artifact_packet_ref is missing"
		)
	if decision_refs.is_empty():
		result.add_field_error(file_path, id, "decision_refs", "required decision_refs are missing")

	for category in requirements.keys():
		var spec := ModelUtils.as_dictionary(requirements[category])
		if not spec.has("min"):
			result.add_field_error(
				file_path, id, "requirements", "category '%s' has no min" % category
			)
		elif ModelUtils.as_int(spec.get("min")) < 0:
			result.add_field_error(
				file_path, id, "requirements", "category '%s' min must be >= 0" % category
			)

	for category in content.keys():
		if not content[category] is Array:
			result.add_field_error(
				file_path, id, "content", "category '%s' content must be an array" % category
			)
			continue
		var seen: Dictionary = {}
		for entry_id in content_ids(category):
			if entry_id.is_empty():
				result.add_field_error(
					file_path, id, "content", "category '%s' has an empty content id" % category
				)
				continue
			if _is_placeholder(entry_id):
				result.add_field_error(
					file_path,
					id,
					"content",
					"category '%s' uses placeholder production id '%s'" % [category, entry_id]
				)
			if seen.has(entry_id):
				result.add_field_error(
					file_path,
					id,
					"content",
					"category '%s' has duplicate id '%s'" % [category, entry_id]
				)
			seen[entry_id] = true
	return result


func _is_placeholder(value: String) -> bool:
	var upper := value.to_upper()
	for token in PLACEHOLDER_TOKENS:
		if upper.find(token) >= 0:
			return true
	return false
