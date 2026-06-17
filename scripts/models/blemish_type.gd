class_name BlemishType
## Reference catalog entry for one kind of surface blemish (grime/damage).
##
## "Blemish" is the in-game umbrella term for the soiling/accretions the player
## cleans off an artifact; each authored `SurfaceDecal` on an object has a `type`
## that matches a BlemishType `id`. The journal's Blemish Guide renders these so
## the player learns which tool clears which blemish. `color` is a placeholder
## swatch for now and is replaced by an authored picture later.

var id: String = ""  ## Matches SurfaceDecal.type (e.g. "rust").
var display_name: String = ""  ## Player-facing name (e.g. "Rust").
var color: String = "#FFFFFF"  ## Placeholder swatch hex; swapped for a picture later.
var cleaning_tool: String = ""  ## ToolDefinition id that removes this blemish.
var description: String = ""  ## Short guide blurb.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> BlemishType:
	var b := BlemishType.new()
	b.id = ModelUtils.as_string(data.get("id"))
	b.display_name = ModelUtils.as_string(data.get("display_name"))
	b.color = ModelUtils.as_string(data.get("color"), "#FFFFFF")
	b.cleaning_tool = ModelUtils.as_string(data.get("cleaning_tool"))
	b.description = ModelUtils.as_string(data.get("description"))
	return b


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"color": color,
		"cleaning_tool": cleaning_tool,
		"description": description,
	}


## Returns the placeholder colour, falling back to white on a malformed hex.
func to_color() -> Color:
	var hex := color.trim_prefix("#")
	if hex.length() != 6 or not hex.is_valid_hex_number(false):
		return Color.WHITE
	return Color.html(color)


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "blemish id is required")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "blemish display_name is required")
	if cleaning_tool.is_empty():
		result.add_field_error(file_path, id, "cleaning_tool", "blemish cleaning_tool is required")
	var hex := color.trim_prefix("#")
	if hex.length() != 6 or not hex.is_valid_hex_number(false):
		result.add_field_error(file_path, id, "color", "color must be a #RRGGBB hex string")
	return result
