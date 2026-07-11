class_name QuestTracker
extends PanelContainer
## Node-based quest tracker. Lists the player's active quests (title + current
## objective) as child QuestEntry nodes, driven entirely by QuestService and the
## EventBus quest signals. Authoring a new quest in data makes it appear here with no
## UI code changes. Hidden while there are no active quests.
##
## The header is a Button that collapses/expands the list with a short fade; the
## state (collapsed vs expanded) is remembered for the tracker's lifetime. The list
## lives in a capped ScrollContainer so the panel never grows past the screen or
## overlaps lower UI, no matter how many quests are active.

const QUEST_ENTRY_SCENE := preload("res://scenes/ui/quest_entry.tscn")

## Seconds for the collapse/expand fade.
const COLLAPSE_DURATION := 0.25

@onready var _header: Button = $Margin/VBox/Header
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _entries: VBoxContainer = $Margin/VBox/Scroll/Entries

## Persisted for the tracker's lifetime (it is freed with its host scene).
var _collapsed := false


func _ready() -> void:
	_header.pressed.connect(_on_toggle)
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
	# A quest event must not force the list open while the player has it collapsed.
	_apply_collapse(false)


## Toggles the entries list; the header glyph mirrors the expanded/collapsed state.
func _on_toggle() -> void:
	_collapsed = not _collapsed
	_apply_collapse(true)


## Applies `_collapsed`, optionally with a short fade. The PanelContainer reflows its
## height for free as the scroll area is shown/hidden.
func _apply_collapse(animated: bool) -> void:
	if _scroll == null or _header == null:
		return
	_header.text = "▶ Quests" if _collapsed else "▼ Quests"
	if not animated:
		_scroll.visible = not _collapsed
		_scroll.modulate.a = 0.0 if _collapsed else 1.0
		return
	if _collapsed:
		var tween := UiAnimations.fade_to(_scroll, 0.0, COLLAPSE_DURATION)
		tween.finished.connect(_on_collapse_faded)
	else:
		_scroll.visible = true
		_scroll.modulate.a = 0.0
		UiAnimations.fade_to(_scroll, 1.0, COLLAPSE_DURATION)


## Hides the scroll area once its collapse fade finishes. Guarded so a quick re-expand
## (which flips `_collapsed` back) never hides a freshly-shown list.
func _on_collapse_faded() -> void:
	if is_instance_valid(_scroll) and _collapsed:
		_scroll.visible = false
