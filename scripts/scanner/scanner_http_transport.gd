class_name ScannerHttpTransport
extends ScannerTransport
## Future HTTP transport for Phase 8.
##
## This is a typed stub that preserves the transport boundary. It does not
## perform actual HTTP calls in Phase 7; Phase 8 will implement the backend
## `POST /api/scan` call with timeout, retry, and fallback logic.

var _base_url: String = ""
var _endpoint: String = "/api/scan"


func _init(base_url: String) -> void:
	_base_url = base_url


func submit(request: ScannerRequest) -> Dictionary:
	# Phase 8 implementation. Returning a transport error keeps Phase 7 offline-only.
	var response := ScannerResponse.new()
	response.ok = false
	response.request_id = request.request_id
	response.transport_error = "HTTP transport is not implemented in Phase 7"
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
