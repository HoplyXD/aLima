class_name PortalClient
## Godot client for the aLima backend Portal proxy.
##
## Calls only POST /api/portal/discovery and the museum record/retrieval endpoints
## on the configured backend. Never talks directly to the mock Portal or a live
## LLM/Portal provider (Invariant §4-K).

extends RefCounted

signal discovery_completed(result: PortalResult)
signal museum_record_completed(result: MuseumResult)
signal museum_entries_completed(result: MuseumResult)

const BACKEND_URL_SETTING := "network/portal/backend_url"
const DEFAULT_BACKEND_URL := "http://localhost:3000"
const DISCOVERY_ENDPOINT := "/api/portal/discovery"
const MUSEUM_ENDPOINT := "/api/portal/museum"
const REQUEST_TIMEOUT_MS := 10000

var _backend_url: String = ""


func _init() -> void:
	_backend_url = _read_backend_url()


func set_backend_url(url: String) -> void:
	_backend_url = url


func get_backend_url() -> String:
	return _backend_url


func request_discovery(fragment_id: String, condition: int, context: String = "") -> void:
	var request := PortalDiscoveryRequest.new()
	request.artifact_id = _get_master_artifact_id()
	request.fragment_id = fragment_id
	request.player_id = GameState.player_id
	request.timestamp = Time.get_datetime_string_from_system(true)
	request.condition = clampi(condition, 0, 100)
	request.discovery_context = context

	var http := HTTPRequest.new()
	var runner := _HttpRunner.new(http)
	runner.completed.connect(_on_discovery_request_completed)
	runner.request(
		_backend_url + DISCOVERY_ENDPOINT, request.to_dictionary(), HTTPClient.METHOD_POST
	)


func request_museum_record(record_request: MuseumRecordRequest) -> void:
	var http := HTTPRequest.new()
	var runner := _HttpRunner.new(http)
	runner.completed.connect(_on_museum_record_request_completed)
	runner.request(
		_backend_url + MUSEUM_ENDPOINT, record_request.to_dictionary(), HTTPClient.METHOD_POST
	)


func request_museum_entries(player_id: String) -> void:
	var http := HTTPRequest.new()
	var runner := _HttpRunner.new(http)
	runner.completed.connect(_on_museum_entries_request_completed)
	var query := "?player_id=%s" % player_id.uri_encode()
	runner.request(_backend_url + MUSEUM_ENDPOINT + query, {}, HTTPClient.METHOD_GET)


func _read_backend_url() -> String:
	if ProjectSettings.has_setting(BACKEND_URL_SETTING):
		return ProjectSettings.get_setting(BACKEND_URL_SETTING)
	return DEFAULT_BACKEND_URL


func _get_master_artifact_id() -> String:
	var artifact: MasterArtifact = DataRepository.singleton().master_artifact
	if artifact != null:
		return artifact.id
	return ""


func _on_request_completed(result: int, response_code: int, body: PackedByteArray) -> void:
	_on_discovery_request_completed(result, response_code, body)


func _on_discovery_request_completed(
	http_result: int, response_code: int, body: PackedByteArray
) -> void:
	discovery_completed.emit(_parse_discovery_result(http_result, response_code, body))


func _on_museum_record_request_completed(
	http_result: int, response_code: int, body: PackedByteArray
) -> void:
	museum_record_completed.emit(_parse_museum_record_result(http_result, response_code, body))


func _on_museum_entries_request_completed(
	http_result: int, response_code: int, body: PackedByteArray
) -> void:
	museum_entries_completed.emit(_parse_museum_entries_result(http_result, response_code, body))


func _parse_discovery_result(
	http_result: int, response_code: int, body: PackedByteArray
) -> PortalResult:
	if http_result != HTTPRequest.RESULT_SUCCESS:
		var status := PortalResult.Status.NETWORK_ERROR
		if http_result == HTTPRequest.RESULT_TIMEOUT:
			status = PortalResult.Status.TIMEOUT_ERROR
		var err := PortalDiscoveryResponse.new()
		err.ok = false
		err.error = _http_error_message(http_result)
		return PortalResult.new(status, err, err.error)

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		var err := PortalDiscoveryResponse.new()
		err.ok = false
		err.error = "invalid JSON from backend"
		return PortalResult.new(PortalResult.Status.NETWORK_ERROR, err, err.error)

	var data: Dictionary = json.data
	var response := PortalDiscoveryResponse.from_dictionary(data)

	if response_code >= 400 or not response.ok:
		var status := PortalResult.Status.VALIDATION_ERROR
		if response_code >= 500:
			status = PortalResult.Status.NETWORK_ERROR
		return PortalResult.new(status, response, response.error)

	var status := PortalResult.Status.SUCCESS
	if response.used_fallback:
		status = PortalResult.Status.FALLBACK
	return PortalResult.new(status, response, "")


func _parse_museum_record_result(
	http_result: int, response_code: int, body: PackedByteArray
) -> MuseumResult:
	if http_result != HTTPRequest.RESULT_SUCCESS:
		var status := MuseumResult.Status.NETWORK_ERROR
		if http_result == HTTPRequest.RESULT_TIMEOUT:
			status = MuseumResult.Status.TIMEOUT_ERROR
		var err := MuseumRecordResponse.new()
		err.ok = false
		err.error = _http_error_message(http_result)
		return MuseumResult.new(status, err, [], err.error)

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		var err := MuseumRecordResponse.new()
		err.ok = false
		err.error = "invalid JSON from backend"
		return MuseumResult.new(MuseumResult.Status.NETWORK_ERROR, err, [], err.error)

	var response := MuseumRecordResponse.from_dictionary(json.data)
	if response_code >= 400 or not response.ok:
		var status := MuseumResult.Status.VALIDATION_ERROR
		if response_code >= 500:
			status = MuseumResult.Status.NETWORK_ERROR
		return MuseumResult.new(status, response, [], response.error)

	var status := MuseumResult.Status.SUCCESS
	if response.used_fallback:
		status = MuseumResult.Status.FALLBACK
	return MuseumResult.new(status, response, [], "")


func _parse_museum_entries_result(
	http_result: int, response_code: int, body: PackedByteArray
) -> MuseumResult:
	if http_result != HTTPRequest.RESULT_SUCCESS:
		var status := MuseumResult.Status.NETWORK_ERROR
		if http_result == HTTPRequest.RESULT_TIMEOUT:
			status = MuseumResult.Status.TIMEOUT_ERROR
		return MuseumResult.new(status, null, [], _http_error_message(http_result))

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK or response_code >= 400:
		return MuseumResult.new(
			MuseumResult.Status.NETWORK_ERROR, null, [], "invalid backend response"
		)

	var data: Dictionary = json.data
	var entries: Array[MuseumRecordResponse] = []
	for raw in data.get("entries", []):
		if raw is Dictionary:
			entries.append(MuseumRecordResponse.from_dictionary(raw))

	var status := MuseumResult.Status.SUCCESS
	if data.get("used_fallback", false) == true:
		status = MuseumResult.Status.FALLBACK
	return MuseumResult.new(status, null, entries, "")


func _http_error_message(http_result: int) -> String:
	match http_result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect to backend"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve backend"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TIMEOUT:
			return "backend request timed out"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve backend"
		_:
			return "HTTP request failed (%d)" % http_result


## Internal helper that owns an HTTPRequest node and bridges its signal.
class _HttpRunner:
	extends RefCounted

	signal completed(result: int, response_code: int, body: PackedByteArray)

	var _http: HTTPRequest

	func _init(http: HTTPRequest) -> void:
		_http = http
		_http.request_completed.connect(_on_completed)

	func request(url: String, body: Dictionary, method: int) -> void:
		Engine.get_main_loop().root.add_child(_http)
		var headers := PackedStringArray(["Content-Type: application/json"])
		_http.timeout = REQUEST_TIMEOUT_MS / 1000.0
		if method == HTTPClient.METHOD_GET:
			_http.request(url, headers, method)
		else:
			_http.request(url, headers, method, JSON.stringify(body))

	func _on_completed(
		result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
	) -> void:
		_http.queue_free()
		completed.emit(result, response_code, body)
