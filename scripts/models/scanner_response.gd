class_name ScannerResponse
## Typed response from the scanner backend or cache.
##
## This is the shared response model used by both the offline cache transport
## (Phase 7) and the future HTTP transport (Phase 8). It is advisory only: it
## never contains or sets an authenticity verdict.

var ok: bool = true
var request_id: String = ""
var type: String = ""
var period: String = ""
var materials: Array[String] = []
var markings: Array[String] = []
var condition_note: String = ""
var cultural_relevance: String = ""
var price_range_min: int = 0
var price_range_max: int = 0
var modification_signs: Array[String] = []
var confidence: String = ""  ## high, medium, low, uncertain.
var uncertainty_notes: String = ""
var source_references: Array[Dictionary] = []
var fallback: bool = false
var transport_error: String = ""
var validation_errors: Array[String] = []


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScannerResponse:
	var r := ScannerResponse.new()
	r.ok = ModelUtils.as_bool(data.get("ok"), true)
	r.request_id = ModelUtils.as_string(data.get("request_id"))
	r.type = ModelUtils.as_string(data.get("type"))
	r.period = ModelUtils.as_string(data.get("period"))
	r.materials = ModelUtils.as_string_array(data.get("materials"))
	r.markings = ModelUtils.as_string_array(data.get("markings"))
	r.condition_note = ModelUtils.as_string(data.get("condition_note"))
	r.cultural_relevance = ModelUtils.as_string(data.get("cultural_relevance"))
	var price_range = data.get("price_range", [0, 0])
	if price_range is Array and price_range.size() >= 2:
		r.price_range_min = ModelUtils.as_int(price_range[0])
		r.price_range_max = ModelUtils.as_int(price_range[1])
	r.modification_signs = ModelUtils.as_string_array(data.get("modification_signs"))
	r.confidence = ModelUtils.as_string(data.get("confidence"))
	r.uncertainty_notes = ModelUtils.as_string(data.get("uncertainty_notes"))

	var refs: Array[Dictionary] = []
	var raw_refs = data.get("source_references", [])
	if raw_refs is Array:
		for item in raw_refs:
			if item is Dictionary:
				refs.append(item.duplicate())
	r.source_references = refs

	r.fallback = ModelUtils.as_bool(data.get("fallback"))
	r.transport_error = ModelUtils.as_string(data.get("transport_error"))
	r.validation_errors = ModelUtils.as_string_array(data.get("validation_errors"))
	return r


func to_dictionary() -> Dictionary:
	var refs: Array = []
	for ref in source_references:
		refs.append(ref.duplicate())
	return {
		"ok": ok,
		"request_id": request_id,
		"type": type,
		"period": period,
		"materials": materials.duplicate(),
		"markings": markings.duplicate(),
		"condition_note": condition_note,
		"cultural_relevance": cultural_relevance,
		"price_range": [price_range_min, price_range_max],
		"modification_signs": modification_signs.duplicate(),
		"confidence": confidence,
		"uncertainty_notes": uncertainty_notes,
		"source_references": refs,
		"fallback": fallback,
		"transport_error": transport_error,
		"validation_errors": validation_errors.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if not ok:
		# Error responses are valid by shape; the error text carries the detail.
		return result
	if request_id.is_empty():
		result.add_field_error(file_path, request_id, "request_id", "request_id is required")
	if type.is_empty():
		result.add_field_error(file_path, request_id, "type", "type is required")
	if period.is_empty():
		result.add_field_error(file_path, request_id, "period", "period is required")
	if materials.is_empty():
		result.add_field_error(file_path, request_id, "materials", "materials are required")
	if condition_note.is_empty():
		result.add_field_error(
			file_path, request_id, "condition_note", "condition_note is required"
		)
	if price_range_min < 0 or price_range_max < price_range_min:
		result.add_field_error(
			file_path, request_id, "price_range", "invalid price range (min >= 0, max >= min)"
		)
	for ref in source_references:
		if ref.is_empty():
			continue
		if ref.has("verified") and ref.get("verified") is bool:
			continue
		# A source reference must either be marked verified or explicitly unverified.
		if not ref.has("status"):
			result.add_field_error(
				file_path,
				request_id,
				"source_references",
				"source reference missing status/verified flag"
			)
	return result


func is_success() -> bool:
	return ok and validation_errors.is_empty() and transport_error.is_empty()
