class_name StorageScreen
extends CanvasLayer
## Storage: prepare the workbench. Three tabs:
##   * Artifacts  — ordinary restorable inventory; pick which one to restore next.
##   * Tools      — owned tools; choose up to 10 to load into the bench.
##   * Key Items  — quest artifacts (route-given pieces) and the five fragments.
##
## Presentation only. Loadout/restore-target rules live in ToolService; fragment
## and inventory state are read from GameState. UI is built in code so the scene
## file stays trivial.

signal closed

var _owns_pause: bool = false
var _tools: ToolService

@onready var _artifacts_list: VBoxContainer = %ArtifactsList
@onready var _tools_list: VBoxContainer = %ToolsList
@onready var _keyitems_list: VBoxContainer = %KeyItemsList
@onready var _status_label: Label = %StatusLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_tools = ToolService.new()
	_close_button.pressed.connect(close)


func open() -> void:
	if not visible:
		visible = true
		if not _owns_pause:
			DayClock.request_pause(DayClock.PAUSE_STORAGE)
			_owns_pause = true
	refresh()
	_close_button.grab_focus()


func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_STORAGE):
		DayClock.release_pause(DayClock.PAUSE_STORAGE)
	_owns_pause = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Player actions (also test seams) ----------------------------------------


## Chooses which artifact to restore next at the bench.
func select_artifact(uid: String) -> void:
	_tools.set_restore_target(uid)
	SaveService.save_game()
	refresh()


## Loads/unloads an owned tool from the bench (max 10).
func toggle_tool(uid: String) -> void:
	if GameState.save_state.loop.workbench_tools.has(uid):
		_tools.remove_from_workbench(uid)
	else:
		if not _tools.add_to_workbench(uid):
			_status_label.text = "The bench is full (%d tools)." % ToolService.MAX_WORKBENCH_TOOLS
			return
	SaveService.save_game()
	refresh()


func owns_pause() -> bool:
	return _owns_pause


# --- Rendering ---------------------------------------------------------------


func refresh() -> void:
	_clear(_artifacts_list)
	_clear(_tools_list)
	_clear(_keyitems_list)
	_render_artifacts()
	_render_tools()
	_render_key_items()
	var loaded: int = GameState.save_state.loop.workbench_tools.size()
	var target := _tools.get_restore_target()
	var target_name := _instance_display_name(target) if not target.is_empty() else "nothing"
	_status_label.text = (
		"Bench: %d / %d tools · Restoring: %s" % [loaded, ToolService.MAX_WORKBENCH_TOOLS, target_name]
	)


func _render_artifacts() -> void:
	var repo := DataRepository.singleton()
	var target := _tools.get_restore_target()
	var any := false
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		var template := repo.get_template(inst.template_id)
		if template == null or not template.deliverable:
			continue  # quest-given items live under Key Items.
		any = true
		_artifacts_list.add_child(_make_artifact_row(inst, template, target == inst.uid))
	if not any:
		_artifacts_list.add_child(_make_note("No restorable artifacts in storage yet."))


func _render_tools() -> void:
	var owned := _tools.get_owned_tools()
	if owned.is_empty():
		_tools_list.add_child(_make_note("No tools owned. Buy some from the phone Marketplace."))
		return
	for inst in owned:
		_tools_list.add_child(_make_tool_row(inst))


func _render_key_items() -> void:
	var repo := DataRepository.singleton()

	# Quest artifacts: quest-given (non-deliverable) inventory objects.
	var quest_any := false
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		var template := repo.get_template(inst.template_id)
		if template == null or template.deliverable:
			continue
		if not quest_any:
			_keyitems_list.add_child(_make_header("Quest Artifacts"))
			quest_any = true
		var target := _tools.get_restore_target()
		_keyitems_list.add_child(_make_artifact_row(inst, template, target == inst.uid))
	if not quest_any:
		_keyitems_list.add_child(_make_note("No quest artifacts in hand."))

	# Fragments: the five pieces and their lifecycle state.
	_keyitems_list.add_child(_make_header("Fragments"))
	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if fragments.is_empty():
		_keyitems_list.add_child(_make_note("No fragments tracked yet."))
		return
	var seated := 0
	for fragment_id in fragments.keys():
		var fragment: Fragment = fragments[fragment_id]
		var state := ModelEnums.fragment_state_name(fragment.state).capitalize()
		if fragment.state == ModelEnums.FragmentState.SEATED:
			seated += 1
		_keyitems_list.add_child(
			_make_note("• Slot %d — %s (%s)" % [fragment.case_slot_index + 1, fragment_id, state])
		)
	_keyitems_list.add_child(_make_note("%d / 5 fragments seated." % seated))


func _make_artifact_row(inst: ObjectInstance, template: ScrapObjectTemplate, selected: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	var state := ModelEnums.obj_state_name(inst.state).capitalize()
	label.text = "%s — %s" % [template.display_name, state]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var button := Button.new()
	button.text = "Restoring" if selected else "Restore this"
	button.disabled = selected
	button.focus_mode = Control.FOCUS_ALL
	var uid := inst.uid
	button.pressed.connect(func() -> void: select_artifact(uid))
	row.add_child(button)
	return row


func _make_tool_row(inst: ToolInstance) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var def := DataRepository.singleton().get_tool(inst.tool_id)
	var name := def.display_name if def != null else inst.tool_id
	var wear := "∞" if inst.is_infinite() else "%d/%d" % [inst.durability, inst.max_durability]
	var loaded: bool = GameState.save_state.loop.workbench_tools.has(inst.uid)
	var label := Label.new()
	label.text = "%s  (%s uses)%s" % [name, wear, "  · in bench" if loaded else ""]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var button := Button.new()
	button.text = "Remove" if loaded else "Add to bench"
	button.focus_mode = Control.FOCUS_ALL
	var uid := inst.uid
	button.pressed.connect(func() -> void: toggle_tool(uid))
	row.add_child(button)
	return row


func _instance_display_name(uid: String) -> String:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			var template := DataRepository.singleton().get_template(
				ModelUtils.as_string(raw.get("template_id"))
			)
			return template.display_name if template != null else uid
	return uid


# --- UI construction ---------------------------------------------------------


func _make_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	return label


func _make_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.7))
	return label


func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()
