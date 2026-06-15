class_name ScannerCacheEntry
## Cached scanner response fixture for one object template.
##
## The response shape mirrors PRD §20 and is advisory only: it never contains
## or sets a final authenticity verdict.

var id: String = ""  ## Matches ScrapObjectTemplate.id.
var template_id: String = ""  ## Redundant with id; kept for clarity.
var response: Dictionary = {}
var fallback: bool = false  ## True if this is a fallback/canned response.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScannerCacheEntry:
	var s := ScannerCacheEntry.new()
	s.id = ModelUtils.as_string(data.get("id"))
	s.template_id = ModelUtils.as_string(data.get("template_id"))
	s.response = data.get("response", {}) as Dictionary
	s.fallback = ModelUtils.as_bool(data.get("fallback"))
	return s


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"template_id": template_id,
		"response": response.duplicate(),
		"fallback": fallback,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	var effective_id := id if not id.is_empty() else template_id
	if effective_id.is_empty():
		result.add_field_error(
			file_path,
			effective_id,
			"id/template_id",
			"scanner cache entry must reference a template id"
		)
	if response.is_empty():
		result.add_field_error(
			file_path, effective_id, "response", "cached response body is required"
		)
	else:
		for key in ["type", "period", "materials", "price_range"]:
			if not response.has(key):
				result.add_field_error(
					file_path,
					effective_id,
					"response.%s" % key,
					"missing expected scanner response field"
				)
		if response.has("price_range"):
			var pr = response["price_range"]
			if not pr is Array or pr.size() < 2:
				result.add_field_error(
					file_path,
					effective_id,
					"response.price_range",
					"price_range must be a two-element array"
				)
	return result
