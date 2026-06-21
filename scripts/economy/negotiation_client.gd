extends Node
## Client for the backend LLM buyer-banter endpoint (POST /api/negotiate, MKT-R3).
##
## When online services are enabled and the backend is reachable, it returns a live,
## in-character buyer line for the current haggle. On ANY failure — online disabled,
## no internet, backend down/timeout, no model key, malformed reply — it returns ""
## and the caller keeps the deterministic offline banter. This client never decides
## prices and never blocks the deterministic flow; it only swaps in flavour text.

const TIMEOUT_SECONDS: float = 6.0

## Whether the most recent backend call actually returned a LIVE LLM reply (true) vs.
## fell back to offline (false). Drives the phone's AI/offline indicator.
var last_live: bool = false


## Backend /api/negotiate URL from the project's configured backend base.
func _endpoint() -> String:
	var base := str(ProjectSettings.get_setting("network/portal/backend_url", "http://localhost:3000"))
	return base.rstrip("/") + "/api/negotiate"


## Fetches one LLM banter line, or "" to fall back to the offline line. Coroutine —
## await it. Never throws.
func fetch_banter(
	persona: BuyerPersona, listing_price: int, player_message: String, history: Array
) -> String:
	var data := await _post(persona, listing_price, player_message, history)
	if data.is_empty() or bool(data.get("fallback", true)):
		return ""
	return str(data.get("buyer_message", ""))


## Fetches a live, in-character reply to the player's free-text message AND the LLM's
## contextual judgement of whether it was offensive/inappropriate. Returns
## {ok, reply, offended}; ok == false means use the offline path. Coroutine — await it.
func fetch_chat(
	persona: BuyerPersona, listing_price: int, player_message: String, history: Array
) -> Dictionary:
	var data := await _post(persona, listing_price, player_message, history)
	if data.is_empty() or bool(data.get("fallback", true)):
		return {"ok": false}
	return {
		"ok": true,
		"reply": str(data.get("buyer_message", "")),
		"offended": bool(data.get("offended", false)),
	}


## POSTs a negotiate payload and returns the parsed response dict, or {} on any failure
## (offline, headless, network/timeout, non-200, malformed, ok:false). Never throws.
func _post(
	persona: BuyerPersona, listing_price: int, player_message: String, history: Array
) -> Dictionary:
	last_live = false
	if persona == null:
		return {}
	if not SettingsService.online_enabled():
		_log("OFFLINE: 'Live buyer banter' is OFF — enable it in the pause-menu Settings.")
		return {}
	if DisplayServer.get_name() == "headless":  # tests never touch the network
		return {}
	var payload := {
		"persona":
		{
			"id": persona.id,
			"display_name": persona.display_name,
			"motive": persona.motive,
			"negotiation_style": persona.negotiation_style,
		},
		"listing_price": listing_price,
		"player_message": player_message,
		"history": _trim_history(history),
	}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	var err := http.request(
		_endpoint(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)
	)
	if err != OK:
		http.queue_free()
		_log("OFFLINE: could not start the request (bad URL %s?)." % _endpoint())
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		_log(
			(
				"OFFLINE: no response from %s (is the backend running? `npm run dev` in server/). result=%s http=%s"
				% [_endpoint(), result[0], result[1]]
			)
		)
		return {}
	var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if not (data is Dictionary) or not bool(data.get("ok", false)):
		_log("OFFLINE: malformed response from the backend.")
		return {}
	if bool(data.get("fallback", true)):
		_log("OFFLINE: backend is up but has NO ANTHROPIC_API_KEY — set it in server/.env to go live.")
		last_live = false
	else:
		_log("LIVE: got an LLM reply from the backend.")
		last_live = true
	return data


## Prints a one-line diagnostic in debug/editor builds so you can see why banter is
## live vs offline. Silent in exported release builds.
func _log(message: String) -> void:
	if OS.has_feature("editor") or OS.is_debug_build():
		print("[NegotiationClient] ", message)


## Keeps only the recent role/text turns for the backend transcript.
func _trim_history(history: Array) -> Array:
	var out: Array = []
	for turn in history:
		if turn is Dictionary and turn.has("role") and turn.has("text"):
			out.append({"role": str(turn["role"]), "text": str(turn["text"])})
	return out
