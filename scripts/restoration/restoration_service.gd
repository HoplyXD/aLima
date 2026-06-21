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


## Result of working a tool against one surface decal.
class DecalResult:
	var ok: bool = false
	var compatible: bool = false  ## True when the tool matched the decal's required tool.
	var feedback: String = ""
	var decal_id: String = ""
	var removed: bool = false  ## True when this action cleared the decal.
	var reached_clean: bool = false  ## True when this action cleared the last decal.
	var condition_after: float = 0.0
	var value_after: int = 0
	var recorded_damage: int = 0
	var remaining_decals: int = 0


## Result of attempting the join step (e.g. taping torn photo halves).
class JoinResult:
	var ok: bool = false
	var error: String = ""
	var joined: bool = false


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


## Returns all owned tools with their definitions. Includes the id-set ownership
## (starting kit / legacy rewards) and any usable durability-tracked instances.
func get_available_tools() -> Array[ToolDefinition]:
	var owned_ids: Array[String] = []
	owned_ids.append_array(_game_state.save_state.loop.tool_items)
	owned_ids.append_array(_game_state.save_state.persistent.legacy_items)
	for raw in _game_state.save_state.loop.owned_tools:
		if raw is Dictionary and _instance_usable(raw):
			owned_ids.append(ModelUtils.as_string(raw.get("tool_id")))

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


## The tools loaded into the bench (max 5), as definitions. Owned tools auto-equip
## on grant, so the loadout is the source of truth: an empty loadout means the
## player deliberately removed everything (bench shows nothing). The only fallback
## to "all available" is the id-set-only path (no durability instances at all),
## which is the legacy/seed case used in tests.
func get_workbench_tools() -> Array[ToolDefinition]:
	var loadout: Array = _game_state.save_state.loop.workbench_tools
	if loadout.is_empty():
		if _game_state.save_state.loop.owned_tools.is_empty():
			return get_available_tools()
		return []
	var out: Array[ToolDefinition] = []
	var seen := {}
	for raw in _game_state.save_state.loop.owned_tools:
		if not (raw is Dictionary):
			continue
		var uid := ModelUtils.as_string(raw.get("uid"))
		if not loadout.has(uid) or not _instance_usable(raw):
			continue
		var tool_id := ModelUtils.as_string(raw.get("tool_id"))
		if seen.has(tool_id):
			continue
		seen[tool_id] = true
		var tool := _repo.get_tool(tool_id)
		if tool != null:
			out.append(tool)
	return out


## Durability of each bench tool: tool_id -> {current: int, max: int}. An infinite
## tool reports max <= 0. For the tool-tray durability bars. Empty in the legacy/seed
## id-set case (no durability instances).
func get_workbench_durability() -> Dictionary:
	var out := {}
	var loadout: Array = _game_state.save_state.loop.workbench_tools
	for raw in _game_state.save_state.loop.owned_tools:
		if not (raw is Dictionary):
			continue
		var uid := ModelUtils.as_string(raw.get("uid"))
		if not loadout.has(uid):
			continue
		var tool_id := ModelUtils.as_string(raw.get("tool_id"))
		if out.has(tool_id):
			continue
		out[tool_id] = {
			"current": ModelUtils.as_int(raw.get("durability")),
			"max": ModelUtils.as_int(raw.get("max_durability")),
		}
	return out


## The bench as fixed slots: an Array of length WORKBENCH_SLOTS where each entry is a
## tool_id, or "" for an empty (or broken) slot. A tool stays pinned to the slot it
## was equipped into, so a single tool in slot 4 leaves slots 0-3 empty. The legacy
## id-set case (no durability instances) packs the available tools from slot 0.
const WORKBENCH_SLOTS: int = 5


func get_workbench_slots() -> Array:
	var slots: Array = []
	var loadout: Array = _game_state.save_state.loop.workbench_tools
	if loadout.is_empty() and _game_state.save_state.loop.owned_tools.is_empty():
		for tool in get_available_tools():
			slots.append(tool.id)
	else:
		for raw_uid in loadout:
			var uid := ModelUtils.as_string(raw_uid)
			slots.append(_usable_tool_id_for_uid(uid))
	while slots.size() < WORKBENCH_SLOTS:
		slots.append("")
	return slots


## The tool_id of a usable owned instance for `uid`, or "" (unknown/broken/empty slot).
func _usable_tool_id_for_uid(uid: String) -> String:
	if uid.is_empty():
		return ""
	for raw in _game_state.save_state.loop.owned_tools:
		if not (raw is Dictionary) or ModelUtils.as_string(raw.get("uid")) != uid:
			continue
		if not _instance_usable(raw):
			return ""
		return ModelUtils.as_string(raw.get("tool_id"))
	return ""


## True if the player currently owns the named tool (id-set ownership or a usable
## durability-tracked instance).
func is_tool_owned(tool_id: String) -> bool:
	if (
		_game_state.save_state.loop.tool_items.has(tool_id)
		or _game_state.save_state.persistent.legacy_items.has(tool_id)
	):
		return true
	for raw in _game_state.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == tool_id and _instance_usable(raw):
			return true
	return false


func _instance_usable(raw: Dictionary) -> bool:
	var max_d := ModelUtils.as_int(raw.get("max_durability"))
	return max_d <= 0 or ModelUtils.as_int(raw.get("durability")) > 0


## Wears down one durability-tracked instance of the given tool after a use. The
## most-worn usable instance is consumed first; when it breaks it is removed from
## owned tools and the bench loadout, and EventBus.tool_broke is emitted. Tools
## owned only via the id-set (starting kit / legacy) never wear.
func _consume_tool_durability(tool_id: String) -> void:
	var owned: Array = _game_state.save_state.loop.owned_tools
	var best := -1
	var best_durability := 0
	for i in range(owned.size()):
		var raw = owned[i]
		if not (raw is Dictionary) or raw.get("tool_id") != tool_id:
			continue
		if ModelUtils.as_int(raw.get("max_durability")) <= 0:
			continue  # infinite tool; never wears.
		var durability := ModelUtils.as_int(raw.get("durability"))
		if durability <= 0:
			continue  # already broken.
		# Wear the most-worn usable instance first, so backups stay fresh.
		if best < 0 or durability < best_durability:
			best = i
			best_durability = durability
	if best < 0:
		return
	var inst: Dictionary = owned[best]
	inst["durability"] = ModelUtils.as_int(inst.get("durability")) - 1
	owned[best] = inst
	if ModelUtils.as_int(inst.get("durability")) <= 0:
		var uid := ModelUtils.as_string(inst.get("uid"))
		owned.remove_at(best)
		_game_state.save_state.loop.workbench_tools.erase(uid)
		EventBus.tool_broke.emit(tool_id, uid)


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
	_consume_tool_durability(tool_id)
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
	if template == null:
		return false
	# Openable objects clean toward a clasp; decal-based objects (photos/frames, or
	# any instance carrying random conditions) clean by removing marks. Anything else
	# is not a bench object.
	if not template.is_openable and effective_decals(inst, template).is_empty():
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


## Persists the exact dirt-mask PNG onto the instance so the cleaned spots survive
## save/reload. Called by the view (presentation) since the mask lives there; the
## write + save stay in the service.
func persist_dirt_mask(uid: String, png_bytes: PackedByteArray) -> void:
	var inst := find_instance_by_id(uid)
	if inst == null:
		return
	inst.dirt_mask = png_bytes
	_write_instance_back(inst)
	SaveService.save_game()


func _write_instance_back(inst: ObjectInstance) -> void:
	var inventory := _game_state.save_state.loop.inventory
	for i in range(inventory.size()):
		var raw = inventory[i]
		if raw is Dictionary and raw.get("uid") == inst.uid:
			inventory[i] = inst.to_dictionary()
			return


## ---------------------------------------------------------------------------
## Decal-based cleaning (photos, frames, paper) and the join step.
## ---------------------------------------------------------------------------


## True when the template cleans by removing discrete decals rather than by a
## condition threshold.
func is_decal_based(template: ScrapObjectTemplate) -> bool:
	return template != null and not template.decals.is_empty()


## The decals to clean for an instance: its randomly spawned conditions when it has
## them, otherwise the template's authored decals. This is what lets ordinary
## delivered artifacts carry random surface conditions while quest photos keep their
## authored ones.
func effective_decals(inst: ObjectInstance, template: ScrapObjectTemplate) -> Array[SurfaceDecal]:
	if inst != null and not inst.spawned_decals.is_empty():
		return inst.get_spawned_decals()
	return template.decals if template != null else ([] as Array[SurfaceDecal])


## True when this instance cleans by removing discrete decals (spawned or authored).
func instance_is_decal_based(inst: ObjectInstance, template: ScrapObjectTemplate) -> bool:
	return not effective_decals(inst, template).is_empty()


## Returns the decal with the given id among `decals`, or null.
func _find_decal_in(decals: Array, decal_id: String) -> SurfaceDecal:
	for decal in decals:
		if decal.id == decal_id:
			return decal
	return null


## Works the selected tool against one decal. The matching tool removes the
## decal and raises condition/value proportionally; the wrong tool applies the
## template's wrong-tool damage and leaves the decal in place. The object reaches
## CLEAN once the final decal is removed. Saves on a successful action.
func clean_decal(uid: String, decal_id: String, tool_id: String) -> DecalResult:
	var result := DecalResult.new()
	result.decal_id = decal_id
	var inst := find_instance_by_id(uid)
	if inst == null:
		result.feedback = "Item not found."
		return result

	var template := _repo.get_template(inst.template_id)
	var decals := effective_decals(inst, template)
	if template == null or decals.is_empty():
		result.feedback = "This object is not cleaned with decals."
		return result
	if not is_tool_owned(tool_id):
		result.feedback = "Tool not available."
		return result
	if inst.state == ModelEnums.ObjState.OPEN:
		result.feedback = "Already finished."
		return result

	var decal := _find_decal_in(decals, decal_id)
	if decal == null:
		result.feedback = "No such mark."
		return result
	if inst.removed_decals.has(decal_id):
		result.feedback = "That spot is already clean."
		result.removed = false
		result.condition_after = inst.condition
		result.value_after = inst.value
		result.remaining_decals = _remaining_decals(template, inst)
		return result

	result.compatible = decal.required_tool == tool_id
	var tool := _repo.get_tool(tool_id)
	var tool_name := tool.display_name if tool != null else tool_id
	if result.compatible:
		inst.removed_decals.append(decal_id)
		var total := decals.size()
		inst.condition = minf(float(inst.removed_decals.size()) / float(total) * 100.0, 100.0)
		inst.value = clampi(
			inst.value + template.clean_value_bonus,
			int(template.base_value_range.x),
			int(template.base_value_range.y)
		)
		result.removed = true
		result.feedback = "%s lifted the %s." % [tool_name, decal.type]
		if _remaining_decals(template, inst) == 0 and inst.state == ModelEnums.ObjState.DIRTY:
			inst.state = ModelEnums.ObjState.CLEAN
			result.reached_clean = true
			EventBus.restoration_completed.emit(inst.uid, inst.condition, tool_id)
	else:
		var condition_damage := template.wrong_tool_condition_damage
		var value_damage := template.wrong_tool_value_damage
		inst.condition = maxf(inst.condition - float(condition_damage), 0.0)
		inst.value = maxi(inst.value - value_damage, int(template.base_value_range.x))
		inst.recorded_damage += condition_damage + value_damage
		result.feedback = (
			template.wrong_tool_feedback
			if not template.wrong_tool_feedback.is_empty()
			else "%s is wrong for the %s." % [tool_name, decal.type]
		)

	result.condition_after = inst.condition
	result.value_after = inst.value
	result.recorded_damage = inst.recorded_damage
	result.remaining_decals = _remaining_decals(template, inst)
	_consume_tool_durability(tool_id)
	_write_instance_back(inst)
	SaveService.save_game()
	result.ok = true
	return result


func _remaining_decals(template: ScrapObjectTemplate, inst: ObjectInstance) -> int:
	var remaining := 0
	for decal in effective_decals(inst, template):
		if not inst.removed_decals.has(decal.id):
			remaining += 1
	return remaining


## Performs the join step on a reassemblable object (e.g. taping torn halves).
## Requires every decal removed (state CLEAN) and the authored join tool. Saves
## on success. The join is single-use and idempotent.
func join_object(uid: String, tool_id: String) -> JoinResult:
	var out := JoinResult.new()
	var inst := find_instance_by_id(uid)
	if inst == null:
		out.error = "Item not found."
		return out

	var template := _repo.get_template(inst.template_id)
	if template == null or not template.requires_join:
		out.error = "This object does not need joining."
		return out
	if inst.is_joined:
		out.joined = true
		out.ok = true
		return out
	if inst.state != ModelEnums.ObjState.CLEAN:
		out.error = "Treat every mark before joining the pieces."
		return out
	if not is_tool_owned(tool_id) or tool_id != template.join_tool:
		out.error = "You need the right tool to join the pieces."
		return out

	inst.is_joined = true
	out.joined = true
	out.ok = true
	_consume_tool_durability(tool_id)
	_write_instance_back(inst)
	SaveService.save_game()
	return out
