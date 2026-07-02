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


func _ready() -> void:
	# Completion wiring: each authored step declares the EventBus signal that
	# finishes it (complete_on). Connections are unconditional; _signal_fired is
	# a no-op outside Day 0.
	EventBus.scrap_submitted.connect(func(_sel: Dictionary) -> void: _signal_fired("scrap_submitted"))
	# Untyped params: some emitters pass plain Arrays where the signal declares
	# Array[String]; a typed lambda would reject those at call time.
	EventBus.triage_completed.connect(
		func(_kept: Variant, _recycled: Variant) -> void: _signal_fired("triage_completed")
	)
	EventBus.restoration_opened.connect(
		func(_uid: String) -> void: _signal_fired("restoration_opened")
	)
	EventBus.restoration_completed.connect(
		func(_uid: String, _condition: float, _tool_id: String) -> void:
			_signal_fired("restoration_completed")
	)
	EventBus.scanner_verdict_committed.connect(
		func(_uid: String, _verdict: String) -> void: _signal_fired("scanner_verdict_committed")
	)
	EventBus.sale_completed.connect(
		func(_uid: String, _buyer: String, _price: int) -> void: _signal_fired("sale_completed")
	)
	EventBus.meet_scheduled.connect(
		func(_uid: String, _buyer: String, _dest: String) -> void:
			_signal_fired("meet_scheduled")
	)
	EventBus.meet_handoff_completed.connect(
		func(_uid: String, _buyer: String, _price: int, _dest: String) -> void:
			_signal_fired("meet_handoff_completed")
	)
	SpaceManager.space_changed.connect(_on_space_changed)


func _on_space_changed(space: SpaceManager.Space) -> void:
	_signal_fired("space_changed", SpaceManager.Space.keys()[space])


## Advances the tutorial when the current step's authored completion signal
## fires (optionally constrained to a target space name for space_changed).
func _signal_fired(signal_name: String, space_name: String = "") -> void:
	if not is_tutorial_active():
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
		# Re-entering a step (scene change / reload): grants are idempotent, so
		# re-applying keeps a resume from ever losing the step's handouts.
		_apply_step_grants(get_step(step_id))
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
	_apply_step_grants(get_step(step_id))
	if step_id == "restoration_intro":
		_ensure_restorable_artifact()
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


## Day 0 ending beat: touching the Chronos journal blacks the screen out, the
## tutorial graduates at full darkness (atomic save inside complete_tutorial),
## and the shop reloads as a normal Day 1 before the fade back in. The overlay
## lives under this autoload so it survives the scene change. Returns true when
## the finale actually ran (the caller then skips opening the journal).
func run_finale() -> bool:
	if not is_tutorial_active() or current_step_id() != "journal_finale":
		return false
	var overlay := BlackoutOverlay.new()
	add_child(overlay)
	overlay.blacked_out.connect(
		func() -> void:
			LoopController.complete_tutorial()
			SpaceManager.go_to_shop()
			overlay.fade_out()
	)
	overlay.begin()
	return true


## Applies a step's authored grants. Idempotent so resume/replay is safe.
## grants.tools_for_conditions: for each surface-condition id, hand over the
## tool that cleans it (SurfaceCondition.cleaning_tool) — Yuyu's starter tools.
func _apply_step_grants(step: Dictionary) -> void:
	var grants := ModelUtils.as_dictionary(step.get("grants"))
	if grants.is_empty():
		return
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	var tools := ToolService.new(GameState, repo)
	for condition_id in ModelUtils.as_string_array(grants.get("tools_for_conditions")):
		var condition: SurfaceCondition = repo.get_surface_condition(condition_id)
		if condition == null:
			push_warning("TutorialService: unknown condition '%s' in grants" % condition_id)
			continue
		var tool_id := condition.cleaning_tool
		var tool := repo.get_tool(tool_id)
		if tool == null:
			push_warning("TutorialService: no tool cleans condition '%s'" % condition_id)
			continue
		if tool.is_legacy and not GameState.save_state.persistent.legacy_items.has(tool_id):
			GameState.save_state.persistent.legacy_items.append(tool_id)
		if not GameState.save_state.loop.tool_items.has(tool_id):
			GameState.save_state.loop.tool_items.append(tool_id)
		if not _owns_tool_instance(tool_id):
			tools.grant_tool(tool_id)


## Soft-lock guard: reaching the restoration step with nothing restorable (the
## player recycled the whole taught batch) injects one seeded common artifact —
## generated through the normal DeliveryGenerator path, so the tutorial's rarity
## and condition constraints still apply — and targets the bench at it.
func _ensure_restorable_artifact() -> void:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary:
			var existing := ObjectInstance.from_dictionary(raw)
			if existing.state == ModelEnums.ObjState.DIRTY:
				return
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	var cfg := DeliveryConfig.new()
	cfg.batch_min = 1
	cfg.batch_max = 1
	cfg.storage_cap = repo.get_delivery_config().storage_cap
	cfg.rarity_weights = {ModelEnums.rarity_name(ModelEnums.Rarity.WHITE): 1.0}
	var generator := DeliveryGenerator.new(repo, GameState)
	var delivery := generator.generate_day_delivery(GameState.save_state.loop.current_day, cfg)
	if delivery.is_empty():
		return
	var inst: ObjectInstance = delivery[0]
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	GameState.save_state.loop.restore_target_uid = inst.uid


func _owns_tool_instance(tool_id: String) -> bool:
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == tool_id:
			return true
	return false


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
