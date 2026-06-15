class_name TechniqueDefinition
## Persistent knowledge of how to perform a restoration method.
##
## Techniques survive loop resets; they are learned from shops or characters.

var id: String = ""
var display_name: String = ""
var enables_minigame: String = ""  ## Minigame key this technique unlocks.
var learned_from: String = ""  ## "shop" or a character route id.
var quality_bonus: int = 0  ## Extra condition gained when this technique is known.
var value_bonus: int = 0  ## Extra value gained when this technique is known.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> TechniqueDefinition:
	var t := TechniqueDefinition.new()
	t.id = ModelUtils.as_string(data.get("id"))
	t.display_name = ModelUtils.as_string(data.get("display_name"))
	t.enables_minigame = ModelUtils.as_string(data.get("enables_minigame"))
	t.learned_from = ModelUtils.as_string(data.get("learned_from"))
	t.quality_bonus = ModelUtils.as_int(data.get("quality_bonus"))
	t.value_bonus = ModelUtils.as_int(data.get("value_bonus"))
	return t


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"enables_minigame": enables_minigame,
		"learned_from": learned_from,
		"quality_bonus": quality_bonus,
		"value_bonus": value_bonus,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	if enables_minigame.is_empty():
		result.add_field_error(
			file_path, id, "enables_minigame", "required enables_minigame is missing"
		)
	if learned_from.is_empty():
		result.add_field_error(file_path, id, "learned_from", "required learned_from is missing")
	if quality_bonus < 0:
		result.add_field_error(file_path, id, "quality_bonus", "must be non-negative")
	if value_bonus < 0:
		result.add_field_error(file_path, id, "value_bonus", "must be non-negative")
	return result
