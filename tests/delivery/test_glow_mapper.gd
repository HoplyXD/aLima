extends GutTest

## Tests for the fixed six-state glow legend (P3.3).


func test_exact_six_glow_states() -> void:
	assert_eq(ModelEnums.GlowState.WHITE, 0)
	assert_eq(ModelEnums.GlowState.GREEN, 1)
	assert_eq(ModelEnums.GlowState.BLUE, 2)
	assert_eq(ModelEnums.GlowState.PURPLE, 3)
	assert_eq(ModelEnums.GlowState.GOLD, 4)
	assert_eq(ModelEnums.GlowState.FLICKERING, 5)
	assert_eq(ModelEnums.GLOW_STATE_NAMES.size(), 6)


func test_rarity_maps_to_matching_glow() -> void:
	assert_eq(GlowMapper.rarity_to_glow_state(ModelEnums.Rarity.WHITE), ModelEnums.GlowState.WHITE)
	assert_eq(GlowMapper.rarity_to_glow_state(ModelEnums.Rarity.GREEN), ModelEnums.GlowState.GREEN)
	assert_eq(GlowMapper.rarity_to_glow_state(ModelEnums.Rarity.BLUE), ModelEnums.GlowState.BLUE)
	assert_eq(
		GlowMapper.rarity_to_glow_state(ModelEnums.Rarity.PURPLE), ModelEnums.GlowState.PURPLE
	)
	assert_eq(GlowMapper.rarity_to_glow_state(ModelEnums.Rarity.GOLD), ModelEnums.GlowState.GOLD)


func test_carrier_shows_ordinary_glow_before_authorization() -> void:
	for rarity in range(ModelEnums.Rarity.size()):
		var state := GlowMapper.resolve_glow_state(rarity, true, false)
		assert_eq(state, GlowMapper.rarity_to_glow_state(rarity))
		assert_ne(state, ModelEnums.GlowState.FLICKERING)


func test_carrier_shows_flicker_after_authorization() -> void:
	for rarity in range(ModelEnums.Rarity.size()):
		var state := GlowMapper.resolve_glow_state(rarity, true, true)
		assert_eq(state, ModelEnums.GlowState.FLICKERING)


func test_non_carrier_never_flickers() -> void:
	for rarity in range(ModelEnums.Rarity.size()):
		assert_eq(
			GlowMapper.resolve_glow_state(rarity, false, true),
			GlowMapper.rarity_to_glow_state(rarity)
		)
		assert_eq(
			GlowMapper.resolve_glow_state(rarity, false, false),
			GlowMapper.rarity_to_glow_state(rarity)
		)


func test_glow_colors_differ_and_flicker_is_distinct() -> void:
	var colors := {}
	for state in range(ModelEnums.GlowState.size()):
		var color := GlowMapper.get_color(state)
		assert_false(colors.has(color), "Each glow state must have a unique color")
		colors[color] = state
