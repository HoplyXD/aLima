class_name ToolService
## Owns the player's concrete tool instances and the bench loadout.
##
## Tools are owned as durability-tracked instances in `loop.owned_tools`. The
## bench shows at most MAX_WORKBENCH_TOOLS of them (5 — the workbench rack only fits
## five so it stays clear of the restoration table) (`loop.workbench_tools`, by uid)
## and one selected artifact (`loop.restore_target_uid`). Marketplace purchases and
## the starting kit grant instances through here; RestorationService wears them
## down as they are used.

const MAX_WORKBENCH_TOOLS: int = 5

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


## Adds an owned tool to the bench loadout. Returns false if the bench is full,
## the tool is not owned, or it is already loaded.
func add_to_workbench(uid: String) -> bool:
	var wb: Array = _game_state.save_state.loop.workbench_tools
	if wb.has(uid):
		return true
	if wb.size() >= MAX_WORKBENCH_TOOLS or not owns_uid(uid):
		return false
	wb.append(uid)
	return true


func remove_from_workbench(uid: String) -> void:
	_game_state.save_state.loop.workbench_tools.erase(uid)


## Places owned `uid` into bench `slot_index` (0-based). This is what a drag-and-drop
## onto a specific slot does:
##   * empty slot            → equip the tool there;
##   * slot held by another  → replace it (the displaced tool is unequipped);
##   * `uid` already equipped → swap the two positions so nothing else is disturbed.
## Only the one targeted slot changes — equipping a replacement never clears the rest
## of the bench. Slot indices are clamped to real slots, so a drop on a full bench
## always lands on (and replaces) an occupied slot. Returns false only if the tool
## isn't owned.
func equip_to_slot(uid: String, slot_index: int) -> bool:
	if not owns_uid(uid):
		return false
	var wb: Array = _game_state.save_state.loop.workbench_tools
	slot_index = clampi(slot_index, 0, MAX_WORKBENCH_TOOLS - 1)
	var from_index := wb.find(uid)
	if from_index == -1:
		# Equipping an owned tool that isn't on the bench yet.
		if slot_index < wb.size():
			wb[slot_index] = uid  # replace this slot's occupant (it drops off the bench)
		else:
			wb.append(uid)  # equip into the first free slot
		return true
	# Already equipped: reorder or swap within the bench (a trailing empty target
	# clamps to the last occupied slot, which just moves the tool there).
	var target := mini(slot_index, wb.size() - 1)
	if target == from_index:
		return true
	var displaced: Variant = wb[target]
	wb[target] = uid
	wb[from_index] = displaced
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
