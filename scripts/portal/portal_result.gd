class_name PortalResult
## Result wrapper for a Portal discovery attempt.

enum Status {
	SUCCESS = 0,
	FALLBACK = 1,
	VALIDATION_ERROR = 2,
	TIMEOUT_ERROR = 3,
	NETWORK_ERROR = 4,
}

var status: int = Status.SUCCESS
var response: PortalDiscoveryResponse = null
var error: String = ""


func _init(
	p_status: int = Status.SUCCESS, p_response: PortalDiscoveryResponse = null, p_error: String = ""
) -> void:
	status = p_status
	response = p_response
	error = p_error


func is_ok() -> bool:
	return status == Status.SUCCESS or status == Status.FALLBACK


static func status_name(status_code: int) -> String:
	match status_code:
		Status.SUCCESS:
			return "SUCCESS"
		Status.FALLBACK:
			return "FALLBACK"
		Status.VALIDATION_ERROR:
			return "VALIDATION_ERROR"
		Status.TIMEOUT_ERROR:
			return "TIMEOUT_ERROR"
		Status.NETWORK_ERROR:
			return "NETWORK_ERROR"
		_:
			return "UNKNOWN"
