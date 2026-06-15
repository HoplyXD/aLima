class_name ScannerResult
## Result wrapper returned by ScannerService.scan().
##
## Carries an explicit status so callers can render loading, success, fallback,
## missing-cache, and malformed-response states without branching on raw strings.

enum Status {
	SUCCESS = 0,  ## A valid advisory response was returned.
	FALLBACK = 1,  ## A controlled fallback response was returned.
	NOT_CLEAN = 2,  ## The instance is not eligible for scanning.
	MISSING_CACHE = 3,  ## No cached response exists for the template.
	MALFORMED_RESPONSE = 4,  ## Cache/transport returned an invalid response shape.
	TRANSPORT_ERROR = 5,  ## Underlying transport failed (HTTP timeout, etc.).
}

const STATUS_NAMES: Array[String] = [
	"success",
	"fallback",
	"not_clean",
	"missing_cache",
	"malformed_response",
	"transport_error",
]

var status: int = Status.SUCCESS
var response: ScannerResponse = ScannerResponse.new()


func _init(
	p_status: int = Status.SUCCESS, p_response: ScannerResponse = ScannerResponse.new()
) -> void:
	status = p_status
	response = p_response


static func status_name(value: int) -> String:
	if value < 0 or value >= STATUS_NAMES.size():
		return STATUS_NAMES[Status.TRANSPORT_ERROR]
	return STATUS_NAMES[value]


func is_ok() -> bool:
	return status == Status.SUCCESS or status == Status.FALLBACK
