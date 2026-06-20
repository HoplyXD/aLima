extends CanvasLayer
## Global pause + settings overlay.
##
## Opens on the "back/cancel" action when nothing else consumed it (so it never
## fights an open overlay's Esc-to-close — it uses _unhandled_input). Pauses the
## game tree while open. Hosts display settings (resolution, fullscreen) that apply
## live, and a renderer choice (Mobile vs Compatibility) that applies on relaunch.
## All persistence/rules live in SettingsService; this is presentation + input only.

var _open: bool = false

var _resume_button: Button
var _res_option: OptionButton
var _fullscreen_check: CheckButton
var _online_check: CheckButton
var _renderer_option: OptionButton
var _apply_renderer_button: Button
var _status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	layer = 128  # above every other CanvasLayer
	_ensure_back_action()
	_build_ui()
	visible = false


## Registers the global "back" action (Backspace) used by overlays to close/back out,
## so Esc stays reserved for pause/unpause. Idempotent; runs before the main scene.
func _ensure_back_action() -> void:
	if InputMap.has_action("back"):
		return
	InputMap.add_action("back")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_BACKSPACE
	InputMap.action_add_event("back", event)


func _unhandled_input(event: InputEvent) -> void:
	# Esc is the dedicated pause toggle. Headless test runs never pause.
	if DisplayServer.get_name() == "headless":
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_refresh()
	_resume_button.grab_focus()


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return _open


# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks behind the menu
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	vbox.add_child(_title("Paused"))

	_resume_button = _button("Resume")
	_resume_button.pressed.connect(close)
	vbox.add_child(_resume_button)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section("Display"))

	_res_option = OptionButton.new()
	for size in SettingsService.RESOLUTIONS:
		_res_option.add_item("%d × %d" % [size.x, size.y])
	_res_option.item_selected.connect(_on_resolution_selected)
	vbox.add_child(_row("Resolution", _res_option))

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(_row("Fullscreen", _fullscreen_check))

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section("Online"))

	_online_check = CheckButton.new()
	_online_check.toggled.connect(_on_online_toggled)
	vbox.add_child(_row("Live buyer banter", _online_check))

	vbox.add_child(HSeparator.new())
	vbox.add_child(_section("Renderer"))

	_renderer_option = OptionButton.new()
	_renderer_option.add_item("Mobile (decals)", 0)
	_renderer_option.add_item("Compatibility (lite)", 1)
	vbox.add_child(_row("Mode", _renderer_option))

	_apply_renderer_button = _button("Apply renderer (restarts game)")
	_apply_renderer_button.pressed.connect(_on_apply_renderer)
	vbox.add_child(_apply_renderer_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(_status_label)

	vbox.add_child(HSeparator.new())
	var quit := _button("Quit to Desktop")
	quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit)


## Syncs the controls to the saved/effective settings each time the menu opens.
func _refresh() -> void:
	_res_option.select(SettingsService.resolution_index())
	_fullscreen_check.set_pressed_no_signal(SettingsService.fullscreen)
	_online_check.set_pressed_no_signal(SettingsService.online_services)

	var mobile_ok: bool = SettingsService.mobile_supported()
	_renderer_option.set_item_disabled(0, not mobile_ok)
	var want_mobile: bool = SettingsService.renderer == SettingsService.RENDERER_MOBILE
	_renderer_option.select(0 if (want_mobile and mobile_ok) else 1)

	var effective: String = SettingsService.effective_renderer()
	var pretty := "Mobile" if effective == SettingsService.RENDERER_MOBILE else "Compatibility"
	_status_label.text = "Now running: %s." % pretty
	if not mobile_ok:
		_status_label.text += " This device can't run Mobile — locked to Compatibility."


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < SettingsService.RESOLUTIONS.size():
		SettingsService.set_resolution(SettingsService.RESOLUTIONS[index])


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsService.set_fullscreen(pressed)


func _on_online_toggled(pressed: bool) -> void:
	SettingsService.set_online_services(pressed)


func _on_apply_renderer() -> void:
	var method := (
		SettingsService.RENDERER_MOBILE
		if _renderer_option.get_selected_id() == 0
		else SettingsService.RENDERER_COMPAT
	)
	var pretty := "Mobile" if method == SettingsService.RENDERER_MOBILE else "Compatibility"
	if method == SettingsService.effective_renderer():
		_status_label.text = "Already running %s." % pretty
		return
	# In an exported build request_renderer closes and reopens the game in the new
	# renderer. In the editor it can't relaunch a play session, so it just saves.
	if not SettingsService.request_renderer(method):
		if SettingsService.running_in_editor():
			_status_label.text = (
				"Saved as %s. The editor can't switch renderers live — run the exported game "
				+ "(or change the default and restart the editor) to see it."
			) % pretty
		else:
			_status_label.text = "Saved. Restart the game to switch to %s." % pretty


# --- Small widgets -----------------------------------------------------------


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	return button


func _row(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row
