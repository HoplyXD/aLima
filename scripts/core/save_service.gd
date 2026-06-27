extends Node
## Foundation for atomic, validated persistence.
##
## SaveService serializes the top-level SaveState, validates schema versions,
## provides a migration entrypoint, and writes atomically via temp file. It
## depends on GameState for the in-memory state but never touches scene nodes.
##
## Supports up to three independent save slots. Slot selection routes through the
## same save_path/temp_path fields so set_save_paths() test redirection keeps
## working; when no slot is selected the service falls back to the default single
## save file for backward compatibility.

const DEFAULT_SAVE_PATH := "user://save.json"
const DEFAULT_TEMP_PATH := "user://save.tmp"

const SLOT_COUNT: int = 3
const DEFAULT_SLOT: int = 0
const SLOT_SAVE_PATH := "user://save_slot_%d.json"
const SLOT_TEMP_PATH := "user://save_slot_%d.tmp"

## Active save paths. Defaulted to the real game save; overridable via
## set_save_paths() so tests never write into the developer's real save location.
var save_path: String = DEFAULT_SAVE_PATH
var temp_path: String = DEFAULT_TEMP_PATH

## Currently selected slot index. -1 means "no slot; use save_path/temp_path directly".
var _slot_index: int = -1


func _ready() -> void:
	pass


## Redirects save/temp writes (e.g. to an isolated test location). Both paths
## must share the same directory so the atomic temp->final rename stays valid.
func set_save_paths(new_save_path: String, new_temp_path: String) -> void:
	save_path = new_save_path
	temp_path = new_temp_path
	_slot_index = -1


## Selects one of the three save slots. All future save/load/delete operations
## target that slot until another slot is selected or set_save_paths() is called.
func select_slot(index: int) -> void:
	if not is_slot_valid(index):
		push_warning("SaveService.select_slot: invalid slot %d; ignoring" % index)
		return
	_slot_index = index
	save_path = SLOT_SAVE_PATH % index
	temp_path = SLOT_TEMP_PATH % index


func slot_count() -> int:
	return SLOT_COUNT


func is_slot_valid(index: int) -> bool:
	return index >= 0 and index < SLOT_COUNT


func get_selected_slot() -> int:
	return _slot_index


func slot_exists(index: int) -> bool:
	if not is_slot_valid(index):
		return false
	return FileAccess.file_exists(SLOT_SAVE_PATH % index)


## Deletes both files for the given slot. Does not change the active selection.
func delete_slot(index: int) -> void:
	if not is_slot_valid(index):
		return
	var final_path: String = SLOT_SAVE_PATH % index
	var tmp_path: String = SLOT_TEMP_PATH % index
	for path in [final_path, tmp_path]:
		if FileAccess.file_exists(path):
			DirAccess.open(path.get_base_dir()).remove(path.get_file())


## Lightweight metadata reader for the menu. Does not fully validate the payload
## and returns an empty dictionary if the file is missing or unreadable.
func slot_summary(index: int) -> Dictionary:
	if not is_slot_valid(index):
		return {}
	var path: String = SLOT_SAVE_PATH % index
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = _load_raw_json(path)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	var loop_raw: Variant = data.get("loop")
	var loop_data: Dictionary = loop_raw if loop_raw is Dictionary else {}
	return {
		"schema_version": ModelUtils.as_int(data.get("schema_version"), 0),
		"player_id": ModelUtils.as_string(data.get("player_id"), "local-player"),
		"run_seed": ModelUtils.as_int(data.get("run_seed"), 0),
		"loop_index": ModelUtils.as_int(data.get("loop_index"), 0),
		"current_day": ModelUtils.as_int(loop_data.get("current_day"), 1),
		"current_hour": ModelUtils.as_int(loop_data.get("current_hour"), 7),
		"money": ModelUtils.as_int(loop_data.get("money"), 0),
	}


## Serializes the current GameState into a JSON string and validates it.
func serialize_state() -> Dictionary:
	# Ensure the run context is always reflected into the save before serializing.
	GameState.save_state.run_seed = GameState.run_seed
	GameState.save_state.loop_index = GameState.loop_index
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
	return {"ok": true, "path": save_path}


## Loads and validates the save at save_path, populating GameState.save_state.
## On any failure the in-memory state is left untouched (a valid prior state and
## the on-disk save survive). Returns a result with `ok`, `schema_version`, `error`.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {"ok": false, "error": "save file not found", "schema_version": -1}

	var parsed: Variant = _load_raw_json(save_path)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "save file is malformed JSON", "schema_version": -1}

	var version := ModelUtils.as_int(parsed.get("schema_version"), -1)
	if version != SaveState.CURRENT_SCHEMA_VERSION:
		var migrated := _migrate(parsed, version)
		if not migrated.ok:
			return {"ok": false, "error": migrated.error, "schema_version": version}
		parsed = migrated.payload

	# Strict checks the model's coercive from_dictionary cannot catch (unknown
	# enum strings, non-numeric scalars, wrong section types).
	var raw_validation := _validate_raw_payload(parsed)
	if not raw_validation.is_valid():
		return {
			"ok": false,
			"error": "save validation failed: %s" % ", ".join(raw_validation.errors()),
			"schema_version": version
		}

	var validation := SaveState.from_dictionary(parsed).validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error": "save validation failed: %s" % ", ".join(validation.errors()),
			"schema_version": version
		}

	GameState.save_state = SaveState.from_dictionary(parsed)
	GameState.player_id = GameState.save_state.player_id
	# Restore the run context so procedural generation matches the saved run.
	GameState.restore_run_context(GameState.save_state.run_seed, GameState.save_state.loop_index)
	return {"ok": true, "schema_version": SaveState.CURRENT_SCHEMA_VERSION}


## Migration entrypoint. Supports the current schema and rejects anything newer.
func migrate_payload(payload: Dictionary, from_version: int) -> Dictionary:
	return _migrate(payload, from_version)


## Deletes both the temp and final save files for the active path. Useful for tests.
func delete_save_files() -> void:
	for path in [save_path, temp_path]:
		if FileAccess.file_exists(path):
			DirAccess.open(path.get_base_dir()).remove(path.get_file())


func _atomic_write(json_text: String) -> Dictionary:
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		var err := FileAccess.get_open_error()
		return {"ok": false, "error": "could not open temp save file (error %d)" % err}
	temp_file.store_string(json_text)
	temp_file.close()

	var parsed: Variant = _load_raw_json(temp_path)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "temp save file did not parse; original save kept"}

	var validation := SaveState.from_dictionary(parsed).validate()
	if not validation.is_valid():
		return {
			"ok": false,
			"error":
			"temp save payload failed SaveState validation: %s" % ", ".join(validation.errors())
		}

	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return {"ok": false, "error": "could not open save directory for rename"}
	var rename_err := dir.rename(temp_path.get_file(), save_path.get_file())
	if rename_err != OK:
		return {"ok": false, "error": "rename failed with error %d" % rename_err}

	return {"ok": true}


func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	if from_version == SaveState.CURRENT_SCHEMA_VERSION:
		return {"ok": true, "payload": payload}
	if from_version > SaveState.CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported future schema version %d" % from_version}
	if from_version == 1:
		var migrated: Dictionary = payload.duplicate(true)
		migrated["schema_version"] = 2
		migrated["run_seed"] = migrated.get("run_seed", 0)
		migrated["loop_index"] = migrated.get("loop_index", 0)
		return {"ok": true, "payload": migrated}
	# Future migrations chain from older versions here.
	return {"ok": false, "error": "no migration defined for schema version %d" % from_version}


## Strict validation of a current-schema raw payload, catching what the models'
## coercive from_dictionary() silently absorbs: unknown enum strings, non-numeric
## scalars, and wrong section types. Range checks (current_day/hour, money) remain
## the model's job and run afterwards.
func _validate_raw_payload(parsed: Dictionary) -> ValidationResult:
	var result := ValidationResult.new()

	_require_numeric(parsed, "run_seed", result)
	_require_numeric(parsed, "loop_index", result)

	var loop_raw: Variant = parsed.get("loop")
	if loop_raw != null and not (loop_raw is Dictionary):
		result.add_error("loop section must be an object")
	elif loop_raw is Dictionary:
		_require_numeric(loop_raw, "current_day", result)
		_require_numeric(loop_raw, "current_hour", result)
		_require_numeric(loop_raw, "money", result)

	var persistent_raw: Variant = parsed.get("persistent")
	if persistent_raw != null and not (persistent_raw is Dictionary):
		result.add_error("persistent section must be an object")
	elif persistent_raw is Dictionary:
		var fragments_raw: Variant = persistent_raw.get("fragments")
		if fragments_raw is Dictionary:
			for fragment_id in fragments_raw.keys():
				var fragment: Variant = fragments_raw[fragment_id]
				if fragment is Dictionary and fragment.has("state"):
					var state_name := str(fragment["state"]).to_lower().strip_edges()
					if ModelEnums.FRAGMENT_STATE_NAMES.find(state_name) < 0:
						result.add_error(
							(
								"fragment '%s' has unknown state '%s'"
								% [fragment_id, fragment["state"]]
							)
						)
	return result


## Flags a present-but-non-numeric scalar (e.g. a string where a number is required).
func _require_numeric(section: Dictionary, key: String, result: ValidationResult) -> void:
	if section.has(key):
		var value: Variant = section[key]
		if not (value is int or value is float):
			result.add_error("%s must be a number" % key)


func _validate_json(text: String) -> bool:
	return JSON.parse_string(text) != null


func _load_raw_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	# Use the JSON instance parser (not the static parse_string) so malformed input
	# returns an error code instead of pushing an engine error to the log.
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
