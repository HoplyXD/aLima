class_name ToolInstance
## A concrete owned copy of a tool, with its own durability.
##
## Tools are owned as instances so the player can buy several of the same tool
## and each wears independently. `max_durability` comes from the ToolDefinition;
## a value <= 0 means the tool never wears (free starter/legacy basics). When a
## finite tool's `durability` reaches 0 it has broken and must be replaced.

var uid: String = ""  ## Unique within the save.
var tool_id: String = ""  ## ToolDefinition id.
var durability: int = 0  ## Remaining uses; ignored when max_durability <= 0.
var max_durability: int = 0  ## <= 0 means infinite (never breaks).


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ToolInstance:
	var t := ToolInstance.new()
	t.uid = ModelUtils.as_string(data.get("uid"))
	t.tool_id = ModelUtils.as_string(data.get("tool_id"))
	t.max_durability = ModelUtils.as_int(data.get("max_durability"))
	t.durability = ModelUtils.as_int(data.get("durability"), t.max_durability)
	return t


func to_dictionary() -> Dictionary:
	return {
		"uid": uid,
		"tool_id": tool_id,
		"durability": durability,
		"max_durability": max_durability,
	}


## True when this tool never wears out (free starter/legacy basics).
func is_infinite() -> bool:
	return max_durability <= 0


## True when a finite tool has run out of durability and must be replaced.
func is_broken() -> bool:
	return not is_infinite() and durability <= 0


## True when the tool can still be used.
func is_usable() -> bool:
	return is_infinite() or durability > 0


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if uid.is_empty():
		result.add_field_error(file_path, uid, "uid", "tool instance uid is required")
	if tool_id.is_empty():
		result.add_field_error(file_path, uid, "tool_id", "tool instance tool_id is required")
	if max_durability > 0 and durability < 0:
		result.add_field_error(file_path, uid, "durability", "durability must be >= 0")
	return result
