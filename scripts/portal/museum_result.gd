class_name MuseumResult
## Result wrapper for a museum record post or retrieval attempt.

enum Status {
	SUCCESS = 0,
	FALLBACK = 1,
	VALIDATION_ERROR = 2,
	TIMEOUT_ERROR = 3,
	NETWORK_ERROR = 4,
}

var status: int = Status.SUCCESS
var record: MuseumRecordResponse = null
var entries: Array[MuseumRecordResponse] = []
var used_fallback: bool = false
var error: String = ""


func _init(
	p_status: int = Status.SUCCESS,
	p_record: MuseumRecordResponse = null,
	p_entries: Array[MuseumRecordResponse] = [],
	p_error: String = ""
) -> void:
	status = p_status
	record = p_record
	entries = p_entries
	error = p_error
	used_fallback = _compute_used_fallback()


func is_ok() -> bool:
	return status == Status.SUCCESS or status == Status.FALLBACK


func _compute_used_fallback() -> bool:
	if record != null:
		return record.used_fallback
	return false


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
