class_name ScrapObjectTemplate
## Authored definition for a scrap object that can appear in deliveries.
##
## This is a data contract, not a runtime instance. The same template can be
## instantiated many times; carrier promotion happens at runtime on an ordinary
## instance (CLAUDE.md §4-C).

var id: String = ""
var display_name: String = ""
var category: String = ""  ## e.g. "jewelry", "paper", "mechanical", "ceramic".
var base_rarity: int = ModelEnums.Rarity.WHITE
var weight_range: Vector2 = Vector2.ZERO
var materials: Array[String] = []
var tags: Array[String] = []  ## Compatibility tags for the Spawn Director (e.g. "small").
var is_openable: bool = false
var openable_type: String = ""  ## e.g. "pendant", "tin", "santo", "frame".
var required_clean_tool: String = ""  ## ToolDefinition id.
var clean_minigame: String = ""  ## Mini-game key used by restoration.
var base_value_range: Vector2 = Vector2.ZERO
var counterfeit_profile: String = ""  ## Optional ref; empty if none.
var historical_fact_ref: String = ""  ## Optional ref; empty if none.
var can_hold_temporal_echo: bool = false


func _init() -> void:
	pass


## Creates a model from a validated or partially-validated dictionary.
static func from_dictionary(data: Dictionary) -> ScrapObjectTemplate:
	var t := ScrapObjectTemplate.new()
	t.id = ModelUtils.as_string(data.get("id"))
	t.display_name = ModelUtils.as_string(data.get("display_name"))
	t.category = ModelUtils.as_string(data.get("category"))
	t.base_rarity = ModelEnums.rarity_from_name(ModelUtils.as_string(data.get("base_rarity")))
	t.weight_range = ModelUtils.as_vector2(data.get("weight_range"))
	t.materials = ModelUtils.as_string_array(data.get("materials"))
	t.tags = ModelUtils.as_string_array(data.get("tags"))
	t.is_openable = ModelUtils.as_bool(data.get("is_openable"))
	t.openable_type = ModelUtils.as_string(data.get("openable_type"))
	t.required_clean_tool = ModelUtils.as_string(data.get("required_clean_tool"))
	t.clean_minigame = ModelUtils.as_string(data.get("clean_minigame"))
	t.base_value_range = ModelUtils.as_vector2(data.get("base_value_range"))
	t.counterfeit_profile = ModelUtils.as_string(data.get("counterfeit_profile"))
	t.historical_fact_ref = ModelUtils.as_string(data.get("historical_fact_ref"))
	t.can_hold_temporal_echo = ModelUtils.as_bool(data.get("can_hold_temporal_echo"))
	return t


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"base_rarity": ModelEnums.rarity_name(base_rarity),
		"weight_range": ModelUtils.vector2_to_array(weight_range),
		"materials": materials.duplicate(),
		"tags": tags.duplicate(),
		"is_openable": is_openable,
		"openable_type": openable_type,
		"required_clean_tool": required_clean_tool,
		"clean_minigame": clean_minigame,
		"base_value_range": ModelUtils.vector2_to_array(base_value_range),
		"counterfeit_profile": counterfeit_profile,
		"historical_fact_ref": historical_fact_ref,
		"can_hold_temporal_echo": can_hold_temporal_echo,
	}


## Validates this instance and returns a result that accumulates errors.
func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing or empty")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	if category.is_empty():
		result.add_field_error(file_path, id, "category", "required category is missing")
	if ModelEnums.RARITY_NAMES.find(ModelEnums.rarity_name(base_rarity)) < 0:
		result.add_field_error(file_path, id, "base_rarity", "unknown rarity value")
	if weight_range.x < 0.0 or weight_range.y < weight_range.x:
		result.add_field_error(file_path, id, "weight_range", "invalid weight range")
	if materials.is_empty():
		result.add_field_error(file_path, id, "materials", "at least one material is required")
	if tags.is_empty():
		result.add_field_error(file_path, id, "tags", "at least one compatibility tag is required")
	if is_openable and openable_type.is_empty():
		result.add_field_error(
			file_path, id, "openable_type", "openable objects must declare an openable_type"
		)
	if is_openable and required_clean_tool.is_empty():
		result.add_field_error(
			file_path,
			id,
			"required_clean_tool",
			"openable objects must declare a required cleaning tool"
		)
	if base_value_range.x < 0.0 or base_value_range.y < base_value_range.x:
		result.add_field_error(file_path, id, "base_value_range", "invalid value range")
	return result
