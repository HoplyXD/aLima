extends Node
## Centralized UI interaction audio for the aLima interface.
##
## Autoloaded as `UiAudio`. Watches the whole scene tree and automatically wires
## every interactive control (authored `Button`/`OptionButton`/`CheckButton`, the many
## runtime `Button.new()` sites, custom `extends Button` classes, and `TabContainer`
## tabs) so hover, focus (keyboard/controller) and press all play a subtle, warm,
## medieval-appropriate sound. New UI inherits the behaviour with zero setup.
##
## Playback is allocation-free after boot: a small pool of `AudioStreamPlayer`s is
## created once and reused, and all clips are preloaded. Sounds fire on the same
## `mouse_entered`/`focus_entered` edge the theme hover visuals use, so they stay in
## sync with the existing UI animations.

## Where the soft, short, wooden UI ticks live. Kept as editable constants so the
## mix can be retuned without touching logic. The Wood Block set is warm and tactile
## (medieval, non-arcade); louder/futuristic packs in the same folder are avoided.
const AUDIO_DIR := "res://assets/audio/UI Soundpack/WAV/"
const HOVER_CLIPS: Array[String] = [
	AUDIO_DIR + "Wood Block1.wav",
	AUDIO_DIR + "Wood Block2.wav",
	AUDIO_DIR + "Wood Block3.wav",
]

## Audio bus the UI players are routed to (added in default_bus_layout.tres).
const UI_BUS := &"UI"
## Reused player count. Hover ticks are short, so 8 is ample even for fast sweeps;
## if every voice is busy we round-robin steal rather than allocate.
const POOL_SIZE := 8
## Per-node cooldown (ms) so `mouse_entered` and `focus_entered` firing together on
## the same control collapse into a single tick ("once per hover").
const HOVER_DEDUP_MS := 60

## Per-voice loudness, measured relative to Master when the `UI` bus is at unity and
## `SettingsService.ui_volume` is 1.0. Hover sits inside the requested -18..-12 dB
## window; pressed is clearly stronger but still restrained; locked is a muted thud.
const HOVER_VOLUME_DB := -16.0
const PRESSED_VOLUME_DB := -10.0
const LOCKED_VOLUME_DB := -26.0
## Per-keystroke clacks are the quietest voice so fast typing never overwhelms.
const CLACK_VOLUME_DB := -20.0
const HOVER_PITCH_MIN := 0.97
const HOVER_PITCH_MAX := 1.03
const PRESSED_PITCH := 0.9
const LOCKED_PITCH := 0.7
const CLACK_PITCH_MIN := 1.3
const CLACK_PITCH_MAX := 1.6

## Meta keys stashed on wired controls so we never double-connect and so the
## dedup timer is automatically cleaned up when the node is freed.
const META_WIRED := &"_ui_audio_wired"
const META_LAST_HOVER_MS := &"_ui_audio_last_hover_ms"
## Last known text length on a wired text input, used to detect per-character entry.
const META_TEXT_LEN := &"_ui_audio_text_len"
## Opt-in marker for locked controls: group `ui_locked` or meta `ui_locked = true`.
const LOCKED_GROUP := &"ui_locked"
const META_LOCKED := &"ui_locked"

## Interaction kinds, exposed so tests (and future callers) can query the mix policy
## without touching audio.
enum Kind { HOVER, PRESSED, LOCKED, CLACK }

var _hover_streams: Array[AudioStream] = []
var _pool: Array[AudioStreamPlayer] = []
var _rr_cursor: int = 0
var _last_hover_index: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Keep working while the tree is paused (the pause menu is autoloaded and
	# always-processes, and its buttons must still tick).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_preload_streams()
	_build_pool()
	# Catch controls that enter the tree after boot (popups, sub-screens, future UI).
	get_tree().node_added.connect(_on_node_added)
	# Wire everything already present (boot scene + autoloaded UI like PauseMenu).
	_scan(get_tree().root)


# --- Public helpers ----------------------------------------------------------


## Plays a hover tick manually. Useful for non-Button custom controls.
func play_hover() -> void:
	_play_kind(Kind.HOVER)


## Plays a press confirmation manually.
func play_pressed() -> void:
	_play_kind(Kind.PRESSED)


## Plays a keyboard-style clack manually (e.g. for a custom text control).
func play_clack() -> void:
	_play_kind(Kind.CLACK)


## Marks (or clears) a control as locked: hover/press then play the muted locked
## sound instead of the normal ones. Equivalent to adding it to the `ui_locked`
## group or setting the `ui_locked` meta.
func set_locked(control: Control, locked: bool) -> void:
	if not is_instance_valid(control):
		return
	control.set_meta(META_LOCKED, locked)


# --- Wiring ------------------------------------------------------------------


func _on_node_added(node: Node) -> void:
	_wire(node)


func _scan(root: Node) -> void:
	_wire(root)
	for child in root.get_children():
		_scan(child)


func _wire(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	elif node is LineEdit:
		_wire_line_edit(node as LineEdit)
	elif node is TextEdit:
		_wire_text_edit(node as TextEdit)
	elif node is TabContainer:
		_wire_tabs(node as TabContainer)


func _wire_button(button: BaseButton) -> void:
	if button.has_meta(META_WIRED):
		return
	button.set_meta(META_WIRED, true)
	button.mouse_entered.connect(func() -> void: _on_button_hover(button))
	button.focus_entered.connect(func() -> void: _on_button_hover(button))
	button.pressed.connect(func() -> void: _on_button_pressed(button))


func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta(META_WIRED):
		return
	tabs.set_meta(META_WIRED, true)
	# Selection covers keyboard/controller tab changes.
	if tabs.has_signal("tab_selected"):
		tabs.tab_selected.connect(func(_index: int) -> void: _play_kind(Kind.PRESSED))
	# Hover lives on the internal TabBar in Godot 4.
	if tabs.has_method("get_tab_bar"):
		var bar := tabs.get_tab_bar()
		if is_instance_valid(bar) and bar.has_signal("tab_hovered"):
			bar.tab_hovered.connect(func(_index: int) -> void: _play_kind(Kind.HOVER))


func _wire_line_edit(line_edit: LineEdit) -> void:
	if line_edit.has_meta(META_WIRED):
		return
	line_edit.set_meta(META_WIRED, true)
	line_edit.set_meta(META_TEXT_LEN, line_edit.text.length())
	line_edit.text_changed.connect(func(new_text: String) -> void: _on_text_changed(line_edit, new_text))


func _wire_text_edit(text_edit: TextEdit) -> void:
	if text_edit.has_meta(META_WIRED):
		return
	text_edit.set_meta(META_WIRED, true)
	text_edit.set_meta(META_TEXT_LEN, text_edit.text.length())
	# TextEdit.text_changed carries no argument, so read the current text directly.
	text_edit.text_changed.connect(func() -> void: _on_text_changed(text_edit, text_edit.text))


# --- Signal handlers ---------------------------------------------------------


func _on_button_hover(button: BaseButton) -> void:
	if not _can_interact(button):
		return
	var now := int(Time.get_ticks_msec())
	var last := int(button.get_meta(META_LAST_HOVER_MS, -HOVER_DEDUP_MS - 1))
	if now - last < HOVER_DEDUP_MS:
		return
	button.set_meta(META_LAST_HOVER_MS, now)
	_play_kind(Kind.LOCKED if _is_locked(button) else Kind.HOVER)


func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_play_kind(Kind.LOCKED if _is_locked(button) else Kind.PRESSED)


func _can_interact(button: BaseButton) -> bool:
	return (
		is_instance_valid(button)
		and not button.disabled
		and button.is_visible_in_tree()
		and button.mouse_filter != Control.MOUSE_FILTER_IGNORE
	)


func _is_locked(control: Control) -> bool:
	return control.is_in_group(LOCKED_GROUP) or bool(control.get_meta(META_LOCKED, false))


## Clacks once per character added to a focused text input. The stored length is
## always refreshed (even while unfocused) so programmatic `text =` sets never
## produce a clack, and a multi-character paste yields a single clack.
func _on_text_changed(control: Control, new_text: String) -> void:
	if not is_instance_valid(control):
		return
	var previous := int(control.get_meta(META_TEXT_LEN, 0))
	var current := new_text.length()
	control.set_meta(META_TEXT_LEN, current)
	if current > previous and control.has_focus():
		_play_kind(Kind.CLACK)


# --- Playback ----------------------------------------------------------------


func _play_kind(kind: Kind) -> void:
	# Headless runs (CI/GUT) have no audio device; keep wiring intact but stay silent
	# so the suite never trips on a missing audio driver.
	if DisplayServer.get_name() == "headless":
		return
	var stream := _stream_for(kind)
	if stream == null:
		return
	var player := _acquire_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db_for(kind)
	player.pitch_scale = pitch_for(kind)
	player.play()


func _stream_for(kind: Kind) -> AudioStream:
	if _hover_streams.is_empty():
		return null
	# All kinds share the warm Wood Block set; kind is voiced by volume/pitch (see
	# volume_db_for / pitch_for) so the palette stays cohesive and non-arcade.
	if kind == Kind.HOVER:
		return _hover_streams[_next_hover_index()]
	# Pressed/locked pick a clip at random for a little variation too.
	return _hover_streams[_rng.randi_range(0, _hover_streams.size() - 1)]


func _acquire_player() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	for player in _pool:
		if not player.playing:
			return player
	# Every voice is busy: steal the next one in round-robin order.
	var player := _pool[_rr_cursor % _pool.size()]
	_rr_cursor = (_rr_cursor + 1) % _pool.size()
	return player


func _next_hover_index() -> int:
	var index := pick_next_index(_last_hover_index, _hover_streams.size(), _rng)
	_last_hover_index = index
	return index


# --- Mix policy (static, testable) ------------------------------------------


## Chooses the next hover clip index at random, never repeating `last` back-to-back
## when more than one clip is available. Pure and deterministic given `rng`.
static func pick_next_index(last: int, count: int, rng: RandomNumberGenerator) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	var index := rng.randi_range(0, count - 1)
	if index == last:
		index = (index + 1) % count
	return index


## Player volume (dB) for each interaction kind, before the `UI` bus / user trim.
static func volume_db_for(kind: Kind) -> float:
	match kind:
		Kind.HOVER:
			return HOVER_VOLUME_DB
		Kind.PRESSED:
			return PRESSED_VOLUME_DB
		Kind.LOCKED:
			return LOCKED_VOLUME_DB
		Kind.CLACK:
			return CLACK_VOLUME_DB
		_:
			return HOVER_VOLUME_DB


## Player pitch scale for each interaction kind. Hover adds a tiny random wobble so
## repeated ticks never sound identical.
func pitch_for(kind: Kind) -> float:
	match kind:
		Kind.HOVER:
			return _rng.randf_range(HOVER_PITCH_MIN, HOVER_PITCH_MAX)
		Kind.PRESSED:
			return PRESSED_PITCH
		Kind.LOCKED:
			return LOCKED_PITCH
		Kind.CLACK:
			return _rng.randf_range(CLACK_PITCH_MIN, CLACK_PITCH_MAX)
		_:
			return 1.0


# --- Setup -------------------------------------------------------------------


func _preload_streams() -> void:
	_hover_streams.clear()
	for path in HOVER_CLIPS:
		var stream := load(path)
		if stream is AudioStream:
			_hover_streams.append(stream)
		else:
			push_warning("UiAudio: could not load hover clip '%s'." % path)


func _build_pool() -> void:
	for child in get_children():
		child.queue_free()
	_pool.clear()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "UiVoice%d" % i
		player.bus = UI_BUS
		add_child(player)
		_pool.append(player)
