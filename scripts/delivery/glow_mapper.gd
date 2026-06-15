class_name GlowMapper
## Centralized glow legend mapping.
##
## The fixed legend is White, Green, Blue, Purple, Gold, and Flickering
## (CLAUDE.md §4-E). Flickering is a special state, not a new rarity tier.
## Carriers display their ordinary template rarity glow until the Echo phase
## explicitly authorizes flicker. Both 3D placement and 2D triage must use this
## mapper so they cannot disagree.

## Normalized proximity at which the active promoted carrier may reveal its
## flickering glow. Audio leads; flicker confirms (DISC-R10).
const GLOW_REVEAL_AT := 0.60

const COLOR_WHITE := Color("#cfd2d6")
const COLOR_GREEN := Color("#5bc46a")
const COLOR_BLUE := Color("#4c8cff")
const COLOR_PURPLE := Color("#b066ff")
const COLOR_GOLD := Color("#e6b422")
const COLOR_FLICKERING := Color("#ff6a3d")

const GLOW_COLORS: Array[Color] = [
	COLOR_WHITE,
	COLOR_GREEN,
	COLOR_BLUE,
	COLOR_PURPLE,
	COLOR_GOLD,
	COLOR_FLICKERING,
]

const GLOW_DISPLAY_NAMES: Array[String] = [
	"Common",
	"Uncommon",
	"Antique",
	"Rare",
	"Historic",
	"Flickering",
]


## Returns the GlowState for an instance given its template rarity and whether
## the carrier flicker has been authorized by the Echo phase.
static func resolve_glow_state(base_rarity: int, is_carrier: bool, flicker_authorized: bool) -> int:
	if is_carrier and flicker_authorized:
		return ModelEnums.GlowState.FLICKERING
	return rarity_to_glow_state(base_rarity)


## Maps a Rarity enum value to the matching GlowState. Unknown values fall back
## to WHITE.
static func rarity_to_glow_state(rarity: int) -> int:
	match rarity:
		ModelEnums.Rarity.WHITE:
			return ModelEnums.GlowState.WHITE
		ModelEnums.Rarity.GREEN:
			return ModelEnums.GlowState.GREEN
		ModelEnums.Rarity.BLUE:
			return ModelEnums.GlowState.BLUE
		ModelEnums.Rarity.PURPLE:
			return ModelEnums.GlowState.PURPLE
		ModelEnums.Rarity.GOLD:
			return ModelEnums.GlowState.GOLD
		_:
			return ModelEnums.GlowState.WHITE


## Returns the display color for a GlowState.
static func get_color(state: int) -> Color:
	if state < 0 or state >= GLOW_COLORS.size():
		return COLOR_WHITE
	return GLOW_COLORS[state]


## Returns a human-readable name for a GlowState.
static func get_display_name(state: int) -> String:
	if state < 0 or state >= GLOW_DISPLAY_NAMES.size():
		return GLOW_DISPLAY_NAMES[ModelEnums.GlowState.WHITE]
	return GLOW_DISPLAY_NAMES[state]


## Convenience: returns the glow color for an instance without exposing flicker
## before authorization.
static func get_instance_glow_color(
	base_rarity: int, is_carrier: bool, flicker_authorized: bool
) -> Color:
	return get_color(resolve_glow_state(base_rarity, is_carrier, flicker_authorized))
