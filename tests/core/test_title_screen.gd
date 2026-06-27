extends GutTest

## Headless tests for the title screen's New Game / Continue / slot / seed flow.
## These tests do not rely on the rendered scene; they exercise the public helpers
## and seams directly.

const TitleScreenScene := preload("res://scenes/ui/title_screen.tscn")

const TEST_SAVE := "user://test_title_screen_save.json"
const TEST_TEMP := "user://test_title_screen_save.tmp"

var _title: Control


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("title-test-player")
	_title = TitleScreenScene.instantiate()
	add_child_autofree(_title)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	if _title != null and is_instance_valid(_title):
		_title.queue_free()


func test_parse_seed_accepts_valid_numbers() -> void:
	assert_eq(_title._parse_seed("0"), 0)
	assert_eq(_title._parse_seed("12345"), 12345)
	assert_eq(_title._parse_seed("2147483646"), 2147483646)


func test_parse_seed_rejects_invalid_input() -> void:
	assert_eq(_title._parse_seed(""), -1)
	assert_eq(_title._parse_seed("abc"), -1)
	assert_eq(_title._parse_seed("-1"), -1)
	assert_eq(_title._parse_seed("2147483647"), -1)
	assert_eq(_title._parse_seed("12.34"), -1)


func test_start_new_game_sets_seed_and_saves_to_slot() -> void:
	_title._start_new_game(0, 55555)
	assert_true(SaveService.slot_exists(0))
	assert_eq(GameState.run_seed, 55555)
	assert_eq(GameState.loop_index, 1)
	assert_eq(GameState.save_state.run_seed, 55555)
	assert_eq(GameState.save_state.loop_index, 1)


func test_continue_loads_seed_from_slot() -> void:
	_title._start_new_game(1, 77777)
	GameState.initialize("someone-else")
	_title._attempt_continue(1)
	assert_eq(GameState.run_seed, 77777)
	assert_eq(GameState.loop_index, 1)


func test_attempt_continue_surfaces_load_failure() -> void:
	SaveService.select_slot(2)
	SaveService.delete_save_files()
	_title._attempt_continue(2)
	assert_true(not _title._status_label.text.is_empty(), "Status label shows load failure")


func test_slot_buttons_disable_empty_slots_for_continue() -> void:
	_title._in_new_game_flow = false
	_title._refresh_slot_buttons(false)
	for i in SaveService.slot_count():
		var button: Button = _title._slot_buttons[i]
		if SaveService.slot_exists(i):
			assert_false(button.disabled)
		else:
			assert_true(button.disabled)


func test_slot_buttons_enable_empty_slots_for_new_game() -> void:
	_title._in_new_game_flow = true
	_title._refresh_slot_buttons(true)
	for i in SaveService.slot_count():
		var button: Button = _title._slot_buttons[i]
		assert_false(button.disabled, "Empty slots are selectable for New Game")


func test_new_game_seed_produces_deterministic_day1_delivery() -> void:
	# First run: seed 12345, generate day-1 delivery.
	_title._start_new_game(0, 12345)
	var repo := DataRepository.singleton()
	var generator1 := DeliveryGenerator.new(repo, GameState)
	var delivery1 := generator1.generate_day_delivery(1)
	var ids1: Array[String] = []
	for inst in delivery1:
		ids1.append(inst.uid)

	# Second run: same seed, must produce the same delivery IDs.
	_title._start_new_game(0, 12345)
	var generator2 := DeliveryGenerator.new(repo, GameState)
	var delivery2 := generator2.generate_day_delivery(1)
	var ids2: Array[String] = []
	for inst in delivery2:
		ids2.append(inst.uid)

	assert_eq(ids1, ids2, "Same seed produces the same day-1 delivery")

	# Different seed must diverge.
	_title._start_new_game(0, 99999)
	var generator3 := DeliveryGenerator.new(repo, GameState)
	var delivery3 := generator3.generate_day_delivery(1)
	var ids3: Array[String] = []
	for inst in delivery3:
		ids3.append(inst.uid)
	assert_ne(ids1, ids3, "Different seed produces a different day-1 delivery")


func test_continue_restores_seed_for_same_rolls() -> void:
	_title._start_new_game(0, 12345)
	var repo := DataRepository.singleton()
	var generator1 := DeliveryGenerator.new(repo, GameState)
	var delivery1 := generator1.generate_day_delivery(1)
	var ids1: Array[String] = []
	for inst in delivery1:
		ids1.append(inst.uid)

	# Continue from the saved slot.
	GameState.initialize("someone-else")
	_title._attempt_continue(0)
	var generator2 := DeliveryGenerator.new(repo, GameState)
	var delivery2 := generator2.generate_day_delivery(1)
	var ids2: Array[String] = []
	for inst in delivery2:
		ids2.append(inst.uid)

	assert_eq(ids1, ids2, "Continue restores the seed so the same rolls reproduce")
