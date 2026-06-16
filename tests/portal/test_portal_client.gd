extends GutTest
## Tests for PortalClient request parsing and configuration.

var _client: PortalClient = null
var _received: Array = []


func before_each() -> void:
	_client = PortalClient.new()
	_received.clear()
	_client.discovery_completed.connect(func(result: PortalResult): _received.append(result))


func after_each() -> void:
	_client = null


func test_backend_url_defaults_to_project_setting() -> void:
	assert_eq(_client.get_backend_url(), "http://localhost:3000")


func test_backend_url_can_be_overridden() -> void:
	_client.set_backend_url("http://example.com:9000")
	assert_eq(_client.get_backend_url(), "http://example.com:9000")


func test_success_response_emits_success_status() -> void:
	var body := (
		JSON
		. stringify(
			{
				"ok": true,
				"museum_entry_id": "entry_fragment_01_player",
				"fragment_index": 1,
				"fact_card": "A small gear.",
				"artifact_meta": {"name": "Gear", "period": "1920s", "origin": "Panay"},
				"used_fallback": false,
			}
		)
	)
	_client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, body.to_utf8_buffer())

	assert_eq(_received.size(), 1)
	var result: PortalResult = _received[0]
	assert_eq(result.status, PortalResult.Status.SUCCESS)
	assert_true(result.is_ok())
	assert_eq(result.response.museum_entry_id, "entry_fragment_01_player")
	assert_eq(result.response.fact_card, "A small gear.")
	assert_false(result.response.used_fallback)


func test_fallback_response_emits_fallback_status() -> void:
	var body := (
		JSON
		. stringify(
			{
				"ok": true,
				"museum_entry_id": "entry_fragment_02_player",
				"fragment_index": 2,
				"fact_card": "A plate.",
				"artifact_meta": {},
				"used_fallback": true,
			}
		)
	)
	_client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, body.to_utf8_buffer())

	assert_eq(_received.size(), 1)
	var result: PortalResult = _received[0]
	assert_eq(result.status, PortalResult.Status.FALLBACK)
	assert_true(result.is_ok())


func test_backend_validation_error_emits_validation_status() -> void:
	var body := JSON.stringify({"ok": false, "error": "invalid fragment"})
	_client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 400, body.to_utf8_buffer())

	assert_eq(_received.size(), 1)
	var result: PortalResult = _received[0]
	assert_eq(result.status, PortalResult.Status.VALIDATION_ERROR)
	assert_false(result.is_ok())


func test_timeout_emits_timeout_status() -> void:
	_client._on_request_completed(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())

	assert_eq(_received.size(), 1)
	var result: PortalResult = _received[0]
	assert_eq(result.status, PortalResult.Status.TIMEOUT_ERROR)
	assert_false(result.is_ok())


func test_network_error_emits_network_status() -> void:
	_client._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())

	assert_eq(_received.size(), 1)
	var result: PortalResult = _received[0]
	assert_eq(result.status, PortalResult.Status.NETWORK_ERROR)
	assert_false(result.is_ok())
