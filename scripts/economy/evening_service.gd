extends Node
## The mandatory end-of-day evening state (P14.5, EVE-R1..R5, CLAUDE.md §4-N).
## Registered as the `EveningService` autoload.
##
## Every shop day ends through an explicit evening before the day advances. The
## evening summarises the day's outcomes, exposes tool repair/replace upkeep and
## storage resolution, lets the player review journal changes and commit a next-day
## plan, then advances the day (or performs the Day 5 loop reset) on commit.
##
## Integration with day-close: LoopController calls handle_day_close() at the 20:00
## boundary. In interactive mode (the live game sets `interactive = true`) the
## evening takes over advancement — LoopController does NOT advance; commit_plan()
## advances once the player is done. In non-interactive mode (headless/tests by
## default) handle_day_close() returns false and LoopController advances exactly as
## before, so existing clock/loop behaviour is unchanged. Evening plan/upkeep state
## is loop-scoped and cleared on the loop reset; learned upkeep persists (P14.6).

## When true, the evening pauses day advancement until commit_plan(). The live Shop
## sets this on ready; tests opt in explicitly.
var interactive: bool = false

var _pending_day: int = -1  ## Day awaiting evening commitment; -1 when idle.
var _summary: Dictionary = {}


func _ready() -> void:
	EventBus.loop_reset.connect(_on_loop_reset)


# --- Day-close handoff --------------------------------------------------------


## Called by LoopController at the 20:00 close. Returns true when the evening takes
## over advancement (interactive mode), in which case LoopController must not advance
## — commit_plan() will. Returns false otherwise so advancement is unchanged.
func handle_day_close(day: int) -> bool:
	if not interactive:
		return false
	if _pending_day != -1:
		# Already in an evening; swallow a duplicate close so advancement runs once.
		return true
	_pending_day = day
	_summary = build_summary(day)
	EventBus.evening_started.emit(day)
	return true


func is_in_evening() -> bool:
	return _pending_day != -1


func pending_day() -> int:
	return _pending_day


func get_summary() -> Dictionary:
	return _summary


# --- Summary (EVE-R2) ---------------------------------------------------------


## Builds the evening summary for `day`: money, the day's dispositions, route/event
## outcomes, journal/fragment progress, tools needing upkeep, and storage status.
func build_summary(day: int) -> Dictionary:
	var loop := GameState.save_state.loop
	var sales := 0
	var returns := 0
	var preserved := 0
	var journaled := 0
	var sale_total := 0
	for raw in loop.disposition_log:
		if not (raw is Dictionary) or ModelUtils.as_int(raw.get("day")) != day:
			continue
		match ModelUtils.as_string(raw.get("disposition")):
			"SELL":
				sales += 1
				sale_total += ModelUtils.as_int(raw.get("price"))
			"RETURN":
				returns += 1
			"PRESERVE":
				preserved += 1
			"JOURNAL":
				journaled += 1
	return {
		"day": day,
		"money": loop.money,
		"sales": sales,
		"sale_total": sale_total,
		"returns": returns,
		"preserved": preserved,
		"journaled": journaled,
		"event_outcomes": loop.event_outcomes.size(),
		"journal_entries": GameState.save_state.persistent.journal_entries.size(),
		"fragments_seated": _count_seated_fragments(),
		"tools_needing_upkeep": tools_needing_upkeep().size(),
		"storage": storage_status(),
	}


func _count_seated_fragments() -> int:
	var count := 0
	for fragment_id in GameState.save_state.persistent.fragments.keys():
		var fragment: Fragment = GameState.save_state.persistent.fragments[fragment_id]
		if fragment.state == ModelEnums.FragmentState.SEATED:
			count += 1
	return count


# --- Upkeep: tool repair / replace (EVE-R3) ----------------------------------


## Finite owned tools that are worn (below full durability) or broken, as
## ToolInstances. Infinite (legacy/basic) tools never appear.
func tools_needing_upkeep() -> Array[ToolInstance]:
	var out: Array[ToolInstance] = []
	for raw in GameState.save_state.loop.owned_tools:
		if not (raw is Dictionary):
			continue
		var inst := ToolInstance.from_dictionary(raw)
		if not inst.is_infinite() and inst.durability < inst.max_durability:
			out.append(inst)
	return out


## Pesos to repair a tool back to full durability. 0 when the tool is infinite, full,
## or unknown.
func repair_cost(uid: String) -> int:
	var inst := _find_owned(uid)
	if inst == null or inst.is_infinite() or inst.durability >= inst.max_durability:
		return 0
	var cfg := DataRepository.singleton().get_evening_config()
	var per_point := ModelUtils.as_int(cfg.get("repair_cost_per_point"), 2)
	var minimum := ModelUtils.as_int(cfg.get("min_repair_cost"), 5)
	var missing := inst.max_durability - inst.durability
	return maxi(minimum, per_point * missing)


## Repairs a tool to full durability for repair_cost(). Returns {ok, error, cost}.
func repair_tool(uid: String) -> Dictionary:
	var inst := _find_owned(uid)
	if inst == null:
		return {"ok": false, "error": "No such tool.", "cost": 0}
	if inst.is_infinite() or inst.durability >= inst.max_durability:
		return {"ok": false, "error": "That tool does not need repair.", "cost": 0}
	var cost := repair_cost(uid)
	if GameState.save_state.loop.money < cost:
		return {"ok": false, "error": "Not enough money to repair.", "cost": cost}
	GameState.save_state.loop.money -= cost
	_set_owned_durability(uid, inst.max_durability)
	_log_upkeep("repair", inst.tool_id, uid, cost)
	SaveService.save_game()
	return {"ok": true, "error": "", "cost": cost}


## Pesos to replace a tool with a fresh instance: its catalog cost, else the config
## fallback.
func replace_cost(uid: String) -> int:
	var inst := _find_owned(uid)
	if inst == null:
		return 0
	var cfg := DataRepository.singleton().get_evening_config()
	var fallback := ModelUtils.as_int(cfg.get("replace_cost_fallback"), 30)
	var def := DataRepository.singleton().get_tool(inst.tool_id)
	if def != null and def.cost > 0:
		return def.cost
	return fallback


## Replaces a (typically broken) tool with a fresh full-durability instance. Removes
## the old instance + its bench slot and grants a new one. Returns {ok, error, cost}.
func replace_tool(uid: String) -> Dictionary:
	var inst := _find_owned(uid)
	if inst == null:
		return {"ok": false, "error": "No such tool.", "cost": 0}
	var cost := replace_cost(uid)
	if GameState.save_state.loop.money < cost:
		return {"ok": false, "error": "Not enough money to replace.", "cost": cost}
	GameState.save_state.loop.money -= cost
	var tool_id := inst.tool_id
	_remove_owned(uid)
	var tools := ToolService.new(GameState, DataRepository.singleton())
	var fresh := tools.grant_tool(tool_id)
	_log_upkeep("replace", tool_id, fresh.uid, cost)
	SaveService.save_game()
	return {"ok": true, "error": "", "cost": cost}


# --- Storage resolution (EVE-R3) ---------------------------------------------


## {used, cap, over}: total storage cost of loop inventory vs the configured cap.
func storage_status() -> Dictionary:
	var repo := DataRepository.singleton()
	var used := 0
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		used += maxi(1, inst.storage_cost)
	var cap := ModelUtils.as_int(repo.get_evening_config().get("storage_cap"), 12)
	return {"used": used, "cap": cap, "over": maxi(0, used - cap)}


## Resolves storage overage by recycling the lowest-value inventory items until the
## storage cost is within the cap. Returns the number recycled. Loop-scoped.
func resolve_storage_overage() -> int:
	var status := storage_status()
	var over := ModelUtils.as_int(status.get("over"))
	if over <= 0:
		return 0
	var entries: Array = GameState.save_state.loop.inventory.duplicate()
	entries.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			return _instance_value(a) < _instance_value(b)
	)
	var recycled := 0
	for raw in entries:
		if over <= 0:
			break
		var inst := ObjectInstance.from_dictionary(raw)
		if inst.is_carrier:
			continue  # never auto-recycle a carrier
		_remove_inventory(inst.uid)
		over -= maxi(1, inst.storage_cost)
		recycled += 1
	if recycled > 0:
		SaveService.save_game()
	return recycled


# --- Plan commit (EVE-R4 / EVE-R5) -------------------------------------------


## Commits the next-day plan, saves atomically, then advances the day (or performs
## the Day 5 loop reset). Idempotent: a second call while idle is a no-op so repeated
## input cannot double-advance. Returns {ok, error, day}.
func commit_plan(plan_id: String = "", notes: String = "") -> Dictionary:
	if _pending_day == -1:
		return {"ok": false, "error": "No evening is in progress.", "day": -1}
	var day := _pending_day
	GameState.save_state.loop.evening_plan = {
		"plan_id": plan_id,
		"day": day,
		"notes": notes,
	}
	var save_result := SaveService.save_game()
	if not save_result.ok:
		return {"ok": false, "error": ModelUtils.as_string(save_result.get("error")), "day": day}
	EventBus.evening_plan_committed.emit(day, plan_id)
	_pending_day = -1
	_summary = {}
	# Advance after the plan is committed and saved (EVE-R5).
	LoopController.advance_day_or_reset(day)
	return {"ok": true, "error": "", "day": day}


func _on_loop_reset(_loop_index: int) -> void:
	_pending_day = -1
	_summary = {}


# --- Internals ----------------------------------------------------------------


func _instance_value(raw: Variant) -> int:
	if not (raw is Dictionary):
		return 0
	var inst := ObjectInstance.from_dictionary(raw)
	if inst.value > 0:
		return inst.value
	var template := DataRepository.singleton().get_template(inst.template_id)
	if template == null:
		return 0
	return int(round((template.base_value_range.x + template.base_value_range.y) / 2.0))


func _find_owned(uid: String) -> ToolInstance:
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == uid:
			return ToolInstance.from_dictionary(raw)
	return null


func _set_owned_durability(uid: String, value: int) -> void:
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == uid:
			raw["durability"] = value
			return


func _remove_owned(uid: String) -> void:
	var kept: Array = []
	for raw in GameState.save_state.loop.owned_tools:
		if not (raw is Dictionary and raw.get("uid") == uid):
			kept.append(raw)
	GameState.save_state.loop.owned_tools = kept
	var wb: Array = GameState.save_state.loop.workbench_tools
	var idx := wb.find(uid)
	if idx != -1:
		wb.remove_at(idx)


func _remove_inventory(uid: String) -> void:
	var kept: Array = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary and raw.get("uid") == uid):
			kept.append(raw)
	GameState.save_state.loop.inventory = kept


func _log_upkeep(action: String, tool_id: String, uid: String, cost: int) -> void:
	GameState.save_state.loop.upkeep_actions.append(
		{
			"action": action,
			"tool_id": tool_id,
			"uid": uid,
			"cost": cost,
			"day": GameState.save_state.loop.current_day,
		}
	)
