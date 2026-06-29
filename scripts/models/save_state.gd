class_name SaveState
## Top-level save contract.
##
## The save is split into persistent (Chronos-bound) and loop-scoped sections.
## See docs/phase-task.md "Save Contract" and PRD §5.

const CURRENT_SCHEMA_VERSION: int = 2

var schema_version: int = CURRENT_SCHEMA_VERSION
var player_id: String = "local-player"
## Run context. Persisted at the top level so loop reset never wipes the seed (SAVE-R1).
var run_seed: int = 0
var loop_index: int = 0
var persistent: PersistentState = PersistentState.new()
var loop: LoopState = LoopState.new()


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> SaveState:
	var s := SaveState.new()
	s.schema_version = ModelUtils.as_int(data.get("schema_version"))
	s.player_id = ModelUtils.as_string(data.get("player_id"), "local-player")
	s.run_seed = ModelUtils.as_int(data.get("run_seed"), 0)
	s.loop_index = ModelUtils.as_int(data.get("loop_index"), 0)
	if data.get("persistent") is Dictionary:
		s.persistent = PersistentState.from_dictionary(data["persistent"])
	if data.get("loop") is Dictionary:
		s.loop = LoopState.from_dictionary(data["loop"])
	return s


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"player_id": player_id,
		"run_seed": run_seed,
		"loop_index": loop_index,
		"persistent": persistent.to_dictionary(),
		"loop": loop.to_dictionary(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if schema_version != CURRENT_SCHEMA_VERSION:
		result.add_field_error(
			file_path,
			player_id,
			"schema_version",
			"unsupported schema version %d (expected %d)" % [schema_version, CURRENT_SCHEMA_VERSION]
		)
	if player_id.is_empty():
		result.add_field_error(file_path, player_id, "player_id", "player_id is required")
	if run_seed < 0:
		result.add_field_error(file_path, player_id, "run_seed", "run_seed must be non-negative")
	if loop_index < 0:
		result.add_field_error(
			file_path, player_id, "loop_index", "loop_index must be non-negative"
		)
	persistent.validate(result, file_path)
	loop.validate(result, file_path)
	return result


## Resets only loop-scoped state; persistent knowledge survives (SAVE-R1).
func reset_loop_state() -> void:
	loop = LoopState.new()


## ---------------------------------------------------------------------------
## PersistentState
## ---------------------------------------------------------------------------
class PersistentState:
	var journal_entries: Dictionary = {}  ## template_id -> JournalEntry.
	var techniques_learned: Array[String] = []
	var scanned_records: Dictionary = {}  ## template_id -> ScannedRecord.
	var museum_entries: Dictionary = {}  ## artifact_id -> MuseumEntry.
	var story_clues: Array[String] = []
	var dialogue_flags: Array[String] = []
	var route_completion: Dictionary = {}  ## route_id -> bool.
	var route_beats_completed: Array[String] = []  ## Completed beat ids (e.g. "auntie_beat_1").
	var fragments: Dictionary = {}  ## fragment_id -> Fragment.
	var legacy_items: Array[String] = []
	var leads: Array[String] = []
	var spawn_history: Dictionary = {}  ## fragment_id -> Array of placement logs.
	var neglect_history: Dictionary = {}  ## container_id -> int; recycled/ignored counts.
	var safe_code_known: bool = false
	var drawer_unlocked: bool = false
	var best_sale: Dictionary = {}  ## Best sale ever: {price, template_id, buyer_id, condition, day}.
	## Completed return-to-owner outcomes (DISP-R3/DISP-R6, persistent story state).
	## Each entry: {template_id, owner_route_id, reward_id, day}.
	var returns: Array = []
	## Upkeep knowledge the player has learned (e.g. a repair technique unlocked in the
	## evening). Persistent so it survives the loop reset (P14.6).
	var upkeep_learned: Array[String] = []

	static func from_dictionary(data: Dictionary) -> PersistentState:
		var p := PersistentState.new()
		p.journal_entries = SaveState._entry_dict(data.get("journal_entries", {}), JournalEntry)
		p.techniques_learned = ModelUtils.as_string_array(data.get("techniques_learned"))
		p.scanned_records = SaveState._entry_dict(data.get("scanned_records", {}), ScannedRecord)
		p.museum_entries = SaveState._entry_dict(data.get("museum_entries", {}), MuseumEntry)
		p.story_clues = ModelUtils.as_string_array(data.get("story_clues"))
		p.dialogue_flags = ModelUtils.as_string_array(data.get("dialogue_flags"))
		p.route_completion = data.get("route_completion", {}) as Dictionary
		p.route_beats_completed = ModelUtils.as_string_array(data.get("route_beats_completed"))
		p.fragments = SaveState._entry_dict(data.get("fragments", {}), Fragment)
		p.legacy_items = ModelUtils.as_string_array(data.get("legacy_items"))
		p.leads = ModelUtils.as_string_array(data.get("leads"))
		p.spawn_history = data.get("spawn_history", {}) as Dictionary
		p.neglect_history = data.get("neglect_history", {}) as Dictionary
		p.safe_code_known = ModelUtils.as_bool(data.get("safe_code_known"))
		p.drawer_unlocked = ModelUtils.as_bool(data.get("drawer_unlocked"))
		p.best_sale = ModelUtils.as_dictionary(data.get("best_sale"))
		p.returns = SaveState._as_array(data.get("returns", []))
		p.upkeep_learned = ModelUtils.as_string_array(data.get("upkeep_learned"))
		return p

	func to_dictionary() -> Dictionary:
		return {
			"journal_entries": SaveState._dict_to_raw(journal_entries),
			"techniques_learned": techniques_learned.duplicate(),
			"scanned_records": SaveState._dict_to_raw(scanned_records),
			"museum_entries": SaveState._dict_to_raw(museum_entries),
			"story_clues": story_clues.duplicate(),
			"dialogue_flags": dialogue_flags.duplicate(),
			"route_completion": route_completion.duplicate(),
			"route_beats_completed": route_beats_completed.duplicate(),
			"fragments": SaveState._dict_to_raw(fragments),
			"legacy_items": legacy_items.duplicate(),
			"leads": leads.duplicate(),
			"spawn_history": spawn_history.duplicate(),
			"neglect_history": neglect_history.duplicate(),
			"safe_code_known": safe_code_known,
			"drawer_unlocked": drawer_unlocked,
			"best_sale": best_sale.duplicate(true),
			"returns": returns.duplicate(true),
			"upkeep_learned": upkeep_learned.duplicate(),
		}

	func validate(result: ValidationResult, file_path: String) -> void:
		for template_id in journal_entries.keys():
			var entry: JournalEntry = journal_entries[template_id]
			entry.validate(result, file_path)
		for artifact_id in museum_entries.keys():
			var entry: MuseumEntry = museum_entries[artifact_id]
			entry.validate(result, file_path)
		for fragment_id in fragments.keys():
			var fragment: Fragment = fragments[fragment_id]
			fragment.validate(result, file_path)
		for template_id in scanned_records.keys():
			var record: ScannedRecord = scanned_records[template_id]
			record.validate(result, file_path)


## ---------------------------------------------------------------------------
## LoopState
## ---------------------------------------------------------------------------
class LoopState:
	var current_day: int = 1
	var current_hour: int = 7
	var current_minute: int = 0  ## Minute within the hour (0..59); resumes the saved moment.
	var money: int = 0
	var inventory: Array = []  ## ObjectInstance dictionaries.
	var tool_items: Array[String] = []  ## Owned non-legacy tool ids.
	var temp_upgrades: Array[String] = []
	var marketplace_listings: Array = []  ## Listing dictionaries.
	var pending_requests: Array = []  ## Request dictionaries.
	var day_event_outcomes: Dictionary = {}
	var current_delivery_ids: Array[String] = []
	var last_delivery_day: int = 0  ## Day on which the most recent Morning Delivery arrived.
	var current_carrier_placements: Dictionary = {}  ## fragment_id -> placement dict.
	var owned_tools: Array = []  ## ToolInstance dictionaries (durability-tracked, loop-scoped).
	var workbench_tools: Array[String] = []  ## Tool instance uids loaded into the bench (<= 5).
	var tool_shipments: Array = []  ## Pending purchases: {tool_id, arrival_index}.
	var restore_target_uid: String = ""  ## Instance selected to restore at the bench.
	var flashlight_on: bool = false  ## Phone flashlight state; loop-scoped, no battery.
	## Phase RV2-B scrap-foraging state. Reset on loop_reset; persistent knowledge untouched.
	var scrap_pool: Dictionary = {}  ## rarity_name -> count foraged this loop.
	## pending_sort = { "submitted": {}, "ready_index": int, "active": bool }.
	var pending_sort: Dictionary = {}
	## Pieces of scrap still scattered in the yard today. -1 means "not spawned yet".
	var yard_scrap_remaining: int = -1
	## Phase 18 mini-event state. All reset on loop_reset; persistent knowledge untouched.
	var event_active: Array = []  ## Active event states: {event_id, day, hour,
	## expires_hour, resolved}.
	var event_history: Array[String] = []  ## Event ids triggered this loop.
	var event_caps: Dictionary = {}  ## category -> count this loop.
	var event_outcomes: Array = []  ## Resolved outcomes for the future evening summary.
	## Phase 14 disposition + evening state. All loop-scoped: cleared on loop_reset.
	## Dispositions routed this loop (SELL/RETURN/PRESERVE/JOURNAL), for the evening
	## summary. Each entry: {uid, template_id, disposition, outcome_id, price, day}.
	var disposition_log: Array = []
	## Formal marketplace listings for restored items (P14.1). MarketplaceListing dicts.
	## (marketplace_listings above is the legacy field; listings is the typed model store.)
	var listings: Array = []
	## The committed next-day plan (P14.5 / EVE-R4): {plan_id, day, notes, prep}.
	var evening_plan: Dictionary = {}
	## Tool repair/replace upkeep performed this loop, for the summary. Each entry:
	## {action, tool_id, uid, cost, day}.
	var upkeep_actions: Array = []

	static func from_dictionary(data: Dictionary) -> LoopState:
		var l := LoopState.new()
		l.current_day = ModelUtils.as_int(data.get("current_day"), 1)
		l.current_hour = ModelUtils.as_int(data.get("current_hour"), 7)
		l.current_minute = ModelUtils.as_int(data.get("current_minute"), 0)
		l.money = ModelUtils.as_int(data.get("money"))
		l.inventory = SaveState._as_array(data.get("inventory", []))
		l.tool_items = ModelUtils.as_string_array(data.get("tool_items"))
		l.temp_upgrades = ModelUtils.as_string_array(data.get("temp_upgrades"))
		l.marketplace_listings = SaveState._as_array(data.get("marketplace_listings", []))
		l.pending_requests = SaveState._as_array(data.get("pending_requests", []))
		l.day_event_outcomes = data.get("day_event_outcomes", {}) as Dictionary
		l.current_delivery_ids = ModelUtils.as_string_array(data.get("current_delivery_ids"))
		l.last_delivery_day = ModelUtils.as_int(data.get("last_delivery_day"), 0)
		l.current_carrier_placements = data.get("current_carrier_placements", {}) as Dictionary
		l.owned_tools = SaveState._as_array(data.get("owned_tools", []))
		l.workbench_tools = ModelUtils.as_string_array(data.get("workbench_tools"))
		l.tool_shipments = SaveState._as_array(data.get("tool_shipments", []))
		l.restore_target_uid = ModelUtils.as_string(data.get("restore_target_uid"))
		l.flashlight_on = ModelUtils.as_bool(data.get("flashlight_on"))
		l.scrap_pool = ModelUtils.as_dictionary(data.get("scrap_pool"))
		l.pending_sort = ModelUtils.as_dictionary(data.get("pending_sort"))
		l.yard_scrap_remaining = ModelUtils.as_int(data.get("yard_scrap_remaining"), -1)
		l.event_active = SaveState._as_array(data.get("event_active", []))
		l.event_history = ModelUtils.as_string_array(data.get("event_history"))
		l.event_caps = data.get("event_caps", {}) as Dictionary
		l.event_outcomes = SaveState._as_array(data.get("event_outcomes", []))
		l.disposition_log = SaveState._as_array(data.get("disposition_log", []))
		l.listings = SaveState._as_array(data.get("listings", []))
		l.evening_plan = ModelUtils.as_dictionary(data.get("evening_plan"))
		l.upkeep_actions = SaveState._as_array(data.get("upkeep_actions", []))
		return l

	func to_dictionary() -> Dictionary:
		return {
			"current_day": current_day,
			"current_hour": current_hour,
			"current_minute": current_minute,
			"money": money,
			"inventory": inventory.duplicate(),
			"tool_items": tool_items.duplicate(),
			"temp_upgrades": temp_upgrades.duplicate(),
			"marketplace_listings": marketplace_listings.duplicate(),
			"pending_requests": pending_requests.duplicate(),
			"day_event_outcomes": day_event_outcomes.duplicate(),
			"current_delivery_ids": current_delivery_ids.duplicate(),
			"last_delivery_day": last_delivery_day,
			"current_carrier_placements": current_carrier_placements.duplicate(),
			"owned_tools": owned_tools.duplicate(),
			"workbench_tools": workbench_tools.duplicate(),
			"tool_shipments": tool_shipments.duplicate(),
			"restore_target_uid": restore_target_uid,
			"flashlight_on": flashlight_on,
			"scrap_pool": scrap_pool.duplicate(),
			"pending_sort": pending_sort.duplicate(true),
			"yard_scrap_remaining": yard_scrap_remaining,
			"event_active": event_active.duplicate(),
			"event_history": event_history.duplicate(),
			"event_caps": event_caps.duplicate(),
			"event_outcomes": event_outcomes.duplicate(),
			"disposition_log": disposition_log.duplicate(true),
			"listings": listings.duplicate(true),
			"evening_plan": evening_plan.duplicate(true),
			"upkeep_actions": upkeep_actions.duplicate(true),
		}

	func validate(result: ValidationResult, file_path: String) -> void:
		if current_day < 1 or current_day > 5:
			result.add_field_error(file_path, "", "loop.current_day", "current_day must be 1..5")
		if current_hour < 0 or current_hour > 23:
			result.add_field_error(file_path, "", "loop.current_hour", "current_hour must be 0..23")
		if current_minute < 0 or current_minute > 59:
			result.add_field_error(
				file_path, "", "loop.current_minute", "current_minute must be 0..59"
			)
		if money < 0:
			result.add_field_error(file_path, "", "loop.money", "money must be non-negative")


## ---------------------------------------------------------------------------
## Helpers for nested model dictionaries.
## ---------------------------------------------------------------------------
static func _entry_dict(raw: Variant, model_class: GDScript) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key in raw.keys():
			var value = raw[key]
			if value is Dictionary:
				out[key] = model_class.call("from_dictionary", value)
	return out


static func _dict_to_raw(dict: Dictionary) -> Dictionary:
	var out := {}
	for key in dict.keys():
		var value = dict[key]
		if value != null and value.has_method("to_dictionary"):
			out[key] = value.to_dictionary()
		else:
			out[key] = value
	return out


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate()
	return []
