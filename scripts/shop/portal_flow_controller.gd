extends Node
## Orchestrates the Artifact Found -> Portal Unlock flow.
##
## Listens for fragment_discovered, opens the Artifact Found screen, sends the
## discovery request through PortalClient, and opens the Portal Unlock screen.
## Never seats a fragment directly; that is SeatingService's job.

signal flow_started(fragment_id: String)
signal flow_unlocked(
	fragment_id: String, museum_entry_id: String, used_fallback: bool, fact_card: String
)
signal flow_finished(fragment_id: String)

const ARTIFACT_FOUND_SCENE := "res://scenes/ui/artifact_found_screen.tscn"
const PORTAL_UNLOCK_SCENE := "res://scenes/ui/portal_unlock_screen.tscn"

var _client: PortalClient = null
var _found_screen: ArtifactFoundScreen = null
var _unlock_screen: PortalUnlockScreen = null
var _pending_fragment_id: String = ""


func _ready() -> void:
	EventBus.fragment_discovered.connect(_on_fragment_discovered)
	_client = PortalClient.new()
	_client.discovery_completed.connect(_on_discovery_completed)


func set_client(client: PortalClient) -> void:
	if _client != null:
		_client.discovery_completed.disconnect(_on_discovery_completed)
	_client = client
	_client.discovery_completed.connect(_on_discovery_completed)


func _on_fragment_discovered(fragment_id: String, _instance_id: String) -> void:
	if fragment_id.is_empty():
		return
	_pending_fragment_id = fragment_id
	flow_started.emit(fragment_id)
	_show_found_screen(fragment_id)


func _show_found_screen(fragment_id: String) -> void:
	_close_screens()
	_found_screen = _load_screen(ARTIFACT_FOUND_SCENE) as ArtifactFoundScreen
	if _found_screen == null:
		push_error("PortalFlowController: could not load ArtifactFoundScreen")
		return
	_get_root().add_child(_found_screen)
	_found_screen.closed.connect(_on_found_closed)
	_found_screen.continue_pressed.connect(_on_found_continue)

	var fragment: Fragment = _get_fragment(fragment_id)
	var instance: ObjectInstance = _find_instance_with_fragment(fragment_id)
	_found_screen.present(fragment, instance)
	_request_pause()


func _on_found_continue() -> void:
	if _pending_fragment_id.is_empty():
		return
	var fragment: Fragment = _get_fragment(_pending_fragment_id)
	var instance: ObjectInstance = _find_instance_with_fragment(_pending_fragment_id)
	var condition := 0
	if instance != null:
		condition = int(instance.condition)
	_found_screen.show_loading(true)
	_client.request_discovery(_pending_fragment_id, condition, _format_context(instance))


func _on_discovery_completed(result: PortalResult) -> void:
	if _found_screen != null:
		_found_screen.show_loading(false)

	if not result.is_ok():
		_show_error(result.error)
		return

	var response: PortalDiscoveryResponse = result.response
	flow_unlocked.emit(
		_pending_fragment_id, response.museum_entry_id, response.used_fallback, response.fact_card
	)
	EventBus.portal_completed.emit(
		_pending_fragment_id, response.museum_entry_id, response.used_fallback, response.fact_card
	)
	_show_unlock_screen(response)


func _show_unlock_screen(response: PortalDiscoveryResponse) -> void:
	_close_screens()
	_unlock_screen = _load_screen(PORTAL_UNLOCK_SCENE) as PortalUnlockScreen
	if _unlock_screen == null:
		push_error("PortalFlowController: could not load PortalUnlockScreen")
		return
	_get_root().add_child(_unlock_screen)
	_unlock_screen.closed.connect(_on_unlock_closed)
	_unlock_screen.present(response)


func _on_unlock_closed() -> void:
	var fragment_id := _pending_fragment_id
	_pending_fragment_id = ""
	_close_screens()
	_release_pause()
	flow_finished.emit(fragment_id)


func _on_found_closed() -> void:
	_pending_fragment_id = ""
	_close_screens()
	_release_pause()


func _close_screens() -> void:
	if _found_screen != null:
		_found_screen.queue_free()
		_found_screen = null
	if _unlock_screen != null:
		_unlock_screen.queue_free()
		_unlock_screen = null


func _show_error(message: String) -> void:
	if _found_screen != null:
		_found_screen.show_error(message)
	else:
		push_error("Portal discovery error: %s" % message)


func _format_context(instance: ObjectInstance) -> String:
	if instance == null:
		return ""
	return "opened from %s" % instance.template_id


func _get_fragment(fragment_id: String) -> Fragment:
	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if fragments.has(fragment_id):
		return fragments[fragment_id]
	return null


func _find_instance_with_fragment(fragment_id: String) -> ObjectInstance:
	var inventory: Array = GameState.save_state.loop.inventory
	for item in inventory:
		if item is ObjectInstance and item.fragment_id == fragment_id:
			return item
	return null


func _load_screen(path: String) -> Control:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Control


func _get_root() -> Node:
	return Engine.get_main_loop().root


func _request_pause() -> void:
	DayClock.request_pause(DayClock.PAUSE_PORTAL)


func _release_pause() -> void:
	DayClock.release_pause(DayClock.PAUSE_PORTAL)
