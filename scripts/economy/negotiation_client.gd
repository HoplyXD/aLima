extends Node
## NegotiationClient autoload — Godot client for the backend marketplace banter proxy.
##
## Calls POST /api/negotiate for an in-character buyer line + an offended flag.
## NEVER returns a price — the deterministic Negotiation engine owns all numbers.

const BACKEND_URL_SETTING := "network/portal/backend_url"
const DEFAULT_BACKEND_URL := "http://localhost:3000"
const ENDPOINT := "/api/negotiate"
const STATUS_ENDPOINT := "/api/negotiate/status"
const TIMEOUT_S := 6.0

var _backend_url := ""
var _live := false
var _model := ""


func _ready() -> void:
	_backend_url = (
		str(ProjectSettings.get_setting(BACKEND_URL_SETTING))
		if ProjectSettings.has_setting(BACKEND_URL_SETTING)
		else DEFAULT_BACKEND_URL
	)


func is_live() -> bool:
	return _live


func model_name() -> String:
	return _model


## GET /status → sets _live + _model. Call once when the haggle opens. Coroutine.
func probe_status() -> void:
	_live = false
	var res := await _request(_backend_url + STATUS_ENDPOINT, {}, HTTPClient.METHOD_GET)
	if res.get("ok", false) and (res.data as Dictionary).get("ok", false):
		_live = bool(res.data.get("live_capable", false))
		_model = str(res.data.get("model", ""))


## POST /api/negotiate → {ok, reply, offended}. ok=false ⇒ caller must fall back. Coroutine.
func fetch_banter(
	persona: BuyerPersona, current_offer: int, seller_price: int, message: String, history: Array
) -> Dictionary:
	if not _live or persona == null:
		return {"ok": false}
	var body := {
		"persona":
		{
			"display_name": persona.display_name,
			"motive": persona.motive,
			"negotiation_style": persona.negotiation_style,
		},
		"listing_price": seller_price if seller_price > 0 else current_offer,
		"player_message": message,
		"history": history,
	}
	var res := await _request(_backend_url + ENDPOINT, body, HTTPClient.METHOD_POST)
	if not res.get("ok", false):
		return {"ok": false}
	var data: Dictionary = res.data
	if bool(data.get("fallback", false)):
		return {"ok": false}
	var reply := str(data.get("buyer_message", "")).strip_edges()
	if reply.is_empty():
		return {"ok": false}
	return {"ok": true, "reply": reply, "offended": bool(data.get("offended", false))}


## Fire one HTTP request and await it. Returns {ok, code, data}. Never throws.
func _request(url: String, body: Dictionary, method: int) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_S
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	if http.request(url, headers, method, payload) != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": {}}
	var result: Array = await http.request_completed  # [result, code, headers, body]
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) >= 400:
		return {"ok": false, "code": int(result[1]), "data": {}}
	var json := JSON.new()
	if json.parse((result[3] as PackedByteArray).get_string_from_utf8()) != OK:
		return {"ok": false, "code": int(result[1]), "data": {}}
	if not (json.data is Dictionary):
		return {"ok": false, "code": int(result[1]), "data": {}}
	return {"ok": true, "code": int(result[1]), "data": json.data}
