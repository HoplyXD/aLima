class_name ModelUtils
## Shared helpers for dictionary serialization and validation used by models.


static func as_string(value: Variant, default_value: String = "") -> String:
	if value == null:
		return default_value
	return str(value)


static func as_int(value: Variant, default_value: int = 0) -> int:
	if value == null:
		return default_value
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return value.to_int()
	return default_value


static func as_float(value: Variant, default_value: float = 0.0) -> float:
	if value == null:
		return default_value
	if value is float or value is int:
		return float(value)
	if value is String:
		return value.to_float()
	return default_value


static func as_bool(value: Variant, default_value: bool = false) -> bool:
	if value == null:
		return default_value
	if value is bool:
		return value
	return default_value


static func as_string_array(value: Variant, default_value: Array[String] = []) -> Array[String]:
	if value == null:
		return default_value.duplicate()
	if value is Array:
		var out: Array[String] = []
		for item in value:
			out.append(str(item))
		return out
	return default_value.duplicate()


## Accepts a Vector2 or a two-element array and returns a Vector2.
static func as_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if value == null:
		return default_value
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(as_float(value[0]), as_float(value[1]))
	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(as_float(value.x), as_float(value.y))
	return default_value


static func vector2_to_array(v: Vector2) -> Array:
	return [v.x, v.y]


static func require_string(
	data: Dictionary, key: String, result: ValidationResult, file_path: String = "", id: String = ""
) -> String:
	if not data.has(key) or data[key] == null or str(data[key]).is_empty():
		result.add_field_error(file_path, id, key, "required string field is missing or empty")
		return ""
	return str(data[key])


static func require_string_array(
	data: Dictionary, key: String, result: ValidationResult, file_path: String = "", id: String = ""
) -> Array[String]:
	if not data.has(key) or data[key] == null:
		result.add_field_error(file_path, id, key, "required array field is missing")
		return []
	if not data[key] is Array:
		result.add_field_error(file_path, id, key, "expected an array")
		return []
	return as_string_array(data[key])
