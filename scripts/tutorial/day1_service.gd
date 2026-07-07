extends Node
## Day 1 intro director. Handles the scripted sequence when the player first
## enters Day 1 (after the Day 0 tutorial is complete).
##
## Similar to TutorialService but for the Day 1 story intro. Runs once per save.
## Loads its script from data/tutorial/day1_script.json.

signal step_changed(step_id: String)
signal day1_intro_finished

const SCRIPT_PATH := "res://data/tutorial/day1_script.json"

var _steps: Array = []
var _step_ids: Array[String] = []
var _steps_by_id: Dictionary = {}
var _config: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	EventBus.scrap_submitted.connect(func(_sel: Dictionary) -> void: _signal_fired("scrap_submitted"))
	EventBus.triage_completed.connect(
		func(_kept: Variant, _recycled: Variant) -> void: _signal_fired("triage_completed")
	)
	SpaceManager.space_changed.connect(_on_space_changed)


func _on_space_changed(space: SpaceManager.Space) -> void:
	_signal_fired("space_changed", SpaceManager.Space.keys()[space])


func _signal_fired(signal_name: String, space_name: String = "") -> void:
	if not is_day1_intro_active():
		return
	var step := current_step()
	if step.is_empty():
		return
	var complete_on := ModelUtils.as_dictionary(step.get("complete_on"))
	if ModelUtils.as_string(complete_on.get("signal")) != signal_name:
		return
	var wanted_space := ModelUtils.as_string(complete_on.get("space"))
	if not wanted_space.is_empty() and wanted_space != space_name:
		return
	advance()


func is_day1_intro_active() -> bool:
	var p := GameState.save_state.persistent
	return p.tutorial_completed and not p.day1_intro_completed


func get_config() -> Dictionary:
	_ensure_loaded()
	return _config


func get_steps() -> Array:
	_ensure_loaded()
	return _steps


func get_step(step_id: String) -> Dictionary:
	_ensure_loaded()
	return _steps_by_id.get(step_id, {})


func get_step_index(step_id: String) -> int:
	return _step_ids.find(step_id)


func current_step_id() -> String:
	return GameState.save_state.persistent.day1_step


func current_step() -> Dictionary:
	return get_step(current_step_id())


func current_step_index() -> int:
	return get_step_index(current_step_id())


func advance() -> void:
	_ensure_loaded()
	if not is_day1_intro_active():
		return
	var idx := current_step_index()
	if idx < 0:
		idx = -1
	var next_idx := idx + 1
	if next_idx >= _step_ids.size():
		_finish()
		return
	var next_id := _step_ids[next_idx]
	_set_step(next_id)


func skip() -> void:
	_finish()


func _set_step(step_id: String) -> void:
	GameState.save_state.persistent.day1_step = step_id
	step_changed.emit(step_id)


func _finish() -> void:
	GameState.save_state.persistent.day1_intro_completed = true
	GameState.save_state.persistent.day1_step = ""
	day1_intro_finished.emit()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	if file == null:
		push_error("Day1Service: failed to open script: " + SCRIPT_PATH)
		return
	var json: Variant = JSON.parse_string(file.get_as_text())
	if json is Dictionary:
		_config = ModelUtils.as_dictionary(json.get("config"))
		_steps = SaveState._as_array(json.get("steps"))
		for step in _steps:
			if step is Dictionary:
				var sid := ModelUtils.as_string(step.get("id"))
				if not sid.is_empty():
					_step_ids.append(sid)
					_steps_by_id[sid] = step
	else:
		push_error("Day1Service: invalid script format")


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
