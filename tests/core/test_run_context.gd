extends GutTest

## Tests for deterministic run context: same seed produces the same sequence,
## different seeds produce different sequences, and streams are independent.


func before_each() -> void:
	GameState.initialize("run-test-player")


func test_same_seed_produces_same_sequence() -> void:
	GameState.new_run(12345)
	var rng1 := GameState.make_rng("placement")
	var rng2 := GameState.make_rng("placement")
	for i in range(10):
		assert_eq(rng1.randf(), rng2.randf())


func test_different_seeds_produce_different_sequences() -> void:
	GameState.new_run(12345)
	var a := GameState.make_rng("placement")
	GameState.new_run(54321)
	var b := GameState.make_rng("placement")
	var different := false
	for i in range(10):
		if a.randf() != b.randf():
			different = true
			break
	assert_true(different, "Different seeds should produce different sequences")


func test_different_stream_names_produce_different_sequences() -> void:
	GameState.new_run(12345)
	var placement := GameState.make_rng("placement")
	var echo := GameState.make_rng("echo")
	assert_ne(placement.randf(), echo.randf())


func test_no_global_random_state_dependency() -> void:
	GameState.new_run(12345)
	var rng := GameState.make_rng("test")
	# Ensure we are not calling global randomize() by checking the RNG seed.
	assert_eq(rng.seed, GameState.derive_seed("test"))
