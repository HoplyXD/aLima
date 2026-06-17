class_name SurfaceDecal
## Authored grime/damage decal on a restorable object's surface.
##
## A decal is a single removable blemish (dust, dirt, rust, fading, tape
## residue, ...). For now it renders as a flat `color`; an authored texture can
## replace the colour later with no logic change. Each decal is cleared by one
## matching `required_tool`; applying the wrong tool damages the object. An
## object is CLEAN once every decal is removed.

## Reference set of decal types. This is documentation, not an enforced enum:
## new types may be authored in data without a code change.
const KNOWN_TYPES: Array[String] = [
	"dust",
	"dirt",
	"rust",
	"tarnish",
	"soot",
	"water_stain",
	"mold",
	"fading",
	"tape_residue",
	"grease",
	"verdigris",
	"crack",
	"paint_loss",
	"cobweb",
]

var id: String = ""  ## Stable within the owning template (e.g. "dust_top").
var type: String = ""  ## One of KNOWN_TYPES (not enforced).
var color: String = "#FFFFFF"  ## Hex placeholder colour; swapped for a texture later.
var required_tool: String = ""  ## ToolDefinition id that removes this decal.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> SurfaceDecal:
	var d := SurfaceDecal.new()
	d.id = ModelUtils.as_string(data.get("id"))
	d.type = ModelUtils.as_string(data.get("type"))
	d.color = ModelUtils.as_string(data.get("color"), "#FFFFFF")
	d.required_tool = ModelUtils.as_string(data.get("required_tool"))
	return d


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"color": color,
		"required_tool": required_tool,
	}


## Returns the placeholder colour as a Color. Falls back to white on a malformed
## hex string rather than erroring.
func to_color() -> Color:
	if not _is_valid_hex(color):
		return Color.WHITE
	return Color.html(color)


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "decal.id", "decal id is required")
	if type.is_empty():
		result.add_field_error(file_path, id, "decal.type", "decal type is required")
	if required_tool.is_empty():
		result.add_field_error(file_path, id, "decal.required_tool", "decal required_tool is required")
	if not _is_valid_hex(color):
		result.add_field_error(file_path, id, "decal.color", "color must be a #RRGGBB hex string")
	return result


func _is_valid_hex(value: String) -> bool:
	var hex := value.trim_prefix("#")
	if hex.length() != 6:
		return false
	return hex.is_valid_hex_number(false)
