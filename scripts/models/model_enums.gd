class_name ModelEnums
## Shared typed constants for aLima data models.
##
## Every enum here is intentionally exhaustive for Phase 1. New values may be
## added in later phases, but the fixed glow legend (WHITE..GOLD + FLICKERING)
## and the fragment/object state machines must never be widened silently.

## Apparent rarity / glow. Flickering is a presentation/story state, not a new
## rarity tier; it is kept separate so systems can treat it as a flag.
enum Rarity {
	WHITE = 0,  ## Common scrap.
	GREEN = 1,  ## Uncommon.
	BLUE = 2,  ## Antique.
	PURPLE = 3,  ## Rare.
	GOLD = 4,  ## Historically significant.
}

## Runtime object condition/state machine.
enum ObjState {
	DIRTY = 0,
	CLEAN = 1,
	OPEN = 2,
}

## Persistent fragment lifecycle.
enum FragmentState {
	LOCKED = 0,
	RELEASED = 1,
	SEATED = 2,
}

## Result of opening an openable object instance.
enum OpenResult {
	EMPTY = 0,
	TEMPORAL_ECHO = 1,
	FRAGMENT = 2,
}

## Player's final authenticity verdict. The scanner suggests evidence but never
## sets this value (PRD §9.4, §4-G).
enum Verdict {
	UNKNOWN = 0,
	AUTHENTIC = 1,
	REPLICA = 2,
	MODIFIED = 3,
	UNCERTAIN = 4,
}

## Fixed glow legend for presentation. Flickering is a special state, not a new
## rarity tier (CLAUDE.md §4-E). The carrier uses its ordinary template rarity
## glow until the Echo phase explicitly authorizes flicker.
enum GlowState {
	WHITE = 0,  ## Common apparent value.
	GREEN = 1,  ## Uncommon.
	BLUE = 2,  ## Antique.
	PURPLE = 3,  ## Rare.
	GOLD = 4,  ## Historically significant.
	FLICKERING = 5,  ## Route-connected / carrier proximity reveal.
}

const RARITY_NAMES: Array[String] = ["white", "green", "blue", "purple", "gold"]
const OBJ_STATE_NAMES: Array[String] = ["dirty", "clean", "open"]
const FRAGMENT_STATE_NAMES: Array[String] = ["locked", "released", "seated"]
const OPEN_RESULT_NAMES: Array[String] = ["empty", "temporal_echo", "fragment"]
const VERDICT_NAMES: Array[String] = ["unknown", "authentic", "replica", "modified", "uncertain"]
const GLOW_STATE_NAMES: Array[String] = ["white", "green", "blue", "purple", "gold", "flickering"]

## Helpers to convert between enum values and stable string IDs.


static func rarity_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := RARITY_NAMES.find(normalized)
	return Rarity.WHITE if idx < 0 else idx


static func rarity_name(value: int) -> String:
	if value < 0 or value >= RARITY_NAMES.size():
		return RARITY_NAMES[Rarity.WHITE]
	return RARITY_NAMES[value]


static func obj_state_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := OBJ_STATE_NAMES.find(normalized)
	return ObjState.DIRTY if idx < 0 else idx


static func obj_state_name(value: int) -> String:
	if value < 0 or value >= OBJ_STATE_NAMES.size():
		return OBJ_STATE_NAMES[ObjState.DIRTY]
	return OBJ_STATE_NAMES[value]


static func fragment_state_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := FRAGMENT_STATE_NAMES.find(normalized)
	return FragmentState.LOCKED if idx < 0 else idx


static func fragment_state_name(value: int) -> String:
	if value < 0 or value >= FRAGMENT_STATE_NAMES.size():
		return FRAGMENT_STATE_NAMES[FragmentState.LOCKED]
	return FRAGMENT_STATE_NAMES[value]


static func open_result_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := OPEN_RESULT_NAMES.find(normalized)
	return OpenResult.EMPTY if idx < 0 else idx


static func open_result_name(value: int) -> String:
	if value < 0 or value >= OPEN_RESULT_NAMES.size():
		return OPEN_RESULT_NAMES[OpenResult.EMPTY]
	return OPEN_RESULT_NAMES[value]


static func verdict_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := VERDICT_NAMES.find(normalized)
	return Verdict.UNKNOWN if idx < 0 else idx


static func verdict_name(value: int) -> String:
	if value < 0 or value >= VERDICT_NAMES.size():
		return VERDICT_NAMES[Verdict.UNKNOWN]
	return VERDICT_NAMES[value]


static func glow_state_from_name(name: String) -> int:
	var normalized := name.to_lower().strip_edges()
	var idx := GLOW_STATE_NAMES.find(normalized)
	return GlowState.WHITE if idx < 0 else idx


static func glow_state_name(value: int) -> String:
	if value < 0 or value >= GLOW_STATE_NAMES.size():
		return GLOW_STATE_NAMES[GlowState.WHITE]
	return GLOW_STATE_NAMES[value]
