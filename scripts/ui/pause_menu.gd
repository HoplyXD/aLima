extends CanvasLayer
## Global pause + settings overlay.
##
## The layout lives in pause_menu.tscn so every control is visible/editable in the
## editor; this script is presentation wiring + input only. Opens on the "back/cancel"
## action when nothing else consumed it (uses _unhandled_input so it never fights an
## open overlay's Esc-to-close). Pauses the game tree while open. Hosts display
## settings (resolution, fullscreen) that apply live, and a renderer choice (Mobile vs
## Compatibility) that applies on relaunch. All persistence/rules live in SettingsService.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

@onready var _resume_button: Button = %ResumeButton
@onready var _return_button: Button = %ReturnToTitleButton
@onready var _exit_button: Button = %ExitButton
@onready var _res_option: OptionButton = %ResolutionOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _online_check: CheckButton = %OnlineCheck
@onready var _previews_check: CheckButton = %PreviewsCheck
@onready var _renderer_option: OptionButton = %RendererOption
@onready var _apply_renderer_button: Button = %ApplyRendererButton
@onready var _status_label: Label = %StatusLabel

var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	layer = 128  # above every other CanvasLayer
	_ensure_actions()
	_populate_resolutions()
	_connect_signals()
	visible = false


## Registers the global input scheme: "back" (Esc) closes/returns out of overlays, and
## "pause" (Space) toggles the pause menu. Idempotent; runs before the main scene.
func _ensure_actions() -> void:
	if not InputMap.has_action("back"):
		InputMap.add_action("back")
		_bind_key("back", KEY_ESCAPE)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		_bind_key("pause", KEY_SPACE)
		_bind_joy("pause", JOY_BUTTON_START)


func _bind_key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _bind_joy(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _populate_resolutions() -> void:
	_res_option.clear()
	for size in SettingsService.RESOLUTIONS:
		_res_option.add_item("%d × %d" % [size.x, size.y])


func _connect_signals() -> void:
	_resume_button.pressed.connect(close)
	_return_button.pressed.connect(_on_return_to_title)
	_exit_button.pressed.connect(func() -> void: get_tree().quit())
	_res_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_online_check.toggled.connect(_on_online_toggled)
	_previews_check.toggled.connect(_on_previews_toggled)
	_apply_renderer_button.pressed.connect(_on_apply_renderer)


func _unhandled_input(event: InputEvent) -> void:
	# Space toggles pause; Esc/Backspace closes the pause menu when it is open (and is
	# otherwise consumed by whatever overlay is up). Headless test runs never pause.
	if DisplayServer.get_name() == "headless":
		return
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("back"):
		close()
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


func _on_return_to_title() -> void:
	close()
	get_tree().change_scene_to_file(TITLE_SCENE)


## Syncs the controls to the saved/effective settings each time the menu opens.
func _refresh() -> void:
	_res_option.select(SettingsService.resolution_index())
	_fullscreen_check.set_pressed_no_signal(SettingsService.fullscreen)
	_online_check.set_pressed_no_signal(SettingsService.online_services)
	_previews_check.set_pressed_no_signal(SettingsService.artifact_previews)

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


func _on_previews_toggled(pressed: bool) -> void:
	SettingsService.set_artifact_previews(pressed)


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
