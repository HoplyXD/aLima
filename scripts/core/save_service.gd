extends Node
## Foundation for atomic, validated persistence.
##
## SaveService serializes the top-level SaveState, validates schema versions,
## provides a migration entrypoint, and writes atomically via temp file. It
## depends on GameState for the in-memory state but never touches scene nodes.

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.tmp"


func _ready() -> void:
	pass


## Serializes the current GameState into a JSON string and validates it.
func serialize_state() -> Dictionary:
	var payload := GameState.save_state.to_dictionary()
	return {"ok": true, "json": JSON.stringify(payload, "\t"), "payload": payload}


## Writes the current GameState to disk atomically. Returns a result dictionary
## with `ok`, `path`, and optional `error` fields.
func save_game() -> Dictionary:
	var serialized := serialize_state()
	if not serialized.ok:
		return {"ok": false, "error": "serialization failed"}

	var json_text: String = serialized.json
	if not _validate_json(json_text):
		return {"ok": false, "error": "serialized payload failed JSON validation"}

	var write_result := _atomic_write(json_text)
	if not write_result.ok:
		return write_result
	return {"ok": true, "path": SAVE_PATH}


## Loads and validates the save at SAVE_PATH, populating GameState.save_state.
## Returns a result dictionary with `ok`, `schema_version`, and `error`.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"ok": false, "error": "save file not found", "schema_version": -1}

	var parsed: Variant = _load_raw_json(SAVE_PATH)
	if parsed == null:
		return {"ok": false, "error": "save file is malformed JSON", "schema_version": -1}

	var version := ModelUtils.as_int(parsed.get("schema_version"), -1)
	if version != SaveState.CURRENT_SCHEMA_VERSION:
		var migrated := _migrate(parsed, version)
		if not migrated.ok:
			return {"ok": false, "error": migrated.error, "schema_version": version}
		parsed = migrated.payload

	var validation := SaveState.from_dictionary(parsed).validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error": "save validation failed: %s" % ", ".join(validation.errors()),
			"schema_version": version
		}

	GameState.save_state = SaveState.from_dictionary(parsed)
	GameState.player_id = GameState.save_state.player_id
	return {"ok": true, "schema_version": SaveState.CURRENT_SCHEMA_VERSION}


## Migration entrypoint. Supports the current schema and rejects anything newer.
func migrate_payload(payload: Dictionary, from_version: int) -> Dictionary:
	return _migrate(payload, from_version)


## Deletes both the temp and final save files. Useful for tests.
func delete_save_files() -> void:
	for path in [SAVE_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.open("user://").remove(path.get_file())


func _atomic_write(json_text: String) -> Dictionary:
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		var err := FileAccess.get_open_error()
		return {"ok": false, "error": "could not open temp save file (error %d)" % err}
	temp_file.store_string(json_text)
	temp_file.close()

	var parsed: Variant = _load_raw_json(TEMP_PATH)
	if parsed == null:
		return {"ok": false, "error": "temp save file did not parse; original save kept"}

	var validation := SaveState.from_dictionary(parsed).validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error":
			"temp save payload failed SaveState validation: %s" % ", ".join(validation.errors())
		}

	var dir := DirAccess.open("user://")
	if dir == null:
		return {"ok": false, "error": "could not open user:// for rename"}
	var rename_err := dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if rename_err != OK:
		return {"ok": false, "error": "rename failed with error %d" % rename_err}

	return {"ok": true}


func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	if from_version == SaveState.CURRENT_SCHEMA_VERSION:
		return {"ok": true, "payload": payload}
	if from_version > SaveState.CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported future schema version %d" % from_version}
	# Future migrations chain from older versions here.
	return {"ok": false, "error": "no migration defined for schema version %d" % from_version}


func _validate_json(text: String) -> bool:
	return JSON.parse_string(text) != null


func _load_raw_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed
