class_name ValidationResult
## Accumulates structured validation errors for a model, file, or repository.
##
## Errors are human-readable strings that include the field and file path where
## possible. A result is valid when no errors have been added.

var _errors: Array[String] = []


func add_error(message: String) -> void:
	_errors.append(message)


func add_field_error(file_path: String, id: String, field: String, message: String) -> void:
	var parts: Array[String] = []
	if not file_path.is_empty():
		parts.append(file_path)
	if not id.is_empty():
		parts.append("id=%s" % id)
	if not field.is_empty():
		parts.append("field=%s" % field)
	parts.append(message)
	_errors.append(" | ".join(parts))


func absorb(other: ValidationResult) -> void:
	for err in other._errors:
		_errors.append(err)


func is_valid() -> bool:
	return _errors.is_empty()


func errors() -> Array[String]:
	return _errors.duplicate()


func error_count() -> int:
	return _errors.size()


func clear() -> void:
	_errors.clear()
