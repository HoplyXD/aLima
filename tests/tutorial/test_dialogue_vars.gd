extends GutTest

## DialogueVars token substitution: {player} resolves to the persistent
## player_name, with a neutral fallback when no name has been chosen.


func before_each() -> void:
	GameState.initialize("dialogue-vars-test")


func test_replaces_player_token_with_saved_name() -> void:
	GameState.save_state.persistent.player_name = "Maverick"
	assert_eq(DialogueVars.format("Hello, {player}!"), "Hello, Maverick!")


func test_falls_back_when_name_unset() -> void:
	GameState.save_state.persistent.player_name = ""
	assert_eq(DialogueVars.format("{player}?"), "%s?" % DialogueVars.PLAYER_FALLBACK)


func test_text_without_tokens_is_untouched() -> void:
	GameState.save_state.persistent.player_name = "Maverick"
	var line := "A plain line, no tokens."
	assert_eq(DialogueVars.format(line), line)


func test_multiple_tokens_all_replaced() -> void:
	GameState.save_state.persistent.player_name = "Om"
	assert_eq(DialogueVars.format("{player}, {player}!"), "Om, Om!")
