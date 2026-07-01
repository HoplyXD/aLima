extends Node
## Day 0 tutorial director (TUT). Registered as the `TutorialService` autoload.
##
## Owns the clockless Day 0 state machine: which authored step the player is on,
## resume-after-reload, and graduation/skip hand-off to LoopController. The step
## script itself (dialogue lines, hints, grants, completion signals) is authored
## data in data/tutorial/day0_script.json so narrative can iterate without code.
##
## Day 0 exists only while the save's persistent tutorial_completed flag is
## false — i.e. exactly once per newly created save file (CLAUDE.md §4-A: the
## flag is persistent, so later loops can never re-enter Day 0). The service
## never touches scene nodes; scene glue listens to step_changed.

## Emitted whenever the active step changes (including the resume re-announce).
signal step_changed(step_id: String)
## Emitted once when the tutorial graduates (played through or skipped).
signal tutorial_finished

const SCRIPT_PATH := "res://data/tutorial/day0_script.json"

var _steps: Array = []
var _step_ids: Array[String] = []
var _steps_by_id: Dictionary = {}
var _config: Dictionary = {}
var _loaded: bool = false


## True while this save is still inside Day 0.
func is_tutorial_active() -> bool:
	return not GameState.save_state.persistent.tutorial_completed


## Tutorial tuning block (sort_hours, allowed_conditions, ...). Empty when the
## script failed to load.
func get_config() -> Dictionary:
	_ensure_loaded()
	return _config


func get_steps() -> Array:
	_ensure_loaded()
	return _steps


func get_step(step_id: String) -> Dictionary:
	_ensure_loaded()
	var step: Variant = _steps_by_id.get(step_id)
	return step if step is Dictionary else {}


func current_step_id() -> String:
	return GameState.save_state.persistent.tutorial_step


func current_step() -> Dictionary:
	return get_step(current_step_id())


func first_step_id() -> String:
	_ensure_loaded()
	return _step_ids[0] if not _step_ids.is_empty() else ""


## The step after `step_id` in authored order, or "" at the end/unknown.
func next_step_id(step_id: String) -> String:
	_ensure_loaded()
	var index := _step_ids.find(step_id)
	if index < 0 or index + 1 >= _step_ids.size():
		return ""
	return _step_ids[index + 1]


## Idempotent session entry: called by LoopController.begin_session() every time
## a scene starts while Day 0 is active. Starts at the first step on a fresh
## save, or re-announces the persisted step so the new scene can catch up.
func begin_or_resume() -> void:
	_ensure_loaded()
	if not is_tutorial_active() or _step_ids.is_empty():
		return
	var step_id := current_step_id()
	if step_id.is_empty() or not _steps_by_id.has(step_id):
		advance_to(first_step_id())
	else:
		step_changed.emit(step_id)


## Moves to `step_id`, persisting it (with a save) so quitting mid-Day-0 resumes
## exactly here. Unknown/empty ids are ignored.
func advance_to(step_id: String) -> void:
	_ensure_loaded()
	if not is_tutorial_active():
		return
	if step_id.is_empty() or not _steps_by_id.has(step_id):
		push_warning("TutorialService.advance_to: unknown step '%s' ignored" % step_id)
		return
	GameState.save_state.persistent.tutorial_step = step_id
	var result := SaveService.save_game()
	if not result.ok:
		push_warning("TutorialService: step save failed: %s" % result.get("error", ""))
	step_changed.emit(step_id)


## Advances to the next authored step after the current one.
func advance() -> void:
	var next := next_step_id(current_step_id())
	if not next.is_empty():
		advance_to(next)


## Pause-menu skip: grants everything Day 0 would grant (the starting kit is
## granted inside complete_tutorial's reset) and jumps to Day 1.
func skip() -> void:
	if not is_tutorial_active():
		return
	LoopController.complete_tutorial()


## Called by LoopController.complete_tutorial() once graduation is saved.
func notify_completed() -> void:
	tutorial_finished.emit()


## Test seam: (re)load the step script from an explicit path.
func load_script_file(path: String = SCRIPT_PATH) -> bool:
	_steps = []
	_step_ids = []
	_steps_by_id = {}
	_config = {}
	_loaded = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TutorialService: cannot open %s" % path)
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		push_error("TutorialService: malformed tutorial script %s" % path)
		return false
	var doc: Dictionary = json.data
	_config = ModelUtils.as_dictionary(doc.get("config"))
	var raw_steps: Variant = doc.get("steps")
	if not (raw_steps is Array):
		raw_steps = []
	for raw in raw_steps:
		if not (raw is Dictionary):
			continue
		var step: Dictionary = raw
		var id := ModelUtils.as_string(step.get("id"))
		if id.is_empty() or _steps_by_id.has(id):
			push_error("TutorialService: missing/duplicate step id '%s' in %s" % [id, path])
			return false
		_steps.append(step)
		_step_ids.append(id)
		_steps_by_id[id] = step
	if _steps.is_empty():
		push_error("TutorialService: no steps in %s" % path)
		return false
	_loaded = true
	return true


func _ensure_loaded() -> void:
	if not _loaded:
		load_script_file()
