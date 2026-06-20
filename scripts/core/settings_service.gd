extends Node
## Player settings: display resolution / fullscreen and the rendering method.
##
## Persists to user://settings.cfg and applies the display settings on boot. The
## renderer (Mobile vs gl_compatibility) cannot be hot-swapped in Godot — switching
## it relaunches the game with --rendering-method. The default is the **Mobile**
## renderer (it draws engine Decals, so restoration conditions show as real decals);
## a device that can't run it falls back to Compatibility, and the Mobile option is
## then locked. The deterministic gameplay is identical on either renderer.

const CONFIG_PATH := "user://settings.cfg"
const RENDERER_MOBILE := "mobile"
const RENDERER_COMPAT := "gl_compatibility"
const DEFAULT_RENDERER := RENDERER_MOBILE

## Selectable windowed resolutions.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
]

var resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
var renderer: String = DEFAULT_RENDERER
## Use live online services (LLM buyer banter, live scanner) when reachable. Default
## on; the marketplace falls back to the offline deterministic banter when this is off
## or a request fails (no connection).
var online_services: bool = true

var _config_path: String = CONFIG_PATH


func _ready() -> void:
	_load()
	apply_display()


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


# --- Online services ---------------------------------------------------------


func set_online_services(value: bool) -> void:
	online_services = value
	_save()


## Whether the live online path (LLM banter) should be attempted. The marketplace
## still falls back to the offline engine if an actual request fails.
func online_enabled() -> bool:
	return online_services


## Applies the window size / mode. No-op when there is no real window (headless tests).
func apply_display() -> void:
	if _is_headless():
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - resolution) / 2)


func resolution_index() -> int:
	var idx := RESOLUTIONS.find(resolution)
	return idx if idx >= 0 else RESOLUTIONS.size() - 1


# --- Renderer ----------------------------------------------------------------


## The renderer actually running now: Mobile/Forward+ expose a RenderingDevice;
## gl_compatibility (OpenGL) does not.
func effective_renderer() -> String:
	return RENDERER_MOBILE if RenderingServer.get_rendering_device() != null else RENDERER_COMPAT


## Whether the Mobile renderer can run here. True when we are already on a
## RenderingDevice renderer. If we are on Compatibility only because the player chose
## it, we assume Mobile is still available; if Compatibility is in force while Mobile
## was the saved/default choice, the device fell back and Mobile is locked.
func mobile_supported() -> bool:
	if RenderingServer.get_rendering_device() != null:
		return true
	return renderer == RENDERER_COMPAT


## Whether we're running from the Godot editor (a play session) rather than an
## exported build. Renderer relaunch only works in an exported build.
func running_in_editor() -> bool:
	return OS.has_feature("editor")


## Persists the renderer choice and relaunches the game to apply it (Godot can't swap
## renderers at runtime; it must reboot with --rendering-method). This only works in
## an exported build — the editor can't relaunch a play session, so there we just save
## and let the caller show a "restart required" message. Returns true if a relaunch
## was actually scheduled (exported build only).
func request_renderer(method: String) -> bool:
	if method != RENDERER_MOBILE and method != RENDERER_COMPAT:
		return false
	renderer = method
	_save()
	if _is_headless() or running_in_editor():
		return false
	OS.set_restart_on_exit(true, ["--rendering-method", method])
	get_tree().quit()
	return true


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
	renderer = str(cfg.get_value("rendering", "renderer", DEFAULT_RENDERER))
	online_services = bool(cfg.get_value("services", "online", online_services))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "width", resolution.x)
	cfg.set_value("display", "height", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("rendering", "renderer", renderer)
	cfg.set_value("services", "online", online_services)
	cfg.save(_config_path)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
