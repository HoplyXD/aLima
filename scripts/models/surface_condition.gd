class_name SurfaceCondition
## Reference catalog entry for one kind of surface condition the player treats
## during restoration.
##
## "Surface Condition" is the in-game umbrella term (conservators avoid the vague
## "blemish"). Each authored `SurfaceDecal` on an object has a `type` matching a
## SurfaceCondition `id`, and each condition belongs to a `category` — the family
## of damage it represents (surface soil, accretion, corrosion, staining, or
## structural damage). The journal's Condition Guide renders these grouped by
## category so the player learns which tool treats which condition. `color` is a
## placeholder swatch, replaced by an authored picture later.

## Category id -> player-facing label. Ordered as conservators triage a surface:
## loose soiling, foreign accretions, chemical corrosion, staining, then structural
## damage and media loss.
const CATEGORY_LABELS := {
	"surface_soil": "Surface Soil",
	"accretion": "Accretion",
	"corrosion": "Corrosion",
	"staining": "Staining",
	"structural_damage": "Structural Damage",
}
const CATEGORY_ORDER: Array[String] = [
	"surface_soil", "accretion", "corrosion", "staining", "structural_damage"
]

var id: String = ""  ## Matches SurfaceDecal.type (e.g. "rust").
var display_name: String = ""  ## Player-facing name (e.g. "Rust").
var category: String = "surface_soil"  ## One of CATEGORY_LABELS keys.
var color: String = "#FFFFFF"  ## Placeholder swatch hex; swapped for a picture later.
var cleaning_tool: String = ""  ## ToolDefinition id that treats this condition.
var description: String = ""  ## Short guide blurb.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> SurfaceCondition:
	var c := SurfaceCondition.new()
	c.id = ModelUtils.as_string(data.get("id"))
	c.display_name = ModelUtils.as_string(data.get("display_name"))
	c.category = ModelUtils.as_string(data.get("category"), "surface_soil")
	c.color = ModelUtils.as_string(data.get("color"), "#FFFFFF")
	c.cleaning_tool = ModelUtils.as_string(data.get("cleaning_tool"))
	c.description = ModelUtils.as_string(data.get("description"))
	return c


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"color": color,
		"cleaning_tool": cleaning_tool,
		"description": description,
	}


## Player-facing label for this condition's category.
func category_label() -> String:
	return CATEGORY_LABELS.get(category, category.capitalize())


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
		result.add_field_error(file_path, id, "id", "surface condition id is required")
	if display_name.is_empty():
		result.add_field_error(
			file_path, id, "display_name", "surface condition display_name is required"
		)
	if not CATEGORY_LABELS.has(category):
		result.add_field_error(
			file_path, id, "category", "unknown category '%s'" % category
		)
	if cleaning_tool.is_empty():
		result.add_field_error(
			file_path, id, "cleaning_tool", "surface condition cleaning_tool is required"
		)
	var hex := color.trim_prefix("#")
	if hex.length() != 6 or not hex.is_valid_hex_number(false):
		result.add_field_error(file_path, id, "color", "color must be a #RRGGBB hex string")
	return result
