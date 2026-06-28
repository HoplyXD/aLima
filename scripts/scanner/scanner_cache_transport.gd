class_name ScannerCacheTransport
extends ScannerTransport
## Offline fixture transport: looks up the template ID in DataRepository.
##
## Returns the authored ScannerResponse from a folder artifact's own ArtifactScannerData node (so new
## artifacts are scannable with no JSON edit), else from `data/scanner-cache/`, else a controlled
## missing-cache error. Never invents content.

## Folder artifacts can ship their own scanner data on the scene (ArtifactScannerData).
const _ArtifactCatalog := preload("res://scripts/restoration/artifact_catalog.gd")

var _repo: DataRepository


func _init(repo: DataRepository = DataRepository.singleton()) -> void:
	_repo = repo


func submit(request: ScannerRequest) -> Dictionary:
	if request.template_id.is_empty():
		return {"ok": false, "error": "request has no template_id"}

	# Scene-authored scanner data wins, so any folder artifact with an ArtifactScannerData node is
	# scannable (and therefore sellable) with no JSON edit. Falls through to the cache otherwise.
	var scene_response := _ArtifactCatalog.scanner_response_for(request.template_id)
	if not scene_response.is_empty():
		return _result_from_response_data(scene_response, request, true)

	var entry: ScannerCacheEntry = _repo.get_scanner_cache(request.template_id)
	if entry == null:
		return {
			"ok": false,
			"error": "no cached response for template '%s'" % request.template_id,
			"status": ScannerResult.Status.MISSING_CACHE,
		}
	return _result_from_response_data(entry.response, request, entry.fallback)


## Validates a response payload and packages it as a transport result.
func _result_from_response_data(
	response_data: Dictionary, request: ScannerRequest, fallback: bool
) -> Dictionary:
	var data := response_data.duplicate(true)
	data["request_id"] = request.request_id
	data["fallback"] = fallback

	var response := ScannerResponse.from_dictionary(data)
	var validation := response.validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error": "malformed cached response: %s" % ", ".join(validation.errors()),
			"status": ScannerResult.Status.MALFORMED_RESPONSE,
			"response": response,
		}

	return {"ok": true, "response": response, "status": ScannerResult.Status.SUCCESS}
