class_name RestorationView
extends CanvasLayer
## Focused 3D restoration view (REST-R8): the production Workbench interaction.
##
## The player picks a delivered object, selects an owned tool, rotates the actual
## 3D object, and cleans grime by working the tool across its surface; once CLEAN,
## a separate 3D clasp interaction opens it. This script is a PRESENTATION + INPUT
## layer only. Every gameplay rule — condition/value, tool compatibility, wrong-
## tool damage, the clean->open gate, and open-result resolution — is delegated to
## RestorationService unchanged. The view never re-implements those rules, never
## writes through SaveService, and never branches on carrier identity, so an
## ordinary pendant and a promoted carrier are indistinguishable until opened.
##
## Gestures are translated into deliberate service calls at stable thresholds: a
## cleaning stroke (a press-drag worth of surface work, or one controller press)
## invokes apply_tool() exactly once — never per-frame or per-pixel.

signal closed  ## Emitted after the view is dismissed.

enum Mode { ROTATE, CLEAN }

const MOUSE_ROTATE_SENSITIVITY: float = 0.0065
const KEY_ROTATE_SPEED: float = 2.2
const STROKE_PIXEL_THRESHOLD: float = 64.0  ## Drag distance that commits one stroke.

## Temporary diagnostic logging for the restoration interaction. Flip to false
## (or remove) once the on-screen flow is confirmed working.
const DEBUG_LOG: bool = true

var _service: RestorationService
var _selected_uid: String = ""
var _selected_tool_id: String = ""
var _is_open: bool = false
var _owns_pause: bool = false
var _mode: int = Mode.ROTATE

# Pointer/stroke state.
var _left_down: bool = false
var _right_down: bool = false
var _stroke_active: bool = false
var _stroke_pixels: float = 0.0
var _last_pointer: Vector2 = Vector2.ZERO
var _stroke_uvs: PackedVector2Array = PackedVector2Array()
var _instance_uids: Array[String] = []

@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/World/Camera3D
@onready var _object: RestorationObject3D = $ViewportContainer/SubViewport/World/ObjectPivot
@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _input_catcher: Control = $InputCatcher

@onready var _instance_selector: OptionButton = %InstanceSelector
@onready var _mode_button: Button = %ModeButton
@onready var _title: Label = %Title
@onready var _state_label: Label = %StateLabel
@onready var _condition_bar: ProgressBar = %ConditionBar
@onready var _condition_label: Label = %ConditionLabel
@onready var _value_label: Label = %ValueLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _surface_bar: ProgressBar = %SurfaceBar
@onready var _tool_container: HBoxContainer = %ToolContainer
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _clasp_prompt: Label = %ClaspPrompt
@onready var _reset_button: Button = %ResetButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_service = RestorationService.new()
	visible = false
	_ensure_input_actions()
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The catcher captures all pointer input over the 3D area so it cannot leak
	# through to the Shop HUD buttons sitting behind this view.
	_input_catcher.gui_input.connect(_on_catcher_gui_input)
	_instance_selector.item_selected.connect(_on_instance_selected)
	_mode_button.pressed.connect(_toggle_mode)
	_reset_button.pressed.connect(reset_view)
	_close_button.pressed.connect(close)
	set_process(false)


## Opens the view, pauses the shop clock, lists restorable objects, and focuses the
## first one. Mirrors the old screen's no-argument integration boundary.
func open() -> void:
	visible = true
	_is_open = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_RESTORATION)
		_owns_pause = true
	set_process(true)
	_populate_instances()
	_log("open(): %d restorable instance(s): %s" % [_instance_uids.size(), str(_instance_uids)])
	if _instance_uids.is_empty():
		_show_empty_state()
	else:
		_instance_selector.select(0)
		load_instance(_instance_uids[0])
	_grab_initial_focus()


## Closes the view and releases pause ownership exactly once.
func close() -> void:
	if _is_open:
		_is_open = false
		visible = false
		set_process(false)
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause:
		DayClock.release_pause(DayClock.PAUSE_RESTORATION)
		_owns_pause = false


# --- Instance / tool selection ----------------------------------------------


func _populate_instances() -> void:
	_instance_selector.clear()
	_instance_uids.clear()
	for inst in _service.get_restorable_instances():
		var template := _service.get_repository().get_template(inst.template_id)
		var display_name := template.display_name if template != null else inst.template_id
		var state_name := ModelEnums.obj_state_name(inst.state)
		_instance_selector.add_item("%s (%s)" % [display_name, state_name])
		_instance_uids.append(inst.uid)
	_instance_selector.disabled = _instance_uids.is_empty()


## Loads a specific instance into the 3D view. Public so the Shop/tests can drive
## selection directly; presentation is rebuilt purely from saved instance state.
func load_instance(uid: String) -> void:
	_selected_uid = uid
	_selected_tool_id = ""
	var inst := _service.find_instance_by_id(uid)
	var template: ScrapObjectTemplate = (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst == null or template == null:
		_show_invalid_state()
		return
	_object.visible = true
	_object.configure(template, inst)
	_title.text = template.display_name
	_set_mode(Mode.ROTATE)
	_rebuild_tool_palette()
	reset_view()
	_refresh(inst, template)
	_caption_label.text = "Rotate to inspect, then choose a tool and work the surface."
	_log(
		(
			"load_instance(%s): template=%s state=%s condition=%.0f tools=%d"
			% [
				uid,
				template.id,
				ModelEnums.obj_state_name(inst.state),
				inst.condition,
				_service.get_available_tools().size()
			]
		)
	)


func _rebuild_tool_palette() -> void:
	for child in _tool_container.get_children():
		child.queue_free()
	var tools := _service.get_available_tools()
	if tools.is_empty():
		var none := Label.new()
		none.text = "No tools available."
		_tool_container.add_child(none)
		return
	for tool in tools:
		var button := Button.new()
		button.text = tool.display_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.button_pressed = tool.id == _selected_tool_id
		var tool_id := tool.id
		button.pressed.connect(func() -> void: select_tool(tool_id))
		_tool_container.add_child(button)


## Selects an owned tool to clean with. Public so the Shop/tests can drive it.
func select_tool(tool_id: String) -> void:
	_selected_tool_id = tool_id
	_log("select_tool(%s) -> mode CLEAN" % tool_id)
	for child in _tool_container.get_children():
		if child is Button:
			child.button_pressed = (child as Button).text == _tool_display_name(tool_id)
	# Selecting a tool moves the player into cleaning; they can switch back to
	# Rotate (mode toggle / right-drag / rotate keys) to inspect again.
	_set_mode(Mode.CLEAN)
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst != null and inst.state == ModelEnums.ObjState.DIRTY:
		_caption_label.text = (
			"Work the %s across the surface to clean it." % _tool_display_name(tool_id)
		)


func _tool_display_name(tool_id: String) -> String:
	var tool := _service.get_repository().get_tool(tool_id)
	return tool.display_name if tool != null else tool_id


# --- Cleaning (delegates every rule to RestorationService) -------------------


## Commits one deliberate cleaning stroke worth of work over the given surface UVs.
## Returns the service ToolResult, or null when nothing actionable happened (no
## tool, not DIRTY, or the stroke never touched the surface — i.e. empty space).
func commit_stroke(worked_uvs: PackedVector2Array) -> RestorationService.ToolResult:
	if not _is_open or worked_uvs.is_empty():
		_log("commit_stroke skipped: no surface worked (missed the object)")
		return null
	if _selected_uid.is_empty() or _selected_tool_id.is_empty():
		_log("commit_stroke skipped: no tool selected")
		return null
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null or inst.state != ModelEnums.ObjState.DIRTY:
		var state_name := "missing" if inst == null else ModelEnums.obj_state_name(inst.state)
		_log("commit_stroke skipped: instance not DIRTY (state=%s)" % state_name)
		return null
	var result := _service.apply_tool(_selected_uid, _selected_tool_id)
	if result.ok and result.compatible:
		for uv in worked_uvs:
			_object.clean_brush_at_uv(uv)
		if result.reached_clean:
			_object.set_fully_clean()
	_log(
		(
			"commit_stroke: tool=%s compatible=%s condition=%.0f->%.0f reached_clean=%s coverage=%.2f"
			% [
				_selected_tool_id,
				str(result.compatible),
				result.condition_before,
				result.condition_after,
				str(result.reached_clean),
				_object.coverage()
			]
		)
	)
	_apply_action_feedback(result)
	return result


## Convenience for a single-point stroke (controller/keyboard cleaning and tests).
func clean_stroke_at_uv(uv: Vector2) -> RestorationService.ToolResult:
	return commit_stroke(PackedVector2Array([uv]))


## Ray-tests the surface and, on a hit, performs one stroke there. Returns null on
## a miss so cleaning empty space is a genuine no-op.
func attempt_clean_with_ray(origin: Vector3, direction: Vector3) -> RestorationService.ToolResult:
	var hit := _object.ray_test_surface(origin, direction)
	if not hit.get("hit", false):
		return null
	return clean_stroke_at_uv(hit["uv"])


# --- Clasp opening (delegates the gate + resolution to the service) ----------


## Attempts the 3D clasp open. The service enforces the clean->open gate, so a
## DIRTY object is rejected here exactly as everywhere else, and opening is
## single-use. Content is shown from the resolved result without re-resolving it.
func try_open_clasp() -> RestorationService.OpenAttemptResult:
	if not _is_open or _selected_uid.is_empty():
		var blocked := RestorationService.OpenAttemptResult.new()
		blocked.error = "No object selected."
		return blocked
	var result := _service.open_clasp(_selected_uid)
	if result.ok:
		_object.set_clasp_open(true)
		_feedback_label.text = "The clasp opens."
		_caption_label.text = "The clasp opens — inside is %s" % _friendly_result(result.result)
	else:
		_feedback_label.text = result.error
		_caption_label.text = result.error
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)
	return result


func _friendly_result(open_result: int) -> String:
	match open_result:
		ModelEnums.OpenResult.FRAGMENT:
			return "a fragment."
		ModelEnums.OpenResult.TEMPORAL_ECHO:
			return "a faint echo."
		_:
			return "nothing of note."


# --- Feedback / meters -------------------------------------------------------


func _apply_action_feedback(result: RestorationService.ToolResult) -> void:
	if result == null:
		return
	_feedback_label.text = result.feedback
	if not result.compatible:
		_caption_label.text = "Wrong tool — %s Condition and value dropped." % result.feedback
	elif result.reached_clean:
		_caption_label.text = "The surface is clean. Open the clasp to see inside."
	else:
		_caption_label.text = "Cleaned a section. Keep working the grime."
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)


func _refresh(inst: ObjectInstance, template: ScrapObjectTemplate) -> void:
	var threshold := template.clean_completion_threshold if template != null else 100
	_state_label.text = "State: %s" % ModelEnums.obj_state_name(inst.state).capitalize()
	_condition_bar.max_value = threshold
	_condition_bar.value = inst.condition
	_condition_label.text = "Condition %d / %d" % [int(inst.condition), threshold]
	_value_label.text = "Value: P%d" % inst.value
	_damage_label.text = "Recorded damage: %d" % inst.recorded_damage
	_surface_bar.value = _object.coverage() * 100.0

	var is_clean := inst.state == ModelEnums.ObjState.CLEAN
	var is_open := inst.state == ModelEnums.ObjState.OPEN
	_object.set_clasp_revealed(is_clean)
	if is_open:
		_object.set_clasp_open(true)
	_clasp_prompt.visible = is_clean
	if is_clean:
		_clasp_prompt.text = "Pendant is clean — click the clasp (or press Open) to open it."
	elif is_open:
		_clasp_prompt.visible = false


func _show_empty_state() -> void:
	_selected_uid = ""
	_title.text = "Nothing to restore"
	_object.visible = false
	_caption_label.text = "No delivered objects are ready for the bench."
	_state_label.text = ""
	_condition_label.text = ""
	_value_label.text = ""
	_damage_label.text = ""
	_clasp_prompt.visible = false
	for child in _tool_container.get_children():
		child.queue_free()


func _show_invalid_state() -> void:
	_object.visible = false
	_title.text = "Object unavailable"
	_caption_label.text = "That object can no longer be restored."
	_clasp_prompt.visible = false


# --- Mode --------------------------------------------------------------------


func _toggle_mode() -> void:
	_set_mode(Mode.ROTATE if _mode == Mode.CLEAN else Mode.CLEAN)


func _set_mode(mode: int) -> void:
	_mode = mode
	_mode_button.text = "Mode: Clean" if _mode == Mode.CLEAN else "Mode: Rotate"


func get_mode() -> int:
	return _mode


func get_selected_uid() -> String:
	return _selected_uid


func get_restoration_object() -> RestorationObject3D:
	return _object


func owns_pause() -> bool:
	return _owns_pause


func _log(msg: String) -> void:
	if DEBUG_LOG:
		print("[Restoration] ", msg)


# --- View controls -----------------------------------------------------------


func reset_view() -> void:
	_object.reset_orientation()


## Orbits the displayed object. Presentation only — never mutates game state.
func rotate_view(delta_yaw: float, delta_pitch: float) -> void:
	_object.rotate_view(delta_yaw, delta_pitch)


# --- Input -------------------------------------------------------------------


func _process(delta: float) -> void:
	if not _is_open:
		return
	var rx := (
		Input.get_action_strength("restoration_rotate_right")
		- Input.get_action_strength("restoration_rotate_left")
	)
	var ry := (
		Input.get_action_strength("restoration_rotate_down")
		- Input.get_action_strength("restoration_rotate_up")
	)
	if rx != 0.0 or ry != 0.0:
		_object.rotate_view(-rx * KEY_ROTATE_SPEED * delta, -ry * KEY_ROTATE_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard/controller actions only; pointer input is handled by the InputCatcher
	# so it cannot fall through to Controls on other CanvasLayers (the Shop HUD).
	if not _is_open:
		return
	if _handle_action_event(event):
		get_viewport().set_input_as_handled()


## Mouse and (emulated) touch handling for the 3D area. Positions are in catcher-
## local space, which equals screen space because the catcher fills the screen.
func _on_catcher_gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		_input_catcher.accept_event()
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		_input_catcher.accept_event()


func _handle_action_event(event: InputEvent) -> bool:
	if event.is_action_pressed("restoration_clean"):
		_controller_clean()
		return true
	if event.is_action_pressed("restoration_open"):
		try_open_clasp()
		return true
	if event.is_action_pressed("restoration_reset_view"):
		reset_view()
		return true
	if event.is_action_pressed("restoration_toggle_mode"):
		_toggle_mode()
		return true
	if event.is_action_pressed("ui_cancel"):
		close()
		return true
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := _ray_at_pointer(pos)
			_log(
				(
					"left press @%s mode=%s surface_hit=%s tool=%s"
					% [
						str(pos),
						"CLEAN" if _mode == Mode.CLEAN else "ROTATE",
						str(hit.get("hit", false)),
						_selected_tool_id
					]
				)
			)
			if not _pointer_over_viewport(pos):
				return
			if _try_clasp_at_pointer(pos):
				return
			_last_pointer = pos
			if _mode == Mode.CLEAN:
				_begin_stroke(pos)
			_left_down = true
		else:
			if _stroke_active:
				_end_stroke()
			_left_down = false
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-drag always rotates (a mouse convenience); touch/controller use the
		# mode toggle and rotate actions instead, so no gesture is right-click-only.
		if event.pressed and _pointer_over_viewport(pos):
			_right_down = true
			_last_pointer = pos
		else:
			_right_down = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var pos := event.position
	if _left_down and _mode == Mode.CLEAN and _stroke_active:
		_accumulate_stroke(pos)
	elif _right_down or (_left_down and _mode == Mode.ROTATE):
		_object.rotate_view(
			-event.relative.x * MOUSE_ROTATE_SENSITIVITY,
			-event.relative.y * MOUSE_ROTATE_SENSITIVITY
		)


func _controller_clean() -> void:
	if _selected_tool_id.is_empty():
		_caption_label.text = "Select a tool first."
		return
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null or inst.state != ModelEnums.ObjState.DIRTY:
		return
	clean_stroke_at_uv(_object.auto_target_dirty_uv())


func _begin_stroke(pos: Vector2) -> void:
	_stroke_active = true
	_stroke_pixels = 0.0
	_stroke_uvs.clear()
	_last_pointer = pos
	_add_stroke_sample(pos)


func _accumulate_stroke(pos: Vector2) -> void:
	_stroke_pixels += pos.distance_to(_last_pointer)
	_last_pointer = pos
	_add_stroke_sample(pos)
	if _stroke_pixels >= STROKE_PIXEL_THRESHOLD:
		if not _stroke_uvs.is_empty():
			commit_stroke(_stroke_uvs)
		_stroke_uvs.clear()
		_stroke_pixels = 0.0


func _end_stroke() -> void:
	if _stroke_active and not _stroke_uvs.is_empty():
		commit_stroke(_stroke_uvs)
	_stroke_active = false
	_stroke_uvs.clear()
	_stroke_pixels = 0.0


func _add_stroke_sample(pos: Vector2) -> void:
	var hit := _ray_at_pointer(pos)
	if hit.get("hit", false):
		_stroke_uvs.append(hit["uv"])


func _try_clasp_at_pointer(pos: Vector2) -> bool:
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	if _object.ray_test_clasp(origin, dir).get("hit", false):
		try_open_clasp()
		return true
	return false


func _ray_at_pointer(pos: Vector2) -> Dictionary:
	var vp := _to_viewport(pos)
	var origin := _camera.project_ray_origin(vp)
	var dir := _camera.project_ray_normal(vp)
	return _object.ray_test_surface(origin, dir)


func _pointer_over_viewport(pos: Vector2) -> bool:
	return _viewport_container.get_global_rect().has_point(pos)


func _to_viewport(pos: Vector2) -> Vector2:
	return pos - _viewport_container.get_global_rect().position


func _grab_initial_focus() -> void:
	if not _instance_selector.disabled:
		_instance_selector.grab_focus()
	else:
		_close_button.grab_focus()


func _on_instance_selected(index: int) -> void:
	if index >= 0 and index < _instance_uids.size():
		load_instance(_instance_uids[index])


# --- Input map ---------------------------------------------------------------


## Registers restoration Input Map actions at runtime (idempotent) so the view
## works with keyboard and controller without requiring hand-edited project.godot
## InputEvent serialization. A full remap UI is a later input/accessibility phase.
func _ensure_input_actions() -> void:
	_add_action("restoration_rotate_left", [_key(KEY_A)], [_joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("restoration_rotate_right", [_key(KEY_D)], [_joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("restoration_rotate_up", [_key(KEY_W)], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("restoration_rotate_down", [_key(KEY_S)], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("restoration_clean", [_key(KEY_SPACE)], [_joy_button(JOY_BUTTON_A)])
	_add_action("restoration_open", [_key(KEY_E)], [_joy_button(JOY_BUTTON_X)])
	_add_action("restoration_reset_view", [_key(KEY_R)], [_joy_button(JOY_BUTTON_Y)])
	_add_action("restoration_toggle_mode", [_key(KEY_TAB)], [_joy_button(JOY_BUTTON_LEFT_SHOULDER)])


func _add_action(action: String, keys: Array, pads: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev in keys:
		InputMap.action_add_event(action, ev)
	for ev in pads:
		InputMap.action_add_event(action, ev)


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
