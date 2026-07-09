class_name QuestTracker
extends PanelContainer
## Node-based quest tracker. Lists the player's active quests (title + current
## objective) as child QuestEntry nodes, driven entirely by QuestService and the
## EventBus quest signals. Authoring a new quest in data makes it appear here with no
## UI code changes. Hidden while there are no active quests.

const QUEST_ENTRY_SCENE := preload("res://scenes/ui/quest_entry.tscn")

@onready var _entries: VBoxContainer = $Margin/VBox/Entries


func _ready() -> void:
	_connect_signals()
	refresh()


func _connect_signals() -> void:
	if not EventBus.quest_started.is_connected(_on_quest_changed):
		EventBus.quest_started.connect(_on_quest_changed)
	if not EventBus.quest_advanced.is_connected(_on_quest_changed):
		EventBus.quest_advanced.connect(_on_quest_changed)
	if not EventBus.quest_completed.is_connected(_on_quest_changed):
		EventBus.quest_completed.connect(_on_quest_changed)
	if not EventBus.quest_failed.is_connected(_on_quest_changed):
		EventBus.quest_failed.connect(_on_quest_changed)
	if not QuestService.tracked_quest_changed.is_connected(_on_tracked_changed):
		QuestService.tracked_quest_changed.connect(_on_tracked_changed)
	_ensure_cycle_action()


func _on_quest_changed(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


func _on_tracked_changed(_quest_id: String) -> void:
	refresh()


## Q cycles the tracked quest target — usable outside where there is no mouse.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_quest"):
		QuestService.cycle_tracked_quest()
		get_viewport().set_input_as_handled()


func _ensure_cycle_action() -> void:
	if InputMap.has_action("cycle_quest"):
		return
	InputMap.add_action("cycle_quest")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event("cycle_quest", key)


## Rebuilds the entry rows from QuestService's active quests. Public so a host scene
## can force a refresh (e.g. after loading a save). The tracked target row reads
## gold with a ➤ marker; clicking any row re-targets it.
func refresh() -> void:
	if _entries == null:
		return
	for child in _entries.get_children():
		child.queue_free()
	var active := QuestService.get_active_quests()
	visible = not active.is_empty()
	var tracked := QuestService.tracked_quest()
	for quest_id in active:
		var def := QuestService.get_quest_definition(quest_id)
		if def == null:
			continue
		var entry: QuestEntry = QUEST_ENTRY_SCENE.instantiate()
		_entries.add_child(entry)
		entry.quest_id = quest_id
		entry.set_tracked(quest_id == tracked)
		entry.set_quest(def.display_name, QuestService.current_objective(quest_id))
		entry.clicked.connect(QuestService.set_tracked_quest)
