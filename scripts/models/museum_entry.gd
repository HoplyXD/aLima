class_name MuseumEntry
## Persisted record for Gold finds and Master Artifact discoveries.

var artifact_id: String = ""  ## Fragment id for fragments; artifact id otherwise.
var fact_card: String = ""
var photo_ref: String = ""
var timeline_entry: String = ""
var regional_story: String = ""
var character_memory_refs: Array[String] = []


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> MuseumEntry:
	var m := MuseumEntry.new()
	m.artifact_id = ModelUtils.as_string(data.get("artifact_id"))
	m.fact_card = ModelUtils.as_string(data.get("fact_card"))
	m.photo_ref = ModelUtils.as_string(data.get("photo_ref"))
	m.timeline_entry = ModelUtils.as_string(data.get("timeline_entry"))
	m.regional_story = ModelUtils.as_string(data.get("regional_story"))
	m.character_memory_refs = ModelUtils.as_string_array(data.get("character_memory_refs"))
	return m


func to_dictionary() -> Dictionary:
	return {
		"artifact_id": artifact_id,
		"fact_card": fact_card,
		"photo_ref": photo_ref,
		"timeline_entry": timeline_entry,
		"regional_story": regional_story,
		"character_memory_refs": character_memory_refs.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if artifact_id.is_empty():
		result.add_field_error(
			file_path, artifact_id, "artifact_id", "required artifact_id is missing"
		)
	if fact_card.is_empty():
		result.add_field_error(file_path, artifact_id, "fact_card", "fact card is required")
	return result
