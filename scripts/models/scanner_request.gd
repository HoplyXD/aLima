class_name ScannerRequest
## Typed request for the backend POST /api/scan contract (PRD §20).
##
## Built from an ObjectInstance and its template. The request deliberately excludes
## hidden truth fields (carrier, fragment, counterfeit truth, injected content) so
## the scanner cannot leak or infer authenticity.

var request_id: String = ""
var instance_id: String = ""
var template_id: String = ""
var condition: float = 0.0
var materials: Array[String] = []
var markings: Array[String] = []
var weight: float = 0.0
var dimensions: Dictionary = {}
var player_notes: String = ""
var language: String = "en"
var schema_version: int = 1


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScannerRequest:
	var r := ScannerRequest.new()
	r.request_id = ModelUtils.as_string(data.get("request_id"))
	r.instance_id = ModelUtils.as_string(data.get("instance_id"))
	r.template_id = ModelUtils.as_string(data.get("template_id"))
	r.condition = ModelUtils.as_float(data.get("condition"))
	r.materials = ModelUtils.as_string_array(data.get("materials"))
	r.markings = ModelUtils.as_string_array(data.get("markings"))
	r.weight = ModelUtils.as_float(data.get("weight"))
	if data.get("dimensions") is Dictionary:
		r.dimensions = data["dimensions"].duplicate()
	r.player_notes = ModelUtils.as_string(data.get("player_notes"))
	r.language = ModelUtils.as_string(data.get("language"), "en")
	r.schema_version = ModelUtils.as_int(data.get("schema_version"), 1)
	return r


func to_dictionary() -> Dictionary:
	return {
		"request_id": request_id,
		"instance_id": instance_id,
		"template_id": template_id,
		"condition": condition,
		"materials": materials.duplicate(),
		"markings": markings.duplicate(),
		"weight": weight,
		"dimensions": dimensions.duplicate(),
		"player_notes": player_notes,
		"language": language,
		"schema_version": schema_version,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if request_id.is_empty():
		result.add_field_error(file_path, instance_id, "request_id", "request_id is required")
	if instance_id.is_empty():
		result.add_field_error(file_path, request_id, "instance_id", "instance_id is required")
	if template_id.is_empty():
		result.add_field_error(file_path, request_id, "template_id", "template_id is required")
	if condition < 0.0 or condition > 100.0:
		result.add_field_error(
			file_path, request_id, "condition", "condition must be between 0 and 100"
		)
	if weight < 0.0:
		result.add_field_error(file_path, request_id, "weight", "weight must be non-negative")
	if schema_version < 1:
		result.add_field_error(
			file_path, request_id, "schema_version", "schema_version must be >= 1"
		)
	return result
