class_name JournalEntry
## Persistent archive entry for Purple-and-below finds.

var template_id: String = ""
var origin: String = ""
var materials: Array[String] = []
var weight_range: Vector2 = Vector2.ZERO
var clean_method: String = ""
var counterfeit_indicators: Array[String] = []
var historical_context: String = ""
var value_range: Vector2 = Vector2.ZERO
var best_condition: int = 0
var best_sale: int = 0
var variants_found: Array[String] = []
var uncle_notes: String = ""
var ai_annotations: String = ""
var temporal_echoes_unlocked: Array[String] = []


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> JournalEntry:
	var j := JournalEntry.new()
	j.template_id = ModelUtils.as_string(data.get("template_id"))
	j.origin = ModelUtils.as_string(data.get("origin"))
	j.materials = ModelUtils.as_string_array(data.get("materials"))
	j.weight_range = ModelUtils.as_vector2(data.get("weight_range"))
	j.clean_method = ModelUtils.as_string(data.get("clean_method"))
	j.counterfeit_indicators = ModelUtils.as_string_array(data.get("counterfeit_indicators"))
	j.historical_context = ModelUtils.as_string(data.get("historical_context"))
	j.value_range = ModelUtils.as_vector2(data.get("value_range"))
	j.best_condition = ModelUtils.as_int(data.get("best_condition"))
	j.best_sale = ModelUtils.as_int(data.get("best_sale"))
	j.variants_found = ModelUtils.as_string_array(data.get("variants_found"))
	j.uncle_notes = ModelUtils.as_string(data.get("uncle_notes"))
	j.ai_annotations = ModelUtils.as_string(data.get("ai_annotations"))
	j.temporal_echoes_unlocked = ModelUtils.as_string_array(data.get("temporal_echoes_unlocked"))
	return j


func to_dictionary() -> Dictionary:
	return {
		"template_id": template_id,
		"origin": origin,
		"materials": materials.duplicate(),
		"weight_range": ModelUtils.vector2_to_array(weight_range),
		"clean_method": clean_method,
		"counterfeit_indicators": counterfeit_indicators.duplicate(),
		"historical_context": historical_context,
		"value_range": ModelUtils.vector2_to_array(value_range),
		"best_condition": best_condition,
		"best_sale": best_sale,
		"variants_found": variants_found.duplicate(),
		"uncle_notes": uncle_notes,
		"ai_annotations": ai_annotations,
		"temporal_echoes_unlocked": temporal_echoes_unlocked.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if template_id.is_empty():
		result.add_field_error(
			file_path, template_id, "template_id", "required template_id is missing"
		)
	if best_condition < 0 or best_condition > 100:
		result.add_field_error(
			file_path, template_id, "best_condition", "best_condition must be 0..100"
		)
	if best_sale < 0:
		result.add_field_error(
			file_path, template_id, "best_sale", "best_sale must be non-negative"
		)
	return result
