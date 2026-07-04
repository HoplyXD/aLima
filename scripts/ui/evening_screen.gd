class_name EveningScreen
extends CanvasLayer
## The end-of-day evening summary + preparation screen (P14.5, EVE-R1..R5, §4-N).
##
## Presentation only; all logic lives in EveningService. The UI is built in code so
## the scene file stays trivial (it is instantiated via EveningScreen.new() by the
## Shop, mirroring ShowcaseScreen). It shows the day's outcome summary, exposes tool
## repair/replace upkeep and storage resolution, lets the player pick a next-day
## plan, and commits — which advances the day (or performs the Day 5 reset) through
## EveningService.commit_plan(). The stable seams for the GUT tests are
## open()/select_plan()/commit()/is_open() and the committed/closed signals.

signal closed
signal committed(day: int, plan_id: String)

var _day: int = 0
var _plan_id: String = ""
var _owns_pause: bool = false

var _backdrop: ColorRect
var _summary_label: RichTextLabel
var _upkeep_box: VBoxContainer
var _plan_box: VBoxContainer
var _status_label: Label
var _commit_button: Button


func _ready() -> void:
	layer = 85
	visible = false
	_build_ui()


## Opens the evening for `day`. Pauses shop time while open.
func open(day: int) -> void:
	_day = day
	_plan_id = ""
	visible = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_EVENING)
		_owns_pause = true
	refresh()
	_commit_button.grab_focus()


func is_open() -> bool:
	return visible


## Sets the next-day plan choice (test seam).
func select_plan(plan_id: String) -> void:
	_plan_id = plan_id
	refresh()


## Commits the evening and lets EveningService advance the day. Closes on success.
func commit() -> void:
	var result := EveningService.commit_plan(_plan_id)
	if not result.ok:
		_status_label.text = ModelUtils.as_string(result.get("error"), "Could not commit.")
		return
	committed.emit(_day, _plan_id)
	close()


func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_EVENING):
		DayClock.release_pause(DayClock.PAUSE_EVENING)
	_owns_pause = false


# --- Rendering ---------------------------------------------------------------


func refresh() -> void:
	_render_summary()
	_render_upkeep()
	_render_plan()


func _render_summary() -> void:
	var s := EveningService.get_summary()
	var storage: Dictionary = s.get("storage", {})
	var lines := PackedStringArray()
	lines.append("[b]Evening — Day %d[/b]" % int(s.get("day", _day)))
	lines.append("Money on hand: ₱%d" % int(s.get("money", 0)))
	lines.append(
		(
			"Sold %d (₱%d) · Returned %d · Preserved %d · Journaled %d"
			% [
				int(s.get("sales", 0)),
				int(s.get("sale_total", 0)),
				int(s.get("returns", 0)),
				int(s.get("preserved", 0)),
				int(s.get("journaled", 0)),
			]
		)
	)
	lines.append(
		(
			"Journal entries: %d · Fragments seated: %d / 5"
			% [int(s.get("journal_entries", 0)), int(s.get("fragments_seated", 0))]
		)
	)
	lines.append(
		(
			"Storage: %d / %d used (%d over)"
			% [int(storage.get("used", 0)), int(storage.get("cap", 0)), int(storage.get("over", 0))]
		)
	)
	_summary_label.text = "\n".join(lines)


func _render_upkeep() -> void:
	for child in _upkeep_box.get_children():
		child.queue_free()
	_upkeep_box.add_child(_label("Tool upkeep", 16))
	var worn := EveningService.tools_needing_upkeep()
	if worn.is_empty():
		_upkeep_box.add_child(_note("Every tool is in good shape."))
	for inst in worn:
		_upkeep_box.add_child(_make_upkeep_row(inst))

	var storage := EveningService.storage_status()
	if int(storage.get("over", 0)) > 0:
		var resolve := Button.new()
		resolve.text = "Recycle %d to fit storage" % int(storage.get("over", 0))
		resolve.focus_mode = Control.FOCUS_ALL
		resolve.pressed.connect(_on_resolve_storage)
		_upkeep_box.add_child(resolve)


func _make_upkeep_row(inst: ToolInstance) -> Control:
	var def := DataRepository.singleton().get_tool(inst.tool_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = (
		"%s  (%d/%d)"
		% [def.display_name if def != null else inst.tool_id, inst.durability, inst.max_durability]
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var uid := inst.uid
	if not inst.is_broken():
		var repair := Button.new()
		repair.text = "Repair ₱%d" % EveningService.repair_cost(uid)
		repair.focus_mode = Control.FOCUS_ALL
		repair.pressed.connect(func() -> void: _on_repair(uid))
		row.add_child(repair)
	var replace := Button.new()
	replace.text = "Replace ₱%d" % EveningService.replace_cost(uid)
	replace.focus_mode = Control.FOCUS_ALL
	replace.pressed.connect(func() -> void: _on_replace(uid))
	row.add_child(replace)
	return row


func _render_plan() -> void:
	for child in _plan_box.get_children():
		child.queue_free()
	_plan_box.add_child(_label("Plan for tomorrow", 16))
	var options: Array = DataRepository.singleton().get_evening_config().get("plan_options", [])
	if options.is_empty():
		_plan_box.add_child(_note("Rest up and take the day as it comes."))
	for opt in options:
		if not (opt is Dictionary):
			continue
		var id := ModelUtils.as_string(opt.get("id"))
		var label := ModelUtils.as_string(opt.get("label"), id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = id == _plan_id
		button.text = ("● " if id == _plan_id else "○ ") + label
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func() -> void: select_plan(id))
		_plan_box.add_child(button)


func _on_repair(uid: String) -> void:
	var result := EveningService.repair_tool(uid)
	if result.ok:
		_status_label.text = "Repaired for ₱%d." % int(result.cost)
	else:
		_status_label.text = ModelUtils.as_string(result.get("error"))
	refresh()


func _on_replace(uid: String) -> void:
	var result := EveningService.replace_tool(uid)
	if result.ok:
		_status_label.text = "Replaced for ₱%d." % int(result.cost)
	else:
		_status_label.text = ModelUtils.as_string(result.get("error"))
	refresh()


func _on_resolve_storage() -> void:
	var recycled := EveningService.resolve_storage_overage()
	_status_label.text = "Recycled %d item(s) to fit storage." % recycled
	refresh()


# --- UI construction ----------------------------------------------------------


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 620)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.custom_minimum_size = Vector2(0, 150)
	col.add_child(_summary_label)

	_upkeep_box = VBoxContainer.new()
	_upkeep_box.add_theme_constant_override("separation", 6)
	col.add_child(_upkeep_box)

	_plan_box = VBoxContainer.new()
	_plan_box.add_theme_constant_override("separation", 6)
	col.add_child(_plan_box)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	col.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_commit_button = Button.new()
	_commit_button.text = "Turn in for the night"
	_commit_button.custom_minimum_size = Vector2(0, 48)
	_commit_button.focus_mode = Control.FOCUS_ALL
	_commit_button.pressed.connect(commit)
	col.add_child(_commit_button)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76))
	return label
