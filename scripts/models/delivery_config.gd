class_name DeliveryConfig
## Authored configuration for morning delivery generation.
##
## Defines batch size bounds, rarity weight table, and the loop storage cap.
## Loaded from data/delivery/delivery_config.json by DataRepository.

var schema_version: int = 1
var batch_min: int = 3
var batch_max: int = 6
var storage_cap: int = 8  ## Total storage-cost budget for kept items.
var rarity_weights: Dictionary = {}  ## rarity_name -> float.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> DeliveryConfig:
	var cfg := DeliveryConfig.new()
	cfg.schema_version = ModelUtils.as_int(data.get("schema_version"), 1)
	cfg.batch_min = ModelUtils.as_int(data.get("batch_min"), 3)
	cfg.batch_max = ModelUtils.as_int(data.get("batch_max"), 6)
	cfg.storage_cap = ModelUtils.as_int(data.get("storage_cap"), 8)

	var raw_weights: Variant = data.get("rarity_weights")
	if raw_weights is Dictionary:
		for key in raw_weights.keys():
			var name := ModelUtils.as_string(key).to_lower().strip_edges()
			var weight: float = ModelUtils.as_float(raw_weights[key])
			cfg.rarity_weights[name] = weight
	return cfg


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"batch_min": batch_min,
		"batch_max": batch_max,
		"storage_cap": storage_cap,
		"rarity_weights": rarity_weights.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if schema_version != DataRepository.SCHEMA_VERSION:
		result.add_field_error(
			file_path, "", "schema_version", "unsupported schema version %d" % schema_version
		)
	if batch_min < 0:
		result.add_field_error(file_path, "", "batch_min", "batch_min must be non-negative")
	if batch_max < batch_min:
		result.add_field_error(file_path, "", "batch_max", "batch_max must be >= batch_min")
	if storage_cap < 1:
		result.add_field_error(file_path, "", "storage_cap", "storage_cap must be positive")

	var valid_rarities := ModelEnums.RARITY_NAMES
	for rarity_name in rarity_weights.keys():
		if valid_rarities.find(rarity_name) < 0:
			result.add_field_error(
				file_path, "", "rarity_weights", "unknown rarity '%s'" % rarity_name
			)
		var weight: float = rarity_weights[rarity_name]
		if weight < 0.0:
			result.add_field_error(
				file_path, "", "rarity_weights", "weight for %s must be non-negative" % rarity_name
			)
	return result
