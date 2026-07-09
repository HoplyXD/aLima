class_name UiPalette
extends RefCounted
## The single source of truth for aLima's UI look: the muted, old-world "junk-shop
## manuscript" palette (dusty browns, faded gold/brass, oxidized green, smoke, bone,
## deep wine) plus small StyleBox factories so hand-built (in-code) UI shares the same
## presentation as the authored `Themes/alima_ui.tres` theme.
##
## Colours are duplicated (as literals) inside alima_ui.tres because a Theme resource
## cannot reference script constants; THIS file is the canonical set — keep the two in
## sync. Everything here is static: `UiPalette.PARCHMENT`, `UiPalette.card_style(...)`.

# --- Core palette -------------------------------------------------------------
const PARCHMENT := Color(0.20, 0.17, 0.12)  ## Warm panel base (aged paper in shadow).
const PARCHMENT_LIGHT := Color(0.26, 0.22, 0.16)  ## Raised/hovered panel base.
const INK := Color(0.12, 0.10, 0.07)  ## Deep brown-black for the darkest fills/text.
const BONE := Color(0.90, 0.85, 0.74)  ## Primary readable text on dark panels.
const BONE_DIM := Color(0.72, 0.68, 0.58)  ## Secondary/label text.
const BRASS := Color(0.74, 0.56, 0.28)  ## Faded-gold accent: borders, headings, focus.
const BRASS_BRIGHT := Color(0.90, 0.72, 0.36)  ## Hover/active brass highlight.
const OXIDIZED := Color(0.38, 0.50, 0.40)  ## Oxidized-green success/positive accent.
const SMOKE := Color(0.42, 0.39, 0.35)  ## Muted grey for worn borders / disabled.
const WINE := Color(0.50, 0.19, 0.22)  ## Deep wine for warnings / failed states.

# --- Rarity glow legend (CLAUDE.md §4-E), muted to fit the palette ------------
const RARITY_WHITE := Color(0.86, 0.83, 0.76)
const RARITY_GREEN := Color(0.52, 0.72, 0.50)
const RARITY_BLUE := Color(0.48, 0.64, 0.82)
const RARITY_PURPLE := Color(0.70, 0.54, 0.80)
const RARITY_GOLD := Color(0.86, 0.70, 0.34)


## Canonical rarity colour, keyed by ModelEnums.Rarity. Replaces the copies that were
## duplicated across storage_screen.gd / shop_hud / artifact_card.
static func rarity_color(rarity: int) -> Color:
	match rarity:
		ModelEnums.Rarity.GREEN:
			return RARITY_GREEN
		ModelEnums.Rarity.BLUE:
			return RARITY_BLUE
		ModelEnums.Rarity.PURPLE:
			return RARITY_PURPLE
		ModelEnums.Rarity.GOLD:
			return RARITY_GOLD
		_:
			return RARITY_WHITE


# --- StyleBox factories -------------------------------------------------------


## A parchment panel: warm fill, soft corners, optional brass edge. Used by in-code
## panels (storage detail, drop zones, trackers) so they match the theme.
static func panel_style(
	fill: Color = PARCHMENT, border: Color = Color(0, 0, 0, 0), radius: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb


## An unrestored artifact card: dusty, rougher, in-progress. Worn smoke border, muted
## fill — reads as "still needs work" at a glance (Tutorial UI master prompt).
static func card_style_unrestored() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.14, 0.10, 0.90)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	sb.set_border_width_all(1)
	sb.border_color = SMOKE
	# A slightly heavier bottom edge reads as sediment/dust settling at the base.
	sb.border_width_bottom = 3
	return sb


## A restored artifact card: complete, honored, stable. Calmer fill, clean brass frame
## — the refined counterpart to card_style_unrestored().
static func card_style_restored() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.13, 0.10, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	sb.set_border_width_all(2)
	sb.border_color = BRASS
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	return sb
