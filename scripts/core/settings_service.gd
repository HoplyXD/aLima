extends Node
## Player settings: display resolution / fullscreen.
##
## Persists to user://settings.cfg and applies the display settings on boot.

const CONFIG_PATH := "user://settings.cfg"

## Marketplace AI banter source. "online" prefers the backend LLM proxy (NegotiationClient);
## "offline" prefers the on-device Godot LLM (LocalAI). Either falls back to the deterministic
## offline bot when its choice is unavailable, so banter never fully breaks (Invariant §4-O).
## Default online because the project runs against a live Groq/OpenAI-compatible backend;
## toggle to offline in the pause menu if you want to run without the backend.
const AI_ONLINE := "online"
const AI_OFFLINE := "offline"
const DEFAULT_AI_MODE := AI_ONLINE

## Audio buses (see default_bus_layout.tres). Everything except music routes through
## SFX (UI and Echo send to it); Music is its own bus. The two settings sliders trim
## SFX and Music independently, so lowering sound effects never touches the BGM.
## `ui_volume` is a fixed internal trim keeping UI ticks subtle inside the SFX bus.
const UI_BUS_NAME := &"UI"
const SFX_BUS_NAME := &"SFX"
const MUSIC_BUS_NAME := &"Music"

## Selectable windowed resolutions.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
## Render small rotating 3D previews of artifacts in the bench picker. Off = text-only
## cards (cheaper on low-end hardware). Default on.
var artifact_previews: bool = true
## Which AI powers marketplace banter (see AI_ONLINE/AI_OFFLINE above).
var ai_mode: String = DEFAULT_AI_MODE
## User trim for UI interaction sounds (0..1). 1.0 leaves hover ≈ -16 dB / press ≈ -10 dB
## relative to Master; 0.0 effectively mutes UI audio.
var ui_volume: float = 1.0
## Sound-effects trim on the SFX bus (0..1) — all non-music audio. 1.0 = unity.
var sfx_volume: float = 1.0
## Background-music trim on the Music bus (0..1). 1.0 = unity, 0.0 = silence.
var music_volume: float = 1.0

var _config_path: String = CONFIG_PATH


func _ready() -> void:
	_load()
	apply_display()
	apply_audio()


## Test seam: redirect the config file.
func set_config_path(path: String) -> void:
	_config_path = path


# --- Display -----------------------------------------------------------------


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_save()
	apply_display()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_save()
	apply_display()


## Applies the window size / mode. No-op when there is no real window (headless tests).
func apply_display() -> void:
	if _is_headless():
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# Leave fullscreen cleanly: a bordered, correctly-sized, centred window.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(resolution)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - resolution) / 2)


func resolution_index() -> int:
	var idx := RESOLUTIONS.find(resolution)
	return idx if idx >= 0 else RESOLUTIONS.size() - 1


# --- Audio -------------------------------------------------------------------


## Sets the UI interaction-sound trim (clamped 0..1) and applies it to the `UI` bus.
func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	_save()
	apply_audio()


## Sets the sound-effects (SFX bus) trim (clamped 0..1) and applies it.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save()
	apply_audio()


## Sets the background-music (Music bus) trim (clamped 0..1) and applies it.
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_save()
	apply_audio()


## Pushes each trim to its audio bus. Missing buses are skipped (e.g. a stripped
## test layout) so audio never crashes headless runs. A 0 trim maps to -80 dB
## (effectively silent) since linear_to_db(0) is -inf.
func apply_audio() -> void:
	_apply_bus_volume(UI_BUS_NAME, ui_volume)
	_apply_bus_volume(SFX_BUS_NAME, sfx_volume)
	_apply_bus_volume(MUSIC_BUS_NAME, music_volume)


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, -80.0 if linear <= 0.0 else linear_to_db(linear))


# --- Online services ---------------------------------------------------------


func set_artifact_previews(value: bool) -> void:
	artifact_previews = value
	_save()


func previews_enabled() -> bool:
	return artifact_previews


## Sets the marketplace AI source ("online" or "offline"); anything else is ignored.
func set_ai_mode(mode: String) -> void:
	if mode != AI_ONLINE and mode != AI_OFFLINE:
		return
	ai_mode = mode
	_save()


## True when banter should prefer the backend LLM proxy; false prefers the on-device LLM.
func ai_mode_is_online() -> bool:
	return ai_mode == AI_ONLINE


# --- Persistence -------------------------------------------------------------


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_config_path) != OK:
		return
	resolution = Vector2i(
		int(cfg.get_value("display", "width", resolution.x)),
		int(cfg.get_value("display", "height", resolution.y)),
	)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	artifact_previews = bool(cfg.get_value("display", "artifact_previews", artifact_previews))
	ai_mode = str(cfg.get_value("ai", "mode", DEFAULT_AI_MODE))
	if ai_mode != AI_ONLINE and ai_mode != AI_OFFLINE:
		ai_mode = DEFAULT_AI_MODE
	ui_volume = clampf(float(cfg.get_value("audio", "ui_volume", ui_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	# Legacy renderer config is ignored; the game always uses Compatibility.


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "width", resolution.x)
	cfg.set_value("display", "height", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "artifact_previews", artifact_previews)
	cfg.set_value("ai", "mode", ai_mode)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(_config_path)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
