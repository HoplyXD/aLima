class_name RestorationScreen
extends CanvasLayer
## Full-screen 2D restoration interface.
##
## Lets the player select a restorable instance, choose an owned tool, and apply
## deliberate cleaning actions. The interface is driven entirely by
## RestorationService so it owns no business logic and does not touch SaveService.

signal closed  ## Emitted after the screen is dismissed.

var _service: RestorationService
var _selected_uid: String = ""
var _selected_tool_id: String = ""

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _item_list: ItemList = $Panel/Margin/VBox/Body/Left/ItemList
@onready var _detail_name: Label = $Panel/Margin/VBox/Body/Right/Name
@onready var _detail_state: Label = $Panel/Margin/VBox/Body/Right/State
@onready var _condition_label: Label = $Panel/Margin/VBox/Body/Right/Condition
@onready var _value_label: Label = $Panel/Margin/VBox/Body/Right/Value
@onready var _damage_label: Label = $Panel/Margin/VBox/Body/Right/Damage
@onready var _selected_tool_label: Label = $Panel/Margin/VBox/Body/Right/SelectedTool
@onready var _tool_container: HBoxContainer = $Panel/Margin/VBox/Body/Right/Tools
@onready var _clean_area: Button = $Panel/Margin/VBox/Body/Right/CleanArea
@onready var _open_button: Button = $Panel/Margin/VBox/Body/Right/OpenButton
@onready var _feedback_label: Label = $Panel/Margin/VBox/Body/Right/Feedback
@onready var _close_button: Button = $Panel/Margin/VBox/Body/Right/CloseButton


func _ready() -> void:
	_service = RestorationService.new()
	visible = false
	_item_list.item_selected.connect(_on_item_selected)
	_clean_area.pressed.connect(_on_clean_area_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_close_button.pressed.connect(close)


## Opens the restoration screen, pauses the shop clock, and refreshes the list.
func open() -> void:
	visible = true
	DayClock.request_pause(DayClock.PAUSE_RESTORATION)
	_selected_uid = ""
	_selected_tool_id = ""
	_refresh_list()
	_refresh_details()


## Closes the screen and releases pause ownership.
func close() -> void:
	if visible:
		visible = false
		DayClock.release_pause(DayClock.PAUSE_RESTORATION)
	closed.emit()


func _exit_tree() -> void:
	if visible:
		DayClock.release_pause(DayClock.PAUSE_RESTORATION)


func _refresh_list() -> void:
	_item_list.clear()
	var instances := _service.get_restorable_instances()
	for inst in instances:
		var template: ScrapObjectTemplate = _service.get_repository().get_template(inst.template_id)
		var display_name := template.display_name if template != null else inst.template_id
		var state_name := ModelEnums.obj_state_name(inst.state)
		var idx := _item_list.add_item("%s (%s)" % [display_name, state_name])
		_item_list.set_item_metadata(idx, inst.uid)
	if _selected_uid.is_empty() and _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)


func _on_item_selected(index: int) -> void:
	_selected_uid = _item_list.get_item_metadata(index)
	_selected_tool_id = ""
	_refresh_details()


func _refresh_details() -> void:
	for child in _tool_container.get_children():
		child.queue_free()

	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null:
		_detail_name.text = "Select an object to restore"
		_detail_state.text = ""
		_condition_label.text = ""
		_value_label.text = ""
		_damage_label.text = ""
		_selected_tool_label.text = ""
		_clean_area.disabled = true
		_open_button.disabled = true
		return

	var template: ScrapObjectTemplate = _service.get_repository().get_template(inst.template_id)
	var display_name := template.display_name if template != null else inst.template_id
	_detail_name.text = display_name
	_detail_state.text = "State: %s" % ModelEnums.obj_state_name(inst.state)
	_condition_label.text = (
		"Condition: %d / %d" % [int(inst.condition), template.clean_completion_threshold]
	)
	_value_label.text = "Value: ₱%d" % inst.value
	_damage_label.text = "Recorded damage: %d" % inst.recorded_damage
	_selected_tool_label.text = "Selected tool: none"

	var tools := _service.get_available_tools()
	if tools.is_empty():
		var none := Label.new()
		none.text = "No tools available."
		_tool_container.add_child(none)
	else:
		for tool in tools:
			var button := Button.new()
			button.text = tool.display_name
			button.toggle_mode = true
			button.button_pressed = tool.id == _selected_tool_id
			button.pressed.connect(func() -> void: _select_tool(tool.id))
			_tool_container.add_child(button)

	_update_action_buttons(inst, template)


func _select_tool(tool_id: String) -> void:
	_selected_tool_id = tool_id
	var tool := _service.get_repository().get_tool(tool_id)
	_selected_tool_label.text = (
		"Selected tool: %s" % (tool.display_name if tool != null else tool_id)
	)
	for child in _tool_container.get_children():
		if child is Button:
			child.button_pressed = child.text == (tool.display_name if tool != null else tool_id)
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst != null:
		var template: ScrapObjectTemplate = _service.get_repository().get_template(inst.template_id)
		_update_action_buttons(inst, template)


func _update_action_buttons(inst: ObjectInstance, template: ScrapObjectTemplate) -> void:
	_clean_area.disabled = (_selected_tool_id.is_empty() or inst.state != ModelEnums.ObjState.DIRTY)
	_open_button.disabled = inst.state != ModelEnums.ObjState.CLEAN
	_clean_area.text = (
		"Apply selected tool" if inst.state == ModelEnums.ObjState.DIRTY else "Object is clean"
	)
	_open_button.text = (
		"Open clasp" if template != null and template.openable_type == "pendant" else "Open"
	)


func _on_clean_area_pressed() -> void:
	if _selected_uid.is_empty() or _selected_tool_id.is_empty():
		return
	var result := _service.apply_tool(_selected_uid, _selected_tool_id)
	_feedback_label.text = result.feedback
	_refresh_details()
	_refresh_list()


func _on_open_pressed() -> void:
	if _selected_uid.is_empty():
		return
	var result := _service.open_clasp(_selected_uid)
	if result.ok:
		var result_name := ModelEnums.open_result_name(result.result)
		_feedback_label.text = "Opened! Result: %s" % result_name
	else:
		_feedback_label.text = result.error
	_refresh_details()
	_refresh_list()
