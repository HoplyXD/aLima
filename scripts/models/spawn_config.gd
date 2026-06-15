class_name SpawnConfig
## Tuning values for the Phase 5 Spawn Director.
##
## All weights and limits live in validated data (data/delivery/spawn_config.json)
## so gameplay code never hardcodes fragment-specific tuning.

var schema_version: int = 1
var base_candidate_weight: float = 1.0
var neglect_weight_multiplier: float = 0.5
var day_spread_weight_multiplier: float = 1.0
var min_candidate_weight: float = 0.0
var safe_container_id: String = "safe"
var safe_unlock_flag: String = "safe_code_known"


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> SpawnConfig:
	var cfg := SpawnConfig.new()
	cfg.schema_version = ModelUtils.as_int(data.get("schema_version"))
	cfg.base_candidate_weight = ModelUtils.as_float(data.get("base_candidate_weight"), 1.0)
	cfg.neglect_weight_multiplier = ModelUtils.as_float(data.get("neglect_weight_multiplier"), 0.5)
	cfg.day_spread_weight_multiplier = ModelUtils.as_float(
		data.get("day_spread_weight_multiplier"), 1.0
	)
	cfg.min_candidate_weight = ModelUtils.as_float(data.get("min_candidate_weight"), 0.0)
	cfg.safe_container_id = ModelUtils.as_string(data.get("safe_container_id"), "safe")
	cfg.safe_unlock_flag = ModelUtils.as_string(data.get("safe_unlock_flag"), "safe_code_known")
	return cfg


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"base_candidate_weight": base_candidate_weight,
		"neglect_weight_multiplier": neglect_weight_multiplier,
		"day_spread_weight_multiplier": day_spread_weight_multiplier,
		"min_candidate_weight": min_candidate_weight,
		"safe_container_id": safe_container_id,
		"safe_unlock_flag": safe_unlock_flag,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if schema_version != DataRepository.SCHEMA_VERSION:
		result.add_field_error(
			file_path,
			"spawn_config",
			"schema_version",
			(
				"unsupported schema version %d (expected %d)"
				% [schema_version, DataRepository.SCHEMA_VERSION]
			)
		)
	if base_candidate_weight <= 0.0:
		result.add_field_error(
			file_path, "spawn_config", "base_candidate_weight", "base weight must be positive"
		)
	if neglect_weight_multiplier < 0.0:
		result.add_field_error(
			file_path,
			"spawn_config",
			"neglect_weight_multiplier",
			"multiplier must be non-negative"
		)
	if day_spread_weight_multiplier < 0.0:
		result.add_field_error(
			file_path,
			"spawn_config",
			"day_spread_weight_multiplier",
			"multiplier must be non-negative"
		)
	if min_candidate_weight < 0.0:
		result.add_field_error(
			file_path, "spawn_config", "min_candidate_weight", "min weight must be non-negative"
		)
	if safe_container_id.is_empty():
		result.add_field_error(
			file_path, "spawn_config", "safe_container_id", "safe container id is required"
		)
	if safe_unlock_flag.is_empty():
		result.add_field_error(
			file_path, "spawn_config", "safe_unlock_flag", "safe unlock flag is required"
		)
	return result
