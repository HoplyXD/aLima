class_name PortalDiscoveryResponse
## Typed response model for the backend Portal discovery endpoint.

var ok: bool = true
var museum_entry_id: String = ""
var fragment_index: int = 0
var fact_card: String = ""
var artifact_meta: Dictionary = {}
var used_fallback: bool = false
var error: String = ""


static func from_dictionary(data: Dictionary) -> PortalDiscoveryResponse:
	var resp := PortalDiscoveryResponse.new()
	resp.ok = data.get("ok", true) == true
	resp.museum_entry_id = ModelUtils.as_string(data.get("museum_entry_id"))
	resp.fragment_index = ModelUtils.as_int(data.get("fragment_index"), 0)
	resp.fact_card = ModelUtils.as_string(data.get("fact_card"))
	resp.artifact_meta = ModelUtils.as_dictionary(data.get("artifact_meta"))
	resp.used_fallback = data.get("used_fallback", false) == true
	resp.error = ModelUtils.as_string(data.get("error"))
	return resp


func to_dictionary() -> Dictionary:
	return {
		"ok": ok,
		"museum_entry_id": museum_entry_id,
		"fragment_index": fragment_index,
		"fact_card": fact_card,
		"artifact_meta": artifact_meta.duplicate(),
		"used_fallback": used_fallback,
		"error": error,
	}
