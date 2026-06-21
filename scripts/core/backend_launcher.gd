extends Node
## Dev convenience: auto-starts the Node backend (the AI banter / scanner / portal
## proxy) so you don't have to run `npm start` by hand. It health-checks first, so it
## never double-starts a server that's already up.
##
## EDITOR/DEV ONLY: exported builds don't ship the `server/` folder, and the API key
## still lives in `server/.env` — never in this client (security invariant K). Starting
## the server does NOT provide a key; set ANTHROPIC_API_KEY in server/.env for live AI.

var _attempted: bool = false


func _ready() -> void:
	SettingsService.online_changed.connect(_on_online_changed)
	if SettingsService.online_enabled():
		_try_start()


func _on_online_changed(enabled: bool) -> void:
	if enabled:
		_try_start()


## One attempt per session, dev-only, never headless.
func _try_start() -> void:
	if _attempted or not OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	_attempted = true
	_start_if_needed()


func _start_if_needed() -> void:
	if await _backend_alive():
		print("[BackendLauncher] backend already running — leaving it be.")
		return
	_spawn()


## True if the backend answers /health (so we don't spawn a duplicate).
func _backend_alive() -> bool:
	var http := HTTPRequest.new()
	http.timeout = 1.5
	add_child(http)
	var err := http.request(_base_url() + "/health")
	if err != OK:
		http.queue_free()
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	return int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200


## Launches `npm start` in the server/ folder (so dotenv reads server/.env), in its own
## console window so you can see the server log + the LIVE/OFFLINE state.
func _spawn() -> void:
	var dir := ProjectSettings.globalize_path("res://server")
	if not DirAccess.dir_exists_absolute(dir):
		print("[BackendLauncher] server/ folder not found at %s — start it manually." % dir)
		return
	var cmd := "cmd.exe" if OS.get_name() == "Windows" else "/bin/sh"
	var inner := 'cd /d "%s" && npm start' if OS.get_name() == "Windows" else 'cd "%s" && npm start'
	var flag := "/c" if OS.get_name() == "Windows" else "-c"
	var pid := OS.create_process(cmd, [flag, inner % dir], true)
	if pid > 0:
		print(
			(
				"[BackendLauncher] launched the backend (pid %d). For LIVE AI, set ANTHROPIC_API_KEY in server/.env."
				% pid
			)
		)
	else:
		print("[BackendLauncher] could not launch the backend — run `npm start` in server/ manually.")


func _base_url() -> String:
	return str(ProjectSettings.get_setting("network/portal/backend_url", "http://localhost:3000")).rstrip(
		"/"
	)
