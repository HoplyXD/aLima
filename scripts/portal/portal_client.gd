class_name PortalClient
## Godot client for the aLima backend Portal proxy.
##
## Calls only POST /api/portal/discovery on the configured backend. Never talks
## directly to the mock Portal or a live LLM/Portal provider.

extends RefCounted

signal discovery_completed(result: PortalResult)

const BACKEND_URL_SETTING := "network/portal/backend_url"
const DEFAULT_BACKEND_URL := "http://localhost:3000"
const ENDPOINT := "/api/portal/discovery"
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
	runner.completed.connect(_on_request_completed)
	runner.request(_backend_url + ENDPOINT, request.to_dictionary())


func _read_backend_url() -> String:
	if ProjectSettings.has_setting(BACKEND_URL_SETTING):
		return ProjectSettings.get_setting(BACKEND_URL_SETTING)
	return DEFAULT_BACKEND_URL


func _get_master_artifact_id() -> String:
	var artifact: MasterArtifact = DataRepository.singleton().master_artifact
	if artifact != null:
		return artifact.id
	return ""


func _on_request_completed(http_result: int, response_code: int, body: PackedByteArray) -> void:
	if http_result != HTTPRequest.RESULT_SUCCESS:
		var status := PortalResult.Status.NETWORK_ERROR
		if http_result == HTTPRequest.RESULT_TIMEOUT:
			status = PortalResult.Status.TIMEOUT_ERROR
		var err := PortalDiscoveryResponse.new()
		err.ok = false
		err.error = _http_error_message(http_result)
		discovery_completed.emit(PortalResult.new(status, err, err.error))
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		var err := PortalDiscoveryResponse.new()
		err.ok = false
		err.error = "invalid JSON from backend"
		discovery_completed.emit(
			PortalResult.new(PortalResult.Status.NETWORK_ERROR, err, err.error)
		)
		return

	var data: Dictionary = json.data
	var response := PortalDiscoveryResponse.from_dictionary(data)

	if response_code >= 400 or not response.ok:
		var status := PortalResult.Status.VALIDATION_ERROR
		if response_code >= 500:
			status = PortalResult.Status.NETWORK_ERROR
		discovery_completed.emit(PortalResult.new(status, response, response.error))
		return

	var status := PortalResult.Status.SUCCESS
	if response.used_fallback:
		status = PortalResult.Status.FALLBACK
	discovery_completed.emit(PortalResult.new(status, response, ""))


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

	func request(url: String, body: Dictionary) -> void:
		Engine.get_main_loop().root.add_child(_http)
		var headers := PackedStringArray(["Content-Type: application/json"])
		_http.timeout = REQUEST_TIMEOUT_MS / 1000.0
		_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

	func _on_completed(
		result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
	) -> void:
		_http.queue_free()
		completed.emit(result, response_code, body)
