class_name MuseumRecordRequest
## Typed request for POST /api/portal/museum.

var record_id: String = ""
var player_id: String = ""
var rarity: String = "gold"  ## "gold" or "master_artifact".
var timestamp: String = ""
var condition: int = 0
var discovery_context: String = ""
var display_name: String = ""


func to_dictionary() -> Dictionary:
	return {
		"record_id": record_id,
		"player_id": player_id,
		"rarity": rarity,
		"timestamp": timestamp,
		"condition": condition,
		"discovery_context": discovery_context,
		"display_name": display_name,
	}
