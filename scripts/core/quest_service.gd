extends Node
## QuestService: tracks active, completed, and failed quests across loops.
##
## Persisted in SaveState.persistent so quest progress survives loop resets.
## Quests are authored in data/quests/*.json and loaded at boot.

const QUESTS_PATH := "res://data/quests/"

## All authored quest definitions loaded at boot: quest_id -> QuestDefinition.
var _quests: Dictionary = {}

## Active quests this loop: quest_id -> QuestInstance.
var _active: Dictionary = {}

## Runtime tracking of quest-essential item uids that must only be sold to a
## specific buyer. uid -> {quest_id, allowed_buyer}. Selling a tracked item to
## anyone else fails the quest (e.g. the salakot must go to Sam, never Mr. Maverick).
var _tracked_items: Dictionary = {}


func _ready() -> void:
	_load_quests()
	if not EventBus.sale_completed.is_connected(_on_sale_completed):
		EventBus.sale_completed.connect(_on_sale_completed)


func _load_quests() -> void:
	var dir := DirAccess.open(QUESTS_PATH)
	if dir == null:
		push_warning("QuestService: cannot open quests directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path := QUESTS_PATH + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var json: Variant = JSON.parse_string(file.get_as_text())
				if json is Dictionary and json.get("id") != null:
					var qd := QuestDefinition.from_dictionary(json)
					_quests[qd.id] = qd
				else:
					push_warning("QuestService: invalid quest file: " + path)
		file_name = dir.get_next()


# --- Public API ----------------------------------------------------------------


## Starts a quest by ID. No-op if already active or completed.
func start_quest(quest_id: String) -> void:
	if quest_id.is_empty() or not _quests.has(quest_id):
		push_warning("QuestService.start_quest: unknown quest '%s'" % quest_id)
		return
	if is_active(quest_id) or is_completed(quest_id):
		return
	var def: QuestDefinition = _quests[quest_id]
	_active[quest_id] = QuestInstance.new(quest_id)
	_set_persistent_progress(quest_id, "started")
	EventBus.emit_signal("quest_started", quest_id, def.display_name)


## Advances a quest to a new progress state. E.g. "found_glasses" for Alya Q1.
func advance_quest(quest_id: String, progress: String) -> void:
	if not is_active(quest_id):
		push_warning("QuestService.advance_quest: quest '%s' is not active" % quest_id)
		return
	var inst: QuestInstance = _active[quest_id]
	inst.progress = progress
	_set_persistent_progress(quest_id, progress)
	EventBus.emit_signal("quest_advanced", quest_id, progress)


## Completes a quest, moves it to persistent.completed_quests, and emits reward.
func complete_quest(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	var def: QuestDefinition = _quests.get(quest_id) as QuestDefinition
	var inst: QuestInstance = _active[quest_id]
	inst.completed = true
	_active.erase(quest_id)
	var p := GameState.save_state.persistent
	if not p.completed_quests.has(quest_id):
		p.completed_quests.append(quest_id)
	p.quest_progress[quest_id] = "completed"
	EventBus.emit_signal("quest_completed", quest_id, def.display_name if def != null else "")


## Fails a quest (e.g. sold the quest item to a wrong buyer). Removes from active.
func fail_quest(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	var inst: QuestInstance = _active[quest_id]
	inst.failed = true
	_active.erase(quest_id)
	GameState.save_state.persistent.quest_progress[quest_id] = "failed"
	EventBus.emit_signal("quest_failed", quest_id)


## Registers a quest-essential item instance that may only be sold to `allowed_buyer`.
## Selling it to any other buyer fails the quest (canon: mis-selling the salakot).
func track_quest_item(uid: String, quest_id: String, allowed_buyer: String) -> void:
	if uid.is_empty():
		return
	_tracked_items[uid] = {"quest_id": quest_id, "allowed_buyer": allowed_buyer}


## When a tracked quest item is sold, fail its quest unless the buyer was the one
## the quest requires. Sam's story buy-back never routes through the marketplace,
## so any sale_completed for the salakot means it went to the wrong buyer.
func _on_sale_completed(instance_id: String, buyer_id: String, _price: int) -> void:
	if not _tracked_items.has(instance_id):
		return
	var info: Dictionary = _tracked_items[instance_id]
	_tracked_items.erase(instance_id)
	var quest_id: String = str(info.get("quest_id", ""))
	var allowed_buyer: String = str(info.get("allowed_buyer", ""))
	if buyer_id != allowed_buyer and is_active(quest_id):
		fail_quest(quest_id)


## Unlocks a location so it can be travelled to. Persists across loops.
func unlock_location(location_id: String) -> void:
	var p := GameState.save_state.persistent
	if not p.unlocked_locations.has(location_id):
		p.unlocked_locations.append(location_id)
		EventBus.emit_signal("location_unlocked", location_id)


## Checks if a location is unlocked (including the base locations).
func is_location_unlocked(location_id: String) -> bool:
	var base_locations := ["shop", "yard", "mall"]  ## Always available.
	if location_id in base_locations:
		return true
	return GameState.save_state.persistent.unlocked_locations.has(location_id)


# --- Queries --------------------------------------------------------------------


func is_active(quest_id: String) -> bool:
	return _active.has(quest_id)


func is_completed(quest_id: String) -> bool:
	return GameState.save_state.persistent.completed_quests.has(quest_id)


func is_failed(quest_id: String) -> bool:
	var progress: String = str(GameState.save_state.persistent.quest_progress.get(quest_id, ""))
	return progress == "failed"


func get_progress(quest_id: String) -> String:
	if _active.has(quest_id):
		var inst: QuestInstance = _active[quest_id]
		return inst.progress
	return str(GameState.save_state.persistent.quest_progress.get(quest_id, ""))


func get_active_quests() -> Array[String]:
	var out: Array[String] = []
	for qid in _active.keys():
		out.append(qid)
	return out


func get_quest_definition(quest_id: String) -> QuestDefinition:
	return _quests.get(quest_id) as QuestDefinition


# --- Internal -------------------------------------------------------------------


func _set_persistent_progress(quest_id: String, progress: String) -> void:
	GameState.save_state.persistent.quest_progress[quest_id] = progress


# --- QuestDefinition ------------------------------------------------------------
class QuestDefinition:
	var id: String = ""
	var display_name: String = ""
	var description: String = ""
	var prerequisite_quests: Array[String] = []  ## Must complete these first.
	var prerequisite_locations: Array[String] = []  ## Must unlock these first.
	var prerequisite_day: int = 1  ## Earliest day this quest can start.
	var beats: Array = []  ## {id, day, summary, object_template}
	var rewards: Array = []  ## {type, value, id}
	var is_repeatable: bool = false  ## Can be redone in next loops?

	static func from_dictionary(data: Dictionary) -> QuestDefinition:
		var q := QuestDefinition.new()
		q.id = str(data.get("id", ""))
		q.display_name = str(data.get("display_name", ""))
		q.description = str(data.get("description", ""))
		q.prerequisite_quests = ModelUtils.as_string_array(data.get("prerequisite_quests"))
		q.prerequisite_locations = ModelUtils.as_string_array(data.get("prerequisite_locations"))
		q.prerequisite_day = int(data.get("prerequisite_day", 1))
		q.beats = SaveState._as_array(data.get("beats", []))
		q.rewards = SaveState._as_array(data.get("rewards", []))
		q.is_repeatable = bool(data.get("is_repeatable", false))
		return q


# --- QuestInstance --------------------------------------------------------------
class QuestInstance:
	var quest_id: String = ""
	var progress: String = "started"
	var completed: bool = false
	var failed: bool = false
	var day_started: int = 1

	func _init(id: String) -> void:
		quest_id = id
		day_started = GameState.save_state.loop.current_day if GameState.save_state != null else 1
