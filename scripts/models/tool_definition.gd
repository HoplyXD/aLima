class_name ToolDefinition
## Authored tool/kit definition.
##
## A Tool is loop-scoped unless is_legacy is true (route reward; persists).

var id: String = ""
var display_name: String = ""
var enables: Array[String] = []  ## Minigames/quality tags this tool unlocks.
var quality: int = 0  ## Higher is better; influences restoration outcome.
var cost: int = 0  ## Shop price in pesos.
var is_legacy: bool = false  ## True => persists across loops.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ToolDefinition:
	var t := ToolDefinition.new()
	t.id = ModelUtils.as_string(data.get("id"))
	t.display_name = ModelUtils.as_string(data.get("display_name"))
	t.enables = ModelUtils.as_string_array(data.get("enables"))
	t.quality = ModelUtils.as_int(data.get("quality"))
	t.cost = ModelUtils.as_int(data.get("cost"))
	t.is_legacy = ModelUtils.as_bool(data.get("is_legacy"))
	return t


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"enables": enables.duplicate(),
		"quality": quality,
		"cost": cost,
		"is_legacy": is_legacy,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	if enables.is_empty():
		result.add_field_error(
			file_path, id, "enables", "tool must enable at least one minigame or quality"
		)
	if quality < 0:
		result.add_field_error(file_path, id, "quality", "quality must be non-negative")
	if cost < 0:
		result.add_field_error(file_path, id, "cost", "cost must be non-negative")
	return result
