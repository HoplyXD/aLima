class_name DialogueVars
## Static token substitution for dialogue text.
##
## Replaces authored tokens like "{player}" with live save-state values so
## narrative JSON stays data-driven. Safe headless: when no GameState autoload
## is reachable (isolated tests), tokens fall back to neutral defaults.

const PLAYER_FALLBACK := "Traveler"


static func format(text: String) -> String:
	if text.find("{") < 0:
		return text
	return text.replace("{player}", _player_name())


static func _player_name() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return PLAYER_FALLBACK
	var game_state: Node = tree.root.get_node_or_null("GameState")
	if game_state == null:
		return PLAYER_FALLBACK
	var save_state: SaveState = game_state.save_state
	if save_state == null or save_state.persistent.player_name.is_empty():
		return PLAYER_FALLBACK
	return save_state.persistent.player_name
