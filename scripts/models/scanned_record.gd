class_name ScannedRecord
## Persistent record of a player scan and verdict.
##
## Lives in PersistentState.scanned_records (template_id -> ScannedRecord). It
## preserves the scanner response snapshot and the player's final verdict, but
## never exposes hidden carrier/counterfeit truth.

var template_id: String = ""
var instance_id: String = ""
var verdict: int = ModelEnums.Verdict.UNKNOWN
var response_snapshot: Dictionary = {}
var scanned_at_loop: int = 0
var fallback: bool = false


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScannedRecord:
	var r := ScannedRecord.new()
	r.template_id = ModelUtils.as_string(data.get("template_id"))
	r.instance_id = ModelUtils.as_string(data.get("instance_id"))
	r.verdict = ModelEnums.verdict_from_name(ModelUtils.as_string(data.get("verdict")))
	if data.get("response_snapshot") is Dictionary:
		r.response_snapshot = data["response_snapshot"].duplicate()
	r.scanned_at_loop = ModelUtils.as_int(data.get("scanned_at_loop"))
	r.fallback = ModelUtils.as_bool(data.get("fallback"))
	return r


func to_dictionary() -> Dictionary:
	return {
		"template_id": template_id,
		"instance_id": instance_id,
		"verdict": ModelEnums.verdict_name(verdict),
		"response_snapshot": response_snapshot.duplicate(),
		"scanned_at_loop": scanned_at_loop,
		"fallback": fallback,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if template_id.is_empty():
		result.add_field_error(file_path, template_id, "template_id", "template_id is required")
	if instance_id.is_empty():
		result.add_field_error(file_path, template_id, "instance_id", "instance_id is required")
	if ModelEnums.VERDICT_NAMES.find(ModelEnums.verdict_name(verdict)) < 0:
		result.add_field_error(file_path, template_id, "verdict", "unknown verdict")
	if response_snapshot.is_empty():
		result.add_field_error(
			file_path, template_id, "response_snapshot", "response snapshot is required"
		)
	# The snapshot must be a scanner response, not hidden truth metadata.
	for forbidden in ["is_carrier", "fragment_id", "is_counterfeit_truth", "contents"]:
		if response_snapshot.has(forbidden):
			result.add_field_error(
				file_path,
				template_id,
				"response_snapshot",
				"snapshot must not contain hidden truth field '%s'" % forbidden
			)
	return result
