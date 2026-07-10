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


func _on_quest_changed(_a: Variant = null, _b: Variant = null) -> void:
	refresh()


## Rebuilds the entry rows from QuestService's active quests. Public so a host scene
## can force a refresh (e.g. after loading a save).
func refresh() -> void:
	if _entries == null:
		return
	for child in _entries.get_children():
		child.queue_free()
	var active := QuestService.get_active_quests()
	visible = not active.is_empty()
	for quest_id in active:
		var def := QuestService.get_quest_definition(quest_id)
		if def == null:
			continue
		var entry: QuestEntry = QUEST_ENTRY_SCENE.instantiate()
		_entries.add_child(entry)
		entry.set_quest(def.display_name, QuestService.current_objective(quest_id))
