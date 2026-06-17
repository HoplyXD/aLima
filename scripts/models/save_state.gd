class_name SaveState
## Top-level save contract.
##
## The save is split into persistent (Chronos-bound) and loop-scoped sections.
## See docs/phase-task.md "Save Contract" and PRD §5.

const CURRENT_SCHEMA_VERSION: int = 1

var schema_version: int = CURRENT_SCHEMA_VERSION
var player_id: String = "local-player"
var persistent: PersistentState = PersistentState.new()
var loop: LoopState = LoopState.new()


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> SaveState:
	var s := SaveState.new()
	s.schema_version = ModelUtils.as_int(data.get("schema_version"))
	s.player_id = ModelUtils.as_string(data.get("player_id"), "local-player")
	if data.get("persistent") is Dictionary:
		s.persistent = PersistentState.from_dictionary(data["persistent"])
	if data.get("loop") is Dictionary:
		s.loop = LoopState.from_dictionary(data["loop"])
	return s


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"player_id": player_id,
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
	var fragments: Dictionary = {}  ## fragment_id -> Fragment.
	var legacy_items: Array[String] = []
	var leads: Array[String] = []
	var spawn_history: Dictionary = {}  ## fragment_id -> Array of placement logs.
	var neglect_history: Dictionary = {}  ## container_id -> int; recycled/ignored counts.
	var safe_code_known: bool = false
	var drawer_unlocked: bool = false

	static func from_dictionary(data: Dictionary) -> PersistentState:
		var p := PersistentState.new()
		p.journal_entries = SaveState._entry_dict(data.get("journal_entries", {}), JournalEntry)
		p.techniques_learned = ModelUtils.as_string_array(data.get("techniques_learned"))
		p.scanned_records = SaveState._entry_dict(data.get("scanned_records", {}), ScannedRecord)
		p.museum_entries = SaveState._entry_dict(data.get("museum_entries", {}), MuseumEntry)
		p.story_clues = ModelUtils.as_string_array(data.get("story_clues"))
		p.dialogue_flags = ModelUtils.as_string_array(data.get("dialogue_flags"))
		p.route_completion = data.get("route_completion", {}) as Dictionary
		p.fragments = SaveState._entry_dict(data.get("fragments", {}), Fragment)
		p.legacy_items = ModelUtils.as_string_array(data.get("legacy_items"))
		p.leads = ModelUtils.as_string_array(data.get("leads"))
		p.spawn_history = data.get("spawn_history", {}) as Dictionary
		p.neglect_history = data.get("neglect_history", {}) as Dictionary
		p.safe_code_known = ModelUtils.as_bool(data.get("safe_code_known"))
		p.drawer_unlocked = ModelUtils.as_bool(data.get("drawer_unlocked"))
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
			"fragments": SaveState._dict_to_raw(fragments),
			"legacy_items": legacy_items.duplicate(),
			"leads": leads.duplicate(),
			"spawn_history": spawn_history.duplicate(),
			"neglect_history": neglect_history.duplicate(),
			"safe_code_known": safe_code_known,
			"drawer_unlocked": drawer_unlocked,
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
	var workbench_tools: Array[String] = []  ## Tool instance uids loaded into the bench (<= 10).
	var tool_shipments: Array = []  ## Pending purchases: {tool_id, arrival_index}.
	var restore_target_uid: String = ""  ## Instance selected to restore at the bench.

	static func from_dictionary(data: Dictionary) -> LoopState:
		var l := LoopState.new()
		l.current_day = ModelUtils.as_int(data.get("current_day"), 1)
		l.current_hour = ModelUtils.as_int(data.get("current_hour"), 7)
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
		return l

	func to_dictionary() -> Dictionary:
		return {
			"current_day": current_day,
			"current_hour": current_hour,
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
		}

	func validate(result: ValidationResult, file_path: String) -> void:
		if current_day < 1 or current_day > 5:
			result.add_field_error(file_path, "", "loop.current_day", "current_day must be 1..5")
		if current_hour < 0 or current_hour > 23:
			result.add_field_error(file_path, "", "loop.current_hour", "current_hour must be 0..23")
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
