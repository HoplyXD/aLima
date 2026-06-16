class_name ScannerHttpTransport
extends ScannerTransport
## Future HTTP transport for the backend scanner endpoint (POST /api/scan).
##
## This is a typed stub that preserves the transport boundary. The backend
## endpoint exists in Phase 8 (server/src/routes/scan.js) and is tested
## independently; wiring the Godot scanner UI to use this transport instead of
## the cached fixture transport is deferred to Phase 9/21 so the synchronous
## ScannerService.scan() contract does not need to change for Phase 8.

var _base_url: String = ""
var _endpoint: String = "/api/scan"


func _init(base_url: String = "") -> void:
	if base_url.is_empty():
		if ProjectSettings.has_setting("network/portal/backend_url"):
			_base_url = ProjectSettings.get_setting("network/portal/backend_url")
		else:
			_base_url = "http://localhost:3000"
	else:
		_base_url = base_url


func submit(_request: ScannerRequest) -> Dictionary:
	var response := ScannerResponse.new()
	response.ok = false
	response.transport_error = "HTTP scanner transport is not enabled. Use ScannerCacheTransport."
	return {
		"ok": false,
		"error": response.transport_error,
		"status": ScannerResult.Status.TRANSPORT_ERROR,
		"response": response,
	}


func get_base_url() -> String:
	return _base_url


func get_endpoint() -> String:
	return _endpoint
