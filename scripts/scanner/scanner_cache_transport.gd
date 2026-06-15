class_name ScannerCacheTransport
extends ScannerTransport
## Offline fixture transport: looks up the template ID in DataRepository.
##
## Returns the authored ScannerResponse from `data/scanner-cache/` or a controlled
## missing-cache error. Never invents content.

var _repo: DataRepository


func _init(repo: DataRepository = DataRepository.singleton()) -> void:
	_repo = repo


func submit(request: ScannerRequest) -> Dictionary:
	if request.template_id.is_empty():
		return {"ok": false, "error": "request has no template_id"}

	var entry: ScannerCacheEntry = _repo.get_scanner_cache(request.template_id)
	if entry == null:
		return {
			"ok": false,
			"error": "no cached response for template '%s'" % request.template_id,
			"status": ScannerResult.Status.MISSING_CACHE,
		}

	var response_data := entry.response.duplicate()
	response_data["request_id"] = request.request_id
	response_data["fallback"] = entry.fallback

	var response := ScannerResponse.from_dictionary(response_data)
	var validation := response.validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error": "malformed cached response: %s" % ", ".join(validation.errors()),
			"status": ScannerResult.Status.MALFORMED_RESPONSE,
			"response": response,
		}

	return {"ok": true, "response": response, "status": ScannerResult.Status.SUCCESS}
