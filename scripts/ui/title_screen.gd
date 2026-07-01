class_name TitleScreen
extends Control
## Main-menu title screen.
##
## First scene the game boots into. Supports New Game (slot + seed), Continue,
## Options, and Quit. The layout lives in title_screen.tscn; this script handles
## screen navigation, seed validation, slot overwrite confirmation, and hand-off
## to SpaceManager. The backdrop camera parallax is preserved.

const BACKDROP_CAM_PATH: NodePath = ^"Backdrop/SubViewport/AntiqueShop/Title Screen cam"

const MAX_SEED: int = 2147483646

@export_group("Idle Sway")
@export var idle_move_amount: float = 0.035
@export var idle_tilt_amount: float = 0.012
@export var idle_speed: float = 0.35

@export_group("Mouse Parallax")
@export var parallax_move_amount: float = 0.06
@export var parallax_tilt_amount: float = 0.018
@export var parallax_smooth: float = 4.0

@onready var _main_menu: VBoxContainer = $MainMenu
@onready var _new_game_button: Button = $MainMenu/NewGame
@onready var _continue_button: Button = $MainMenu/Continue
@onready var _options_button: Button = $MainMenu/Options
@onready var _quit_button: Button = $MainMenu/Quit

@onready var _slot_menu: VBoxContainer = $SlotMenu
@onready var _slot_buttons: Array[Button] = [
	$SlotMenu/Slot0,
	$SlotMenu/Slot1,
	$SlotMenu/Slot2,
]
@onready var _slot_back_button: Button = $SlotMenu/Back

@onready var _name_menu: VBoxContainer = $NameMenu
@onready var _name_edit: LineEdit = $NameMenu/NameEdit
@onready var _name_confirm_button: Button = $NameMenu/Confirm
@onready var _name_back_button: Button = $NameMenu/Back
@onready var _name_status: Label = $NameMenu/Status

@onready var _seed_menu: VBoxContainer = $SeedMenu
@onready var _seed_edit: LineEdit = $SeedMenu/SeedRow/SeedEdit
@onready var _randomize_button: Button = $SeedMenu/SeedRow/Randomize
@onready var _start_button: Button = $SeedMenu/Start
@onready var _seed_back_button: Button = $SeedMenu/Back
@onready var _seed_status: Label = $SeedMenu/Status

@onready var _status_label: Label = $StatusLabel
@onready var _overwrite_dialog: AcceptDialog = $OverwriteConfirm

@onready var _backdrop_cam: Camera3D = get_node_or_null(BACKDROP_CAM_PATH) as Camera3D

var _cam_base_position: Vector3
var _cam_base_basis: Basis
var _time: float = 0.0
var _parallax: Vector2 = Vector2.ZERO

var _selected_slot: int = -1
## Name confirmed on the NameMenu, applied to the save in _start_new_game().
var _pending_player_name: String = ""


func _ready() -> void:
	_connect_main_menu()
	_connect_slot_menu()
	_connect_name_menu()
	_connect_seed_menu()
	_connect_overwrite_dialog()
	_show_main_menu()
	_refresh_continue_button()

	if _backdrop_cam != null:
		_cam_base_position = _backdrop_cam.transform.origin
		_cam_base_basis = _backdrop_cam.transform.basis
	else:
		set_process(false)


func _process(delta: float) -> void:
	_time += delta

	var target := Vector2.ZERO
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		target = ((mouse / viewport_size) * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_parallax = _parallax.lerp(target, clampf(parallax_smooth * delta, 0.0, 1.0))

	var sway := Vector2(sin(_time * idle_speed), sin(_time * idle_speed * 1.3 + 1.7))

	var right: Vector3 = _cam_base_basis.x
	var up: Vector3 = _cam_base_basis.y
	var offset_x: float = sway.x * idle_move_amount + _parallax.x * parallax_move_amount
	var offset_y: float = sway.y * idle_move_amount - _parallax.y * parallax_move_amount
	var yaw: float = sway.x * idle_tilt_amount - _parallax.x * parallax_tilt_amount
	var pitch: float = sway.y * idle_tilt_amount + _parallax.y * parallax_tilt_amount

	var new_basis: Basis = _cam_base_basis * Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var new_origin: Vector3 = _cam_base_position + right * offset_x + up * offset_y
	_backdrop_cam.transform = Transform3D(new_basis, new_origin)


# --- Screen navigation --------------------------------------------------------


func _show_main_menu() -> void:
	_hide_all_menus()
	_main_menu.visible = true
	_new_game_button.grab_focus()
	_refresh_continue_button()


func _show_seed_menu() -> void:
	_hide_all_menus()
	_seed_menu.visible = true
	_seed_edit.text = ""
	_seed_status.text = ""
	_seed_edit.grab_focus()


func _show_name_menu() -> void:
	_hide_all_menus()
	_name_menu.visible = true
	_name_edit.text = _pending_player_name
	_name_status.text = ""
	_name_edit.grab_focus()


func _hide_all_menus() -> void:
	_main_menu.visible = false
	_slot_menu.visible = false
	_name_menu.visible = false
	_seed_menu.visible = false


# --- Main menu ----------------------------------------------------------------


func _connect_main_menu() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	_show_slot_menu(true)


func _on_continue_pressed() -> void:
	_show_slot_menu(false)


func _on_options_pressed() -> void:
	PauseMenu.open()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh_continue_button() -> void:
	var has_save := false
	for i in SaveService.slot_count():
		if SaveService.slot_exists(i):
			has_save = true
			break
	_continue_button.disabled = not has_save


# --- Slot menu ----------------------------------------------------------------


func _connect_slot_menu() -> void:
	for i in _slot_buttons.size():
		_slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i))
	_slot_back_button.pressed.connect(_show_main_menu)


func _refresh_slot_buttons(for_new_game: bool) -> void:
	for i in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		var summary: Dictionary = SaveService.slot_summary(i)
		if summary.is_empty():
			button.text = "Slot %d — Empty" % (i + 1)
			button.disabled = not for_new_game
		else:
			var day: int = summary.get("current_day", 1)
			var loop: int = summary.get("loop_index", 0)
			var seed: int = summary.get("run_seed", 0)
			button.text = "Slot %d — Day %d / Loop %d (Seed %d)" % [i + 1, day, loop, seed]
			button.disabled = false


func _on_slot_pressed(slot: int) -> void:
	_selected_slot = slot
	if SaveService.slot_exists(slot):
		# Occupied slot: different behavior for New Game vs Continue.
		if _seed_menu.visible:
			# Should not happen; seed menu is only reached from an empty slot.
			return
		# We need to know whether we're in New Game or Continue flow.
		# The slot menu is shown for one or the other; use a stored flag.
		if _in_new_game_flow:
			_overwrite_dialog.dialog_text = (
				"Slot %d already has a saved run. Overwrite it? This cannot be undone." % (slot + 1)
			)
			_overwrite_dialog.popup_centered()
		else:
			_attempt_continue(slot)
	else:
		# Empty slot: only valid for New Game.
		_show_name_menu()


# --- Name menu ------------------------------------------------------------------


func _connect_name_menu() -> void:
	_name_confirm_button.pressed.connect(_on_name_confirm_pressed)
	_name_back_button.pressed.connect(_show_slot_menu.bind(true))
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_name_confirm_pressed())


func _on_name_confirm_pressed() -> void:
	var parsed := _parse_player_name(_name_edit.text)
	if parsed.is_empty():
		_name_status.text = "Enter a name (letters, numbers, or spaces)."
		return
	_pending_player_name = parsed
	_show_seed_menu()


## Returns the trimmed name, or "" when invalid (blank/whitespace-only).
func _parse_player_name(text: String) -> String:
	return text.strip_edges()


# --- Seed menu ----------------------------------------------------------------


func _connect_seed_menu() -> void:
	_randomize_button.pressed.connect(_on_randomize_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_seed_back_button.pressed.connect(_show_name_menu)
	_seed_edit.text_changed.connect(_on_seed_text_changed)


func _on_seed_text_changed(new_text: String) -> void:
	# Strip any non-digit input immediately.
	var filtered := ""
	for ch in new_text:
		if ch.is_valid_int():
			filtered += ch
	if filtered != new_text:
		_seed_edit.text = filtered
		_seed_edit.caret_column = filtered.length()


func _on_randomize_pressed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_seed_edit.text = str(rng.randi_range(0, MAX_SEED))


func _on_start_pressed() -> void:
	var seed := _parse_seed(_seed_edit.text)
	if seed < 0:
		_seed_status.text = "Enter a number from 0 to %d." % MAX_SEED
		return
	_start_new_game(_selected_slot, seed)


func _parse_seed(text: String) -> int:
	if text.is_empty():
		return -1
	if not text.is_valid_int():
		return -1
	var value := text.to_int()
	if value < 0 or value > MAX_SEED:
		return -1
	return value


# --- Overwrite dialog ---------------------------------------------------------


func _connect_overwrite_dialog() -> void:
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_dialog.canceled.connect(_on_overwrite_canceled)


func _on_overwrite_confirmed() -> void:
	SaveService.delete_slot(_selected_slot)
	_show_name_menu()


func _on_overwrite_canceled() -> void:
	_selected_slot = -1


# --- Flow helpers -------------------------------------------------------------

## Tracks whether the slot menu is currently being shown for New Game or Continue.
var _in_new_game_flow: bool = false


func _show_slot_menu(for_new_game: bool) -> void:
	_in_new_game_flow = for_new_game
	_hide_all_menus()
	_slot_menu.visible = true
	_refresh_slot_buttons(for_new_game)
	_slot_back_button.grab_focus()


func _start_new_game(slot: int, seed: int) -> void:
	SaveService.select_slot(slot)
	GameState.initialize("local-player")
	# After initialize (it rebuilds save_state), stamp the chosen identity so the
	# very first save already carries the player's name.
	GameState.save_state.persistent.player_name = _pending_player_name
	GameState.new_run(seed)
	var save_result := SaveService.save_game()
	if not save_result.ok:
		_seed_status.text = "Save failed: %s" % save_result.get("error", "")
		return
	SpaceManager.go_to_shop()


func _attempt_continue(slot: int) -> void:
	SaveService.select_slot(slot)
	var load_result := SaveService.load_game()
	if not load_result.ok:
		_status_label.text = "Could not load slot %d: %s" % [slot + 1, load_result.get("error", "")]
		_show_main_menu()
		return
	SpaceManager.go_to_shop()
