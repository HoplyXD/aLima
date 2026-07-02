extends CanvasLayer
## Global pause + settings overlay.
##
## Settings overlay. Opens on the "pause" action (Space or Esc).
## Pauses the game tree while open. All persistence/rules live in SettingsService.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

@onready var _resume_button: Button = %ResumeButton
@onready var _skip_tutorial_button: Button = %SkipTutorialButton
@onready var _skip_tutorial_confirm: ConfirmationDialog = %SkipTutorialConfirm
@onready var _save_button: Button = %SaveButton
@onready var _save_and_quit_button: Button = %SaveAndQuitButton
@onready var _return_button: Button = %ReturnToTitleButton
@onready var _exit_button: Button = %ExitButton
@onready var _res_option: OptionButton = %ResolutionOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _online_check: CheckButton = %OnlineCheck
@onready var _previews_check: CheckButton = %PreviewsCheck
@onready var _status_label: Label = %StatusLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _slot_label: Label = %SlotLabel

var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	layer = 128  # above every other CanvasLayer
	_ensure_actions()
	_populate_resolutions()
	_connect_signals()
	visible = false


## Registers the global input scheme: "back" (Esc) closes/returns out of overlays, and
## "pause" (Space or Esc) toggles the pause menu. Idempotent; runs before the main scene.
func _ensure_actions() -> void:
	if not InputMap.has_action("back"):
		InputMap.add_action("back")
		_bind_key("back", KEY_ESCAPE)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		_bind_key("pause", KEY_SPACE)
		_bind_key("pause", KEY_ESCAPE)
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
	_skip_tutorial_button.pressed.connect(_on_skip_tutorial_pressed)
	_skip_tutorial_confirm.confirmed.connect(_on_skip_tutorial_confirmed)
	_save_button.pressed.connect(_on_save_pressed)
	_save_and_quit_button.pressed.connect(_on_save_and_quit_pressed)
	_return_button.pressed.connect(_on_return_to_title)
	_exit_button.pressed.connect(func() -> void: get_tree().quit())
	_res_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_online_check.toggled.connect(_on_online_toggled)
	_previews_check.toggled.connect(_on_previews_toggled)


func _unhandled_input(event: InputEvent) -> void:
	# Space/Esc toggles pause; Esc/Backspace closes the pause menu when it is open
	# (and is otherwise consumed by whatever overlay is up). Headless test runs never pause.
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


func _on_save_pressed() -> void:
	var result := SaveService.save_game()
	if result.ok:
		_status_label.text = "Saved to %s." % result.get("path", "slot")
	else:
		_status_label.text = "Save failed: %s" % result.get("error", "")


func _on_save_and_quit_pressed() -> void:
	var result := SaveService.save_game()
	if not result.ok:
		_status_label.text = "Save failed: %s" % result.get("error", "")
		return
	close()
	SpaceManager.return_to_title()


func _on_return_to_title() -> void:
	close()
	SpaceManager.return_to_title()


## Skip Tutorial is offered only while Day 0 is active (TUT). Confirming grants
## everything the tutorial would grant (the starting kit arrives with the Day 1
## reset inside complete_tutorial) and reloads the shop as a normal Day 1.
func _on_skip_tutorial_pressed() -> void:
	_skip_tutorial_confirm.popup_centered()


func _on_skip_tutorial_confirmed() -> void:
	TutorialService.skip()
	close()
	SpaceManager.go_to_shop()


## Syncs the controls to the saved/effective settings each time the menu opens.
func _refresh() -> void:
	_skip_tutorial_button.visible = TutorialService.is_tutorial_active()
	_res_option.select(SettingsService.resolution_index())
	_fullscreen_check.set_pressed_no_signal(SettingsService.fullscreen)
	_online_check.set_pressed_no_signal(SettingsService.ai_mode_is_online())
	_previews_check.set_pressed_no_signal(SettingsService.artifact_previews)

	_status_label.text = "Settings applied."

	var seed_text := "Seed: %d" % GameState.run_seed
	var slot := SaveService.get_selected_slot()
	var slot_text := "Slot: %d" % (slot + 1) if SaveService.is_slot_valid(slot) else "Slot: —"
	_seed_label.text = seed_text
	_slot_label.text = slot_text


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < SettingsService.RESOLUTIONS.size():
		SettingsService.set_resolution(SettingsService.RESOLUTIONS[index])


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsService.set_fullscreen(pressed)


## Toggles the marketplace AI source: on → backend server, off → on-device Godot LLM.
func _on_online_toggled(pressed: bool) -> void:
	SettingsService.set_ai_mode(
		SettingsService.AI_ONLINE if pressed else SettingsService.AI_OFFLINE
	)


## Toggles the optional "highlight the conditions a selected tool can clean" learning aid.
func _on_previews_toggled(pressed: bool) -> void:
	SettingsService.set_artifact_previews(pressed)
