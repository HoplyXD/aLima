class_name PortalDiscoveryRequest
## Typed request model for POST /api/portal/discovery.

var artifact_id: String = ""
var fragment_id: String = ""
var player_id: String = ""
var timestamp: String = ""
var condition: int = 0
var discovery_context: String = ""


static func from_dictionary(data: Dictionary) -> PortalDiscoveryRequest:
	var req := PortalDiscoveryRequest.new()
	req.artifact_id = ModelUtils.as_string(data.get("artifact_id"))
	req.fragment_id = ModelUtils.as_string(data.get("fragment_id"))
	req.player_id = ModelUtils.as_string(data.get("player_id"))
	req.timestamp = ModelUtils.as_string(data.get("timestamp"))
	req.condition = ModelUtils.as_int(data.get("condition"), 0)
	req.discovery_context = ModelUtils.as_string(data.get("discovery_context"))
	return req


func to_dictionary() -> Dictionary:
	return {
		"artifact_id": artifact_id,
		"fragment_id": fragment_id,
		"player_id": player_id,
		"timestamp": timestamp,
		"condition": condition,
		"discovery_context": discovery_context,
	}
