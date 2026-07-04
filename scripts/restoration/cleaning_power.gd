class_name CleaningPower
## Resolves how strongly a tool cleans a surface condition.
##
## "Power" is how much a single tool stroke removes from a condition's dirt level
## (0..255 scale; see ArtifactConditionDecal). A tool can clean several conditions,
## each at its own power, authored as `cleans: {condition_id: power}` on the tool.
## When a tool has no authored `cleans`, its power is derived from the journal
## catalog: it cleans the condition whose `cleaning_tool` is this tool, at
## DEFAULT_POWER. Power 0 means "wrong tool — does nothing".

const DEFAULT_POWER: int = 60

## Max cleaning power on the 0..255 dirt scale; the debug eraser cleans anything at full power.
const UNIVERSAL_POWER: int = 255

## A tool whose `enables` lists this interaction is the debug "universal cleaner": it removes
## ANY surface condition (authored overlay, data decal, or dirt mask) regardless of the
## condition's required tool. Data-driven so the engine stays artifact-agnostic.
const DEBUG_ERASE_ENABLE: String = "debug_erase"


## True when the tool is the debug universal cleaner (erases any condition).
static func is_universal_cleaner(repo: DataRepository, tool_id: String) -> bool:
	if repo == null or tool_id.is_empty():
		return false
	var tool := repo.get_tool(tool_id)
	return tool != null and tool.enables.has(DEBUG_ERASE_ENABLE)


## The power `tool_id` has against `condition_id` (0 = can't clean it).
static func power(repo: DataRepository, tool_id: String, condition_id: String) -> int:
	if repo == null or tool_id.is_empty() or condition_id.is_empty():
		return 0
	if is_universal_cleaner(repo, tool_id):
		return UNIVERSAL_POWER  # the debug eraser cleans every condition
	var tool := repo.get_tool(tool_id)
	if tool != null and not tool.cleans.is_empty():
		return maxi(0, int(tool.cleans.get(condition_id, 0)))
	var condition := repo.get_surface_condition(condition_id)
	if condition != null and condition.cleaning_tool == tool_id:
		return DEFAULT_POWER
	return 0


## The conditions a tool can fix, for the tool-tray UI. Returns an array of
## {id, display_name, color, power} sorted by id.
static func conditions_for(repo: DataRepository, tool_id: String) -> Array:
	var out: Array = []
	if repo == null:
		return out
	# The debug eraser lists EVERY known condition (it cleans them all).
	if is_universal_cleaner(repo, tool_id):
		for raw in repo.get_surface_conditions_sorted():
			var cond := raw as SurfaceCondition
			if cond != null:
				out.append(_entry(cond.id, cond, UNIVERSAL_POWER))
		return out
	var tool := repo.get_tool(tool_id)
	if tool != null and not tool.cleans.is_empty():
		var ids := tool.cleans.keys()
		ids.sort()
		for cid in ids:
			var condition := repo.get_surface_condition(cid)
			out.append(_entry(cid, condition, int(tool.cleans[cid])))
		return out
	for raw in repo.get_surface_conditions_sorted():
		var condition := raw as SurfaceCondition
		if condition != null and condition.cleaning_tool == tool_id:
			out.append(_entry(condition.id, condition, DEFAULT_POWER))
	return out


static func _entry(id: String, condition: SurfaceCondition, value: int) -> Dictionary:
	return {
		"id": id,
		"display_name": condition.display_name if condition != null else id,
		"color": condition.to_color() if condition != null else Color.WHITE,
		"power": value,
	}
