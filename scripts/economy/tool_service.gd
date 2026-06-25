class_name ToolService
## Owns the player's concrete tool instances and the bench loadout.
##
## Tools are owned as durability-tracked instances in `loop.owned_tools`. The
## bench shows at most MAX_WORKBENCH_TOOLS of them (8 — the tool sidebar holds eight
## rows) (`loop.workbench_tools`, by uid)
## and one selected artifact (`loop.restore_target_uid`). Marketplace purchases and
## the starting kit grant instances through here; RestorationService wears them
## down as they are used.

const MAX_WORKBENCH_TOOLS: int = 8

static var _uid_counter: int = 0

var _game_state: GameState
var _repo: DataRepository


func _init(
	game_state: GameState = GameState, repo: DataRepository = DataRepository.singleton()
) -> void:
	_game_state = game_state
	_repo = repo


## Builds a fresh, full-durability instance of a tool from its definition.
static func make_instance(tool_id: String, repo: DataRepository) -> ToolInstance:
	var def := repo.get_tool(tool_id)
	var inst := ToolInstance.new()
	inst.tool_id = tool_id
	inst.max_durability = def.durability if def != null else 0
	inst.durability = inst.max_durability
	_uid_counter += 1
	inst.uid = "%s#%d" % [tool_id, _uid_counter]
	return inst


## Grants a new tool instance into the player's owned tools and returns it. The
## instance auto-equips onto the bench while there is a free slot, so the first five
## owned tools are always loaded; the player can drag extras off in Storage.
func grant_tool(tool_id: String) -> ToolInstance:
	var inst := make_instance(tool_id, _repo)
	_game_state.save_state.loop.owned_tools.append(inst.to_dictionary())
	var wb: Array = _game_state.save_state.loop.workbench_tools
	if wb.size() < MAX_WORKBENCH_TOOLS and not wb.has(inst.uid):
		wb.append(inst.uid)
	return inst


## All owned tool instances (including broken ones).
func get_owned_tools() -> Array[ToolInstance]:
	var out: Array[ToolInstance] = []
	for raw in _game_state.save_state.loop.owned_tools:
		if raw is Dictionary:
			out.append(ToolInstance.from_dictionary(raw))
	return out


func owns_uid(uid: String) -> bool:
	for raw in _game_state.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == uid:
			return true
	return false


# --- Bench loadout (max 5) ---------------------------------------------------


## Adds an owned tool to the first free bench slot. Returns false if the bench is
## full, the tool is not owned, or it is already loaded. The bench is slot-based:
## entries may be "" for an empty slot, so this fills the first empty slot before
## appending.
func add_to_workbench(uid: String) -> bool:
	var wb: Array = _game_state.save_state.loop.workbench_tools
	if wb.has(uid):
		return true
	if _occupied_slots(wb) >= MAX_WORKBENCH_TOOLS or not owns_uid(uid):
		return false
	var empty := wb.find("")
	if empty != -1:
		wb[empty] = uid
	else:
		wb.append(uid)
	return true


## Unequips a tool but KEEPS its slot empty (""), so the other tools stay pinned to
## their slots instead of shifting left. Trailing empties are trimmed.
func remove_from_workbench(uid: String) -> void:
	var wb: Array = _game_state.save_state.loop.workbench_tools
	var i := wb.find(uid)
	if i == -1:
		return
	wb[i] = ""
	_trim_trailing_empty(wb)


## Number of tools actually on the bench (excludes empty slots).
func equipped_count() -> int:
	return _occupied_slots(_game_state.save_state.loop.workbench_tools)


## Number of occupied (non-empty) bench slots.
func _occupied_slots(wb: Array) -> int:
	var count := 0
	for entry in wb:
		if not ModelUtils.as_string(entry).is_empty():
			count += 1
	return count


## Drops trailing empty slots so the array doesn't grow without bound; interior gaps
## (which pin later tools to their slots) are preserved.
func _trim_trailing_empty(wb: Array) -> void:
	while not wb.is_empty() and ModelUtils.as_string(wb[wb.size() - 1]).is_empty():
		wb.remove_at(wb.size() - 1)


## Pins owned `uid` to bench `slot_index` (0-based). This is what a drag-and-drop
## onto a specific slot does:
##   * empty slot            → equip the tool there (earlier slots stay empty);
##   * slot held by another  → replace it (the displaced tool is unequipped);
##   * `uid` already equipped → swap the two slots so nothing else is disturbed.
## The tool stays in the exact slot dropped on, so a single tool dropped on slot 4
## renders at the far right with slots 0-3 empty. Only the targeted slot (and, on a
## swap, the tool's old slot) changes. Returns false only if the tool isn't owned.
func equip_to_slot(uid: String, slot_index: int) -> bool:
	if not owns_uid(uid):
		return false
	var wb: Array = _game_state.save_state.loop.workbench_tools
	slot_index = clampi(slot_index, 0, MAX_WORKBENCH_TOOLS - 1)
	# Grow the bench with empty slots so we can address the target slot directly.
	while wb.size() <= slot_index:
		wb.append("")
	var from_index := wb.find(uid)
	if from_index == slot_index:
		return true
	var displaced: Variant = wb[slot_index]
	wb[slot_index] = uid
	if from_index != -1:
		wb[from_index] = displaced  # swap: the slot's old occupant moves to uid's old slot
	# (if uid wasn't on the bench, the displaced occupant simply drops off)
	_trim_trailing_empty(wb)
	return true


## Replaces the whole loadout, keeping only owned uids and at most MAX tools.
func set_workbench(uids: Array) -> bool:
	var accepted: Array[String] = []
	for uid in uids:
		var id := ModelUtils.as_string(uid)
		if owns_uid(id) and not accepted.has(id) and accepted.size() < MAX_WORKBENCH_TOOLS:
			accepted.append(id)
	_game_state.save_state.loop.workbench_tools = accepted
	return accepted.size() == uids.size()


## Usable tool instances currently loaded in the bench.
func get_workbench_loadout() -> Array[ToolInstance]:
	var out: Array[ToolInstance] = []
	for uid in _game_state.save_state.loop.workbench_tools:
		var inst := _find_owned(uid)
		if inst != null and inst.is_usable():
			out.append(inst)
	return out


func set_restore_target(uid: String) -> void:
	_game_state.save_state.loop.restore_target_uid = uid


func get_restore_target() -> String:
	return _game_state.save_state.loop.restore_target_uid


func _find_owned(uid: String) -> ToolInstance:
	for raw in _game_state.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == uid:
			return ToolInstance.from_dictionary(raw)
	return null
