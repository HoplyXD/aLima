class_name RestorationService
## Pure logic for the restoration mini-game and the clean/open state machine.
##
## RestorationService reads authored tuning from the DataRepository and applies
## deterministic tool consequences. It mutates the selected ObjectInstance inside
## GameState's loop inventory and persists through SaveService. UI nodes must not
## call SaveService directly.


## Result of applying a tool to an instance.
class ToolResult:
	var ok: bool = false
	var compatible: bool = false
	var feedback: String = ""
	var condition_before: float = 0.0
	var condition_after: float = 0.0
	var value_before: int = 0
	var value_after: int = 0
	var recorded_damage: int = 0
	var reached_clean: bool = false
	var state_changed: bool = false


## Result of attempting to open an instance's clasp.
class OpenAttemptResult:
	var ok: bool = false
	var error: String = ""
	var result: int = ModelEnums.OpenResult.EMPTY
	var content_id: String = ""


var _game_state: GameState
var _repo: DataRepository


func _init(
	game_state: GameState = GameState, repo: DataRepository = DataRepository.singleton()
) -> void:
	_game_state = game_state
	_repo = repo


## Exposes the data repository so the UI can look up display names without
## duplicating business logic.
func get_repository() -> DataRepository:
	return _repo


## Returns the loop-scoped ObjectInstance with the given uid, or null.
func find_instance_by_id(uid: String) -> ObjectInstance:
	for raw in _game_state.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return ObjectInstance.from_dictionary(raw)
	return null


## Returns every inventory instance that can currently enter restoration.
func get_restorable_instances() -> Array[ObjectInstance]:
	var out: Array[ObjectInstance] = []
	for raw in _game_state.save_state.loop.inventory:
		if raw is Dictionary:
			var inst := ObjectInstance.from_dictionary(raw)
			if _can_restore_instance(inst):
				out.append(inst)
	return out


## Returns all owned tools with their definitions.
func get_available_tools() -> Array[ToolDefinition]:
	var owned_ids: Array[String] = []
	owned_ids.append_array(_game_state.save_state.loop.tool_items)
	owned_ids.append_array(_game_state.save_state.persistent.legacy_items)

	var seen := {}
	var out: Array[ToolDefinition] = []
	for id in owned_ids:
		if seen.has(id):
			continue
		seen[id] = true
		var tool := _repo.get_tool(id)
		if tool != null:
			out.append(tool)
	return out


## True if the player currently owns the named tool.
func is_tool_owned(tool_id: String) -> bool:
	return (
		_game_state.save_state.loop.tool_items.has(tool_id)
		or _game_state.save_state.persistent.legacy_items.has(tool_id)
	)


## Applies one deliberate tool action to the instance. Saves on success.
func apply_tool(uid: String, tool_id: String) -> ToolResult:
	var result := ToolResult.new()
	var inst := find_instance_by_id(uid)
	if inst == null:
		result.feedback = "Item not found."
		return result

	var template := _repo.get_template(inst.template_id)
	var tool := _repo.get_tool(tool_id)
	if tool == null or not is_tool_owned(tool_id):
		result.feedback = "Tool not available."
		return result
	if template == null:
		result.feedback = "Unknown object template."
		return result
	if inst.state == ModelEnums.ObjState.OPEN:
		result.feedback = "Already opened."
		return result

	result.condition_before = inst.condition
	result.value_before = inst.value
	var compatible := _is_compatible_tool(template, tool)
	result.compatible = compatible

	if compatible:
		var gain := _calculate_condition_gain(template, tool)
		inst.condition = minf(inst.condition + gain, float(template.clean_completion_threshold))
		var value_gain := _calculate_value_gain(template, tool)
		inst.value = clampi(
			inst.value + value_gain,
			int(template.base_value_range.x),
			int(template.base_value_range.y)
		)
		result.feedback = (
			"%s lifted grime from the %s." % [tool.display_name, template.display_name]
		)

		if (
			inst.state == ModelEnums.ObjState.DIRTY
			and inst.condition >= template.clean_completion_threshold
		):
			inst.state = ModelEnums.ObjState.CLEAN
			result.reached_clean = true
			result.state_changed = true
			EventBus.restoration_completed.emit(inst.uid, inst.condition, tool_id)
	else:
		var condition_damage := float(template.wrong_tool_condition_damage)
		var value_damage := template.wrong_tool_value_damage
		inst.condition = maxf(inst.condition - condition_damage, 0.0)
		inst.value = maxi(inst.value - value_damage, int(template.base_value_range.x))
		inst.recorded_damage += int(condition_damage) + value_damage
		result.feedback = (
			template.wrong_tool_feedback
			if not template.wrong_tool_feedback.is_empty()
			else "%s is the wrong tool for the %s." % [tool.display_name, template.display_name]
		)

	result.condition_after = inst.condition
	result.value_after = inst.value
	result.recorded_damage = inst.recorded_damage
	_write_instance_back(inst)
	SaveService.save_game()
	result.ok = true
	return result


## Attempts to open the clasp of a CLEAN instance. Saves on success.
func open_clasp(uid: String) -> OpenAttemptResult:
	var out := OpenAttemptResult.new()
	var inst := find_instance_by_id(uid)
	if inst == null:
		out.error = "Item not found."
		return out

	var template := _repo.get_template(inst.template_id)
	if template == null or not template.is_openable:
		out.error = "This object cannot be opened."
		return out
	if inst.state == ModelEnums.ObjState.OPEN:
		out.error = "Already opened."
		return out
	if inst.state == ModelEnums.ObjState.DIRTY:
		out.error = "Too dirty to open. Clean it first."
		return out

	inst.state = ModelEnums.ObjState.OPEN
	out.result = inst.contents
	out.content_id = inst.fragment_id if inst.contents == ModelEnums.OpenResult.FRAGMENT else ""
	out.ok = true

	_write_instance_back(inst)
	EventBus.object_opened.emit(inst.uid, ModelEnums.open_result_name(out.result), out.content_id)
	if out.result == ModelEnums.OpenResult.FRAGMENT:
		EventBus.fragment_discovered.emit(inst.fragment_id, inst.uid)
	SaveService.save_game()
	return out


func _can_restore_instance(inst: ObjectInstance) -> bool:
	var template := _repo.get_template(inst.template_id)
	if template == null or not template.is_openable:
		return false
	if inst.state == ModelEnums.ObjState.OPEN:
		return false
	if inst.state == ModelEnums.ObjState.DIRTY:
		var required_tool := template.required_clean_tool
		if not required_tool.is_empty() and not is_tool_owned(required_tool):
			return false
	return true


func _is_compatible_tool(template: ScrapObjectTemplate, tool: ToolDefinition) -> bool:
	return tool.enables.has(template.clean_minigame) or tool.id == template.required_clean_tool


func _calculate_condition_gain(template: ScrapObjectTemplate, tool: ToolDefinition) -> float:
	var base := float(template.clean_progress_per_action)
	var tech_bonus := _technique_bonus(template.clean_minigame)
	return base * float(tool.quality) + tech_bonus


func _calculate_value_gain(template: ScrapObjectTemplate, tool: ToolDefinition) -> int:
	var base := template.clean_value_bonus
	var tech := _learned_technique(template.clean_minigame)
	var tech_bonus := tech.value_bonus if tech != null else 0
	return (base + tech_bonus) * tool.quality


func _technique_bonus(minigame: String) -> float:
	var tech := _learned_technique(minigame)
	return float(tech.quality_bonus) if tech != null else 0.0


func _learned_technique(minigame: String) -> TechniqueDefinition:
	for tech_id in _game_state.save_state.persistent.techniques_learned:
		var tech := _repo.get_technique(tech_id)
		if tech != null and tech.enables_minigame == minigame:
			return tech
	return null


func _write_instance_back(inst: ObjectInstance) -> void:
	var inventory := _game_state.save_state.loop.inventory
	for i in range(inventory.size()):
		var raw = inventory[i]
		if raw is Dictionary and raw.get("uid") == inst.uid:
			inventory[i] = inst.to_dictionary()
			return
