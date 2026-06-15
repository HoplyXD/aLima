class_name PlacementContainer
## Shop anchor / outer container used by the Spawn Director.
##
## This is a minimal Phase 1 data contract so authored slice fixtures can be
## validated; scheduling and actual placement behavior are Phase 3+.

var id: String = ""
var display_name: String = ""
var compatibility_tags: Array[String] = []  ## e.g. "jewelry", "small", "sturdy".
var capacity: int = 6  ## Max openable items; tunable (PRD §23 D4 default <= 6).
var is_locked_by_default: bool = false
var unlock_requirement: String = ""  ## e.g. route id or flag; empty if always open.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> PlacementContainer:
	var c := PlacementContainer.new()
	c.id = ModelUtils.as_string(data.get("id"))
	c.display_name = ModelUtils.as_string(data.get("display_name"))
	c.compatibility_tags = ModelUtils.as_string_array(data.get("compatibility_tags"))
	c.capacity = ModelUtils.as_int(data.get("capacity"))
	c.is_locked_by_default = ModelUtils.as_bool(data.get("is_locked_by_default"))
	c.unlock_requirement = ModelUtils.as_string(data.get("unlock_requirement"))
	return c


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"compatibility_tags": compatibility_tags.duplicate(),
		"capacity": capacity,
		"is_locked_by_default": is_locked_by_default,
		"unlock_requirement": unlock_requirement,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	if compatibility_tags.is_empty():
		result.add_field_error(
			file_path,
			id,
			"compatibility_tags",
			"container must declare at least one compatibility tag"
		)
	if capacity <= 0:
		result.add_field_error(file_path, id, "capacity", "capacity must be positive")
	return result
