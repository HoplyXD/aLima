class_name ScannerCacheEntry
## Cached scanner response fixture for one object template.
##
## The response shape mirrors PRD §20 and is advisory only: it never contains
## or sets a final authenticity verdict. The cached response serializes as a
## Dictionary that parses into a ScannerResponse.

var id: String = ""  ## Matches ScrapObjectTemplate.id.
var template_id: String = ""  ## Redundant with id; kept for clarity.
var response: Dictionary = {}
var fallback: bool = false  ## True if this is a fallback/canned response.
var schema_version: int = 1


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScannerCacheEntry:
	var s := ScannerCacheEntry.new()
	s.id = ModelUtils.as_string(data.get("id"))
	s.template_id = ModelUtils.as_string(data.get("template_id"))
	s.response = data.get("response", {}) as Dictionary
	s.fallback = ModelUtils.as_bool(data.get("fallback"))
	s.schema_version = ModelUtils.as_int(data.get("schema_version"), 1)
	return s


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"template_id": template_id,
		"response": response.duplicate(),
		"fallback": fallback,
		"schema_version": schema_version,
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
		return result

	# Validate the response through the shared ScannerResponse model.
	# The request_id is injected at scan time, so use a placeholder here.
	var response_for_validation := response.duplicate()
	if not response_for_validation.has("request_id"):
		response_for_validation["request_id"] = "cache_placeholder"
	var parsed := ScannerResponse.from_dictionary(response_for_validation)
	parsed.validate(result, file_path)

	# Cache-specific structural checks.
	if response.has("price_range"):
		var pr = response["price_range"]
		if not pr is Array or pr.size() < 2:
			result.add_field_error(
				file_path,
				effective_id,
				"response.price_range",
				"price_range must be a two-element array"
			)
		else:
			var min_price := ModelUtils.as_int(pr[0])
			var max_price := ModelUtils.as_int(pr[1])
			if min_price < 0 or max_price < min_price:
				result.add_field_error(
					file_path,
					effective_id,
					"response.price_range",
					"price range min must be >= 0 and max >= min"
				)

	# Source references must either be verified or explicitly marked unverified.
	var refs: Array = response.get("source_references", [])
	if refs is Array:
		for i in range(refs.size()):
			var ref = refs[i]
			if not ref is Dictionary:
				result.add_field_error(
					file_path,
					effective_id,
					"response.source_references[%d]" % i,
					"source reference must be an object"
				)
				continue
			var status: String = ModelUtils.as_string(ref.get("status"))
			var verified: bool = ModelUtils.as_bool(ref.get("verified"))
			if status != "verified" and status != "unverified" and not verified:
				result.add_field_error(
					file_path,
					effective_id,
					"response.source_references[%d]" % i,
					"source reference must be marked verified or unverified/development-only"
				)
			if status == "verified":
				var title: String = ModelUtils.as_string(ref.get("title"))
				var url: String = ModelUtils.as_string(ref.get("url"))
				if title.is_empty() and url.is_empty():
					result.add_field_error(
						file_path,
						effective_id,
						"response.source_references[%d]" % i,
						"verified source reference requires a title or URL"
					)

	return result
