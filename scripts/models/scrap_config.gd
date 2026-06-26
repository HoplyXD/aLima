class_name ScrapConfig
## Authored configuration for the scrap-foraging loop (RV2-B).
##
## Declares how many scrap pickups spawn in the yard each day, the rarity weights
## used to scatter them, the per-tier output impulses that bias Ayla's sorted
## delivery, and the scatter bounds so map art swaps do not hardcode positions.

var schema_version: int = 1
var base_scatter_count: int = 10
var per_day_scatter_bonus: Dictionary = {}  ## day_string -> int.
var yard_scatter_rarity_weights: Dictionary = {}  ## rarity_name -> float.
var bias_impulses: Dictionary = {}  ## scrap_rarity -> {output_rarity -> float}.
var bias_scalar: float = 30.0
var scatter_bounds: Dictionary = {
	"center_x": 0.0,
	"center_z": -7.0,
	"size_x": 40.0,
	"size_z": 34.0,
}


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ScrapConfig:
	var cfg := ScrapConfig.new()
	cfg.schema_version = ModelUtils.as_int(data.get("schema_version"), 1)
	cfg.base_scatter_count = ModelUtils.as_int(data.get("base_scatter_count"), 10)
	cfg.per_day_scatter_bonus = ModelUtils.as_dictionary(data.get("per_day_scatter_bonus"))
	cfg.yard_scatter_rarity_weights = ModelUtils.as_dictionary(
		data.get("yard_scatter_rarity_weights")
	)
	cfg.bias_impulses = ModelUtils.as_dictionary(data.get("bias_impulses"))
	cfg.bias_scalar = ModelUtils.as_float(data.get("bias_scalar"), 30.0)
	cfg.scatter_bounds = ModelUtils.as_dictionary(data.get("scatter_bounds"))
	return cfg


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"base_scatter_count": base_scatter_count,
		"per_day_scatter_bonus": per_day_scatter_bonus.duplicate(),
		"yard_scatter_rarity_weights": yard_scatter_rarity_weights.duplicate(),
		"bias_impulses": bias_impulses.duplicate(true),
		"bias_scalar": bias_scalar,
		"scatter_bounds": scatter_bounds.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if schema_version != DataRepository.SCHEMA_VERSION:
		result.add_field_error(
			file_path, "", "schema_version", "unsupported schema version %d" % schema_version
		)
	if base_scatter_count < 0:
		result.add_field_error(file_path, "", "base_scatter_count", "must be non-negative")

	_validate_weight_table(
		result, file_path, "yard_scatter_rarity_weights", yard_scatter_rarity_weights
	)
	_validate_impulses(result, file_path)
	if bias_scalar < 0.0:
		result.add_field_error(file_path, "", "bias_scalar", "must be non-negative")
	return result


func _validate_weight_table(
	result: ValidationResult, file_path: String, field: String, table: Dictionary
) -> void:
	for rarity_name in table.keys():
		if ModelEnums.RARITY_NAMES.find(rarity_name) < 0:
			result.add_field_error(file_path, "", field, "unknown rarity '%s'" % rarity_name)
			continue
		var weight: float = table[rarity_name]
		if weight < 0.0:
			result.add_field_error(
				file_path, "", field, "weight for %s must be non-negative" % rarity_name
			)


func _validate_impulses(result: ValidationResult, file_path: String) -> void:
	for scrap_rarity in bias_impulses.keys():
		if ModelEnums.RARITY_NAMES.find(scrap_rarity) < 0:
			result.add_field_error(
				file_path, "", "bias_impulses", "unknown scrap rarity '%s'" % scrap_rarity
			)
			continue
		var impulse: Dictionary = ModelUtils.as_dictionary(bias_impulses[scrap_rarity])
		var total := 0.0
		for output_rarity in impulse.keys():
			if ModelEnums.RARITY_NAMES.find(output_rarity) < 0:
				(
					result
					. add_field_error(
						file_path,
						"",
						"bias_impulses",
						"unknown output rarity '%s'" % output_rarity,
					)
				)
				continue
			var weight: float = impulse[output_rarity]
			if weight < 0.0:
				(
					result
					. add_field_error(
						file_path,
						"",
						"bias_impulses",
						"impulse weight must be non-negative",
					)
				)
			total += weight
		if impulse.size() > 0 and (total < 0.99 or total > 1.01):
			(
				result
				. add_field_error(
					file_path,
					"",
					"bias_impulses",
					"impulse for %s does not sum to ~1.0 (got %.2f)" % [scrap_rarity, total],
				)
			)
