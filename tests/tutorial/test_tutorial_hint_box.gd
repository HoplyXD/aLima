extends GutTest

## TutorialHintBox: speaker resolution from data, {player} substitution,
## show/hide lifecycle, and pointer-arrow anchoring.

const HintBoxScene := preload("res://dialogue/tutorial_hint_box.tscn")

var _box: TutorialHintBox


func before_each() -> void:
	GameState.initialize("hint-box-test")
	GameState.save_state.persistent.player_name = "Maverick"
	_box = HintBoxScene.instantiate()
	add_child_autofree(_box)


func test_hidden_until_first_hint() -> void:
	assert_false(_box.visible)
	_box.show_hint("yuyu", "Head out the front door.")
	assert_true(_box.visible)


func test_speaker_resolves_from_data() -> void:
	_box.show_hint("yuyu", "Test line")
	assert_eq(_box.get_node("%SpeakerLabel").text, "Tito Yuyu")
	assert_eq(_box.get_node("%PortraitInitial").text, "T")


func test_inner_speaker_uses_player_name() -> void:
	_box.show_hint("inner", "Where did he go?")
	assert_eq(_box.get_node("%SpeakerLabel").text, "Maverick")


func test_unknown_speaker_falls_back_to_id() -> void:
	_box.show_hint("mystery_stranger", "...")
	assert_eq(_box.get_node("%SpeakerLabel").text, "mystery_stranger")


func test_text_substitutes_player_token() -> void:
	_box.show_hint("yuyu", "Good work, {player}!")
	assert_eq(_box.get_node("%HintText").text, "Good work, Maverick!")


func test_pointer_targets_control_top_center() -> void:
	var target := Control.new()
	add_child_autofree(target)
	target.position = Vector2(100, 200)
	target.size = Vector2(50, 40)
	_box.point_at_control(target)
	assert_true(_box.is_pointing())
	assert_eq(_box.arrow_target(), Vector2(125, 200), "Arrow aims at the target's top center")


func test_hide_clears_pointer() -> void:
	_box.show_hint("yuyu", "line")
	_box.point_at_screen_pos(Vector2(10, 10))
	_box.hide_hint()
	assert_false(_box.visible)
	assert_false(_box.is_pointing())
