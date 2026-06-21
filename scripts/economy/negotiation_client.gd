extends Node
## Client for the backend LLM buyer-banter endpoint (POST /api/negotiate, MKT-R3).
##
## When online services are enabled and the backend is reachable, it returns a live,
## in-character buyer line for the current haggle. On ANY failure — online disabled,
## no internet, backend down/timeout, no model key, malformed reply — it returns ""
## and the caller keeps the deterministic offline banter. This client never decides
## prices and never blocks the deterministic flow; it only swaps in flavour text.

const TIMEOUT_SECONDS: float = 6.0


## Backend /api/negotiate URL from the project's configured backend base.
func _endpoint() -> String:
	var base := str(ProjectSettings.get_setting("network/portal/backend_url", "http://localhost:3000"))
	return base.rstrip("/") + "/api/negotiate"


## Fetches one LLM banter line, or "" to fall back to the offline line. Coroutine —
## await it. Never throws.
func fetch_banter(
	persona: BuyerPersona, listing_price: int, player_message: String, history: Array
) -> String:
	if persona == null or not SettingsService.online_enabled():
		return ""
	# Headless test runs never touch the network.
	if DisplayServer.get_name() == "headless":
		return ""

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
		return ""

	# request_completed → [result, response_code, headers, body].
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return ""
	var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if not (data is Dictionary) or not bool(data.get("ok", false)):
		return ""
	# fallback == true means the backend had no live model — keep the offline line.
	if bool(data.get("fallback", true)):
		return ""
	return str(data.get("buyer_message", ""))


## Keeps only the recent role/text turns for the backend transcript.
func _trim_history(history: Array) -> Array:
	var out: Array = []
	for turn in history:
		if turn is Dictionary and turn.has("role") and turn.has("text"):
			out.append({"role": str(turn["role"]), "text": str(turn["text"])})
	return out
