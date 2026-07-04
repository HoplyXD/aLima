extends GutTest
## Smoke + behaviour tests for the node-based Quest UI (quest_tracker.tscn /
## quest_entry.tscn) and the QuestService.current_objective helper that drives it.


func test_quest_entry_scene_instances_as_node() -> void:
	var entry: QuestEntry = load("res://scenes/ui/quest_entry.tscn").instantiate()
	add_child_autofree(entry)
	entry.set_quest("Test Quest", "Do the thing")
	assert_true(entry is QuestEntry, "entry root is a QuestEntry node")


func test_quest_tracker_scene_instances_and_hides_when_no_active() -> void:
	var tracker: QuestTracker = load("res://scenes/ui/quest_tracker.tscn").instantiate()
	add_child_autofree(tracker)
	tracker.refresh()
	assert_true(tracker is QuestTracker, "tracker root is a QuestTracker node")
	if QuestService.get_active_quests().is_empty():
		assert_false(tracker.visible, "tracker hides itself when there are no active quests")


func test_current_objective_empty_for_unknown_quest() -> void:
	assert_eq(QuestService.current_objective("no_such_quest"), "")


func test_current_objective_falls_back_to_description_when_no_beat_matches() -> void:
	var def := QuestService.get_quest_definition("alya_quest_line")
	if def == null:
		pass_test("alya_quest_line not authored in this environment")
		return
	# Not started -> progress "" matches no beat id -> objective is the quest description.
	assert_eq(QuestService.current_objective("alya_quest_line"), def.description)
