class_name MuseumRecordResponse
## Typed response for the backend museum record/retrieval endpoints.

var ok: bool = true
var museum_entry_id: String = ""
var record_id: String = ""
var record_type: String = ""
var fact_card: String = ""
var photo_ref: String = ""
var timeline_entry: String = ""
var regional_story: String = ""
var character_memory_refs: Array[String] = []
var artifact_meta: Dictionary = {}
var used_fallback: bool = false
var error: String = ""


static func from_dictionary(data: Dictionary) -> MuseumRecordResponse:
	var resp := MuseumRecordResponse.new()
	resp.ok = data.get("ok", true) == true
	resp.museum_entry_id = ModelUtils.as_string(data.get("museum_entry_id"))
	resp.record_id = ModelUtils.as_string(data.get("record_id"))
	resp.record_type = ModelUtils.as_string(data.get("record_type"))
	resp.fact_card = ModelUtils.as_string(data.get("fact_card"))
	resp.photo_ref = ModelUtils.as_string(data.get("photo_ref"))
	resp.timeline_entry = ModelUtils.as_string(data.get("timeline_entry"))
	resp.regional_story = ModelUtils.as_string(data.get("regional_story"))
	resp.character_memory_refs = ModelUtils.as_string_array(data.get("character_memory_refs"))
	resp.artifact_meta = ModelUtils.as_dictionary(data.get("artifact_meta"))
	resp.used_fallback = data.get("used_fallback", false) == true
	resp.error = ModelUtils.as_string(data.get("error"))
	return resp


func to_museum_entry() -> MuseumEntry:
	var entry := MuseumEntry.new()
	entry.artifact_id = record_id
	entry.fact_card = fact_card
	entry.photo_ref = photo_ref
	entry.timeline_entry = timeline_entry
	entry.regional_story = regional_story
	entry.character_memory_refs = character_memory_refs.duplicate()
	return entry


func to_dictionary() -> Dictionary:
	return {
		"ok": ok,
		"museum_entry_id": museum_entry_id,
		"record_id": record_id,
		"record_type": record_type,
		"fact_card": fact_card,
		"photo_ref": photo_ref,
		"timeline_entry": timeline_entry,
		"regional_story": regional_story,
		"character_memory_refs": character_memory_refs.duplicate(),
		"artifact_meta": artifact_meta.duplicate(),
		"used_fallback": used_fallback,
		"error": error,
	}
