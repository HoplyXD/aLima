extends Node
## DEV-ONLY auto-start for the Node backend (server/). When the game launches from the
## editor and the marketplace AI mode is "online", this spawns `npm run start` for you
## so you no longer have to run it by hand in a terminal.
##
## Guards — it NEVER spawns a server when any of these hold:
##   * headless (GUT tests) — skipped.
##   * exported / exhibit builds — skipped. Per CLAUDE.md §4-K the exhibit build must
##     never depend on the backend or venue internet; there, switch AI mode to "offline"
##     and the on-device nobodywho LLM (LocalAI) handles banter with no server at all.
##   * AI mode is "offline" — skipped (nobodywho serves banter on-device).
##   * a backend already answering on the port — skipped (never double-launch).
##
## The server is launched in its own console window and LEFT running, so the next editor
## run reuses it (the health check below skips re-launching). Close that window to stop it.

const BACKEND_URL_SETTING := "network/portal/backend_url"
const DEFAULT_BACKEND_URL := "http://localhost:3000"
const HEALTH_PATH := "/health"
const LAUNCH_SCRIPT := "res://server/dev_start.cmd"
const HEALTH_TIMEOUT_S := 1.5


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # tests / CI — never touch the backend
	if not OS.has_feature("editor"):
		return  # exported/exhibit build — offline-first, no auto-spawn (§4-K)
	if OS.get_name() != "Windows":
		# The launcher uses cmd.exe; on other platforms start the server manually.
		return
	if not SettingsService.ai_mode_is_online():
		return  # offline mode uses the on-device nobodywho LLM; no server needed
	await _maybe_launch()


func _maybe_launch() -> void:
	if await _backend_reachable():
		print("[ServerLauncher] backend already running — reusing it.")
		return
	_launch_server()


## True when something answers the backend's /health endpoint (server already up).
func _backend_reachable() -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = HEALTH_TIMEOUT_S
	if http.request(_backend_url() + HEALTH_PATH) != OK:
		http.queue_free()
		return false
	var res: Array = await http.request_completed  # [result, code, headers, body]
	http.queue_free()
	return int(res[0]) == HTTPRequest.RESULT_SUCCESS


func _launch_server() -> void:
	var script_path := ProjectSettings.globalize_path(LAUNCH_SCRIPT)
	if not FileAccess.file_exists(script_path):
		push_warning("[ServerLauncher] launch script missing: %s" % script_path)
		return
	# CreateProcess can't run a .cmd directly, so go through cmd.exe. open_console = true
	# keeps the server's logs visible (and closeable) like the VS Code terminal did.
	var pid := OS.create_process("cmd.exe", ["/c", script_path], true)
	if pid <= 0:
		push_warning("[ServerLauncher] failed to start the backend (is Node/npm installed?).")
		return
	print("[ServerLauncher] starting backend (pid %d) — %s" % [pid, script_path])


func _backend_url() -> String:
	if ProjectSettings.has_setting(BACKEND_URL_SETTING):
		return str(ProjectSettings.get_setting(BACKEND_URL_SETTING))
	return DEFAULT_BACKEND_URL
