class_name ScrapObjectTemplate
## Authored definition for a scrap object that can appear in deliveries.
##
## This is a data contract, not a runtime instance. The same template can be
## instantiated many times; carrier promotion happens at runtime on an ordinary
## instance (CLAUDE.md §4-C).

var id: String = ""
var display_name: String = ""
var description: String = ""  ## Optional flavour blurb for Storage; synthesized when empty.
var category: String = ""  ## e.g. "jewelry", "paper", "mechanical", "ceramic".
var base_rarity: int = ModelEnums.Rarity.WHITE
var weight_range: Vector2 = Vector2.ZERO
var materials: Array[String] = []
var tags: Array[String] = []  ## Compatibility tags for the Spawn Director (e.g. "small").
var is_openable: bool = false
var openable_type: String = ""  ## e.g. "pendant", "tin", "santo", "frame".
var required_clean_tool: String = ""  ## ToolDefinition id.
var clean_minigame: String = ""  ## Mini-game key used by restoration.
var clean_completion_threshold: int = 100  ## Condition required to reach CLEAN.
var clean_progress_per_action: int = 0  ## Base condition gained per correct action.
var clean_value_bonus: int = 0  ## Base value gained per correct action.
var wrong_tool_condition_damage: int = 0  ## Condition lost when an incompatible tool is used.
var wrong_tool_value_damage: int = 0  ## Value lost when an incompatible tool is used.
var wrong_tool_feedback: String = ""  ## Player-facing text for wrong-tool use.
var base_value_range: Vector2 = Vector2.ZERO
var storage_cost: int = 1  ## Loop inventory slots this template occupies.
var counterfeit_profile: String = ""  ## Optional ref; empty if none.
var historical_fact_ref: String = ""  ## Optional ref; empty if none.
var can_hold_temporal_echo: bool = false
var deliverable: bool = true  ## False => quest/given item; excluded from the delivery pool.
var decals: Array[SurfaceDecal] = []
## Authored grime/damage; empty => condition-based cleaning.
var requires_join: bool = false
## True => a join step (e.g. torn photo halves) completes restoration.
var join_tool: String = ""  ## ToolDefinition id required for the join step.


func _init() -> void:
	pass


## Creates a model from a validated or partially-validated dictionary.
static func from_dictionary(data: Dictionary) -> ScrapObjectTemplate:
	var t := ScrapObjectTemplate.new()
	t.id = ModelUtils.as_string(data.get("id"))
	t.display_name = ModelUtils.as_string(data.get("display_name"))
	t.description = ModelUtils.as_string(data.get("description"))
	t.category = ModelUtils.as_string(data.get("category"))
	t.base_rarity = ModelEnums.rarity_from_name(ModelUtils.as_string(data.get("base_rarity")))
	t.weight_range = ModelUtils.as_vector2(data.get("weight_range"))
	t.materials = ModelUtils.as_string_array(data.get("materials"))
	t.tags = ModelUtils.as_string_array(data.get("tags"))
	t.is_openable = ModelUtils.as_bool(data.get("is_openable"))
	t.openable_type = ModelUtils.as_string(data.get("openable_type"))
	t.required_clean_tool = ModelUtils.as_string(data.get("required_clean_tool"))
	t.clean_minigame = ModelUtils.as_string(data.get("clean_minigame"))
	t.clean_completion_threshold = ModelUtils.as_int(data.get("clean_completion_threshold"), 100)
	t.clean_progress_per_action = ModelUtils.as_int(data.get("clean_progress_per_action"))
	t.clean_value_bonus = ModelUtils.as_int(data.get("clean_value_bonus"))
	t.wrong_tool_condition_damage = ModelUtils.as_int(data.get("wrong_tool_condition_damage"))
	t.wrong_tool_value_damage = ModelUtils.as_int(data.get("wrong_tool_value_damage"))
	t.wrong_tool_feedback = ModelUtils.as_string(data.get("wrong_tool_feedback"))
	t.base_value_range = ModelUtils.as_vector2(data.get("base_value_range"))
	t.storage_cost = ModelUtils.as_int(data.get("storage_cost"), 1)
	t.counterfeit_profile = ModelUtils.as_string(data.get("counterfeit_profile"))
	t.historical_fact_ref = ModelUtils.as_string(data.get("historical_fact_ref"))
	t.can_hold_temporal_echo = ModelUtils.as_bool(data.get("can_hold_temporal_echo"))
	t.deliverable = ModelUtils.as_bool(data.get("deliverable"), true)
	var raw_decals: Variant = data.get("decals", [])
	if raw_decals is Array:
		for raw_decal in raw_decals:
			if raw_decal is Dictionary:
				t.decals.append(SurfaceDecal.from_dictionary(raw_decal))
	t.requires_join = ModelUtils.as_bool(data.get("requires_join"))
	t.join_tool = ModelUtils.as_string(data.get("join_tool"))
	return t


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"base_rarity": ModelEnums.rarity_name(base_rarity),
		"weight_range": ModelUtils.vector2_to_array(weight_range),
		"materials": materials.duplicate(),
		"tags": tags.duplicate(),
		"is_openable": is_openable,
		"openable_type": openable_type,
		"required_clean_tool": required_clean_tool,
		"clean_minigame": clean_minigame,
		"clean_completion_threshold": clean_completion_threshold,
		"clean_progress_per_action": clean_progress_per_action,
		"clean_value_bonus": clean_value_bonus,
		"wrong_tool_condition_damage": wrong_tool_condition_damage,
		"wrong_tool_value_damage": wrong_tool_value_damage,
		"wrong_tool_feedback": wrong_tool_feedback,
		"base_value_range": ModelUtils.vector2_to_array(base_value_range),
		"storage_cost": storage_cost,
		"counterfeit_profile": counterfeit_profile,
		"historical_fact_ref": historical_fact_ref,
		"can_hold_temporal_echo": can_hold_temporal_echo,
		"deliverable": deliverable,
		"decals": decals.map(func(d: SurfaceDecal) -> Dictionary: return d.to_dictionary()),
		"requires_join": requires_join,
		"join_tool": join_tool,
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
	if is_openable:
		if clean_completion_threshold <= 0 or clean_completion_threshold > 100:
			result.add_field_error(
				file_path, id, "clean_completion_threshold", "must be between 1 and 100"
			)
		if clean_progress_per_action < 0:
			result.add_field_error(
				file_path, id, "clean_progress_per_action", "must be non-negative"
			)
		if clean_value_bonus < 0:
			result.add_field_error(file_path, id, "clean_value_bonus", "must be non-negative")
		if wrong_tool_condition_damage < 0:
			result.add_field_error(
				file_path, id, "wrong_tool_condition_damage", "must be non-negative"
			)
		if wrong_tool_value_damage < 0:
			result.add_field_error(file_path, id, "wrong_tool_value_damage", "must be non-negative")
	if base_value_range.x < 0.0 or base_value_range.y < base_value_range.x:
		result.add_field_error(file_path, id, "base_value_range", "invalid value range")
	if storage_cost < 1:
		result.add_field_error(file_path, id, "storage_cost", "storage_cost must be at least 1")
	var seen_decal_ids := {}
	for decal in decals:
		decal.validate(result, file_path)
		if seen_decal_ids.has(decal.id):
			result.add_field_error(file_path, id, "decals", "duplicate decal id '%s'" % decal.id)
		seen_decal_ids[decal.id] = true
	if requires_join:
		if join_tool.is_empty():
			result.add_field_error(
				file_path, id, "join_tool", "requires_join objects must declare a join_tool"
			)
		if decals.is_empty():
			result.add_field_error(
				file_path, id, "decals", "requires_join objects must author at least one decal"
			)
	return result
