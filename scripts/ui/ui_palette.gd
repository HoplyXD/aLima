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

# --- Expanded League-inspired premium palette ---------------------------------
const DARK_WALNUT := Color(0.13, 0.09, 0.06)
const BURNT_UMBER := Color(0.32, 0.18, 0.10)
const LEATHER_BROWN := Color(0.42, 0.28, 0.18)
const BRONZE := Color(0.55, 0.38, 0.20)
const ANTIQUE_GOLD := Color(0.76, 0.60, 0.30)
const WARM_BEIGE := Color(0.82, 0.74, 0.58)
const OLD_PAPER := Color(0.88, 0.82, 0.68)
const DARK_OLIVE := Color(0.25, 0.28, 0.20)
const MOSS_GREEN := Color(0.38, 0.46, 0.32)
const DEEP_SLATE := Color(0.18, 0.20, 0.22)
const IRON_GRAY := Color(0.32, 0.32, 0.34)

const SOFT_GOLD := Color(0.95, 0.80, 0.42)
const FADED_COPPER := Color(0.72, 0.46, 0.28)
const ANCIENT_EMERALD := Color(0.32, 0.58, 0.42)
const DUSTY_CRIMSON := Color(0.62, 0.22, 0.24)

# --- Rarity glow legend (CLAUDE.md §4-E) --------------------------------------
## The glow legend is FIXED and owned by GlowMapper — these mirror its hex values so
## rarity UI reads identically to the in-world glow. Do not diverge them; if the legend
## ever changes it changes in GlowMapper, and rarity_color() below stays the live source.
const RARITY_WHITE := Color("#cfd2d6")
const RARITY_GREEN := Color("#5bc46a")
const RARITY_BLUE := Color("#4c8cff")
const RARITY_PURPLE := Color("#b066ff")
const RARITY_GOLD := Color("#e6b422")


## Canonical rarity colour, keyed by ModelEnums.Rarity. Delegates to GlowMapper so the
## fixed glow legend has ONE source; replaces the divergent copies that were duplicated
## across storage_screen.gd / shop_hud / artifact_card.
static func rarity_color(rarity: int) -> Color:
	return GlowMapper.get_color(GlowMapper.rarity_to_glow_state(rarity))


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


## Premium carved wooden panel with an inset parchment layer and bronze trim.
## This is the default container look for pop-ups, menus, and HUD panels.
static func wooden_panel_style(
	wood: Color = DARK_WALNUT,
	parchment: Color = PARCHMENT,
	trim: Color = BRONZE,
	radius: int = 10,
	margin: int = 10
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = parchment
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.set_border_width_all(4)
	sb.border_color = wood
	sb.border_width_left = 6
	sb.border_width_top = 6
	sb.border_width_right = 6
	sb.border_width_bottom = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


## Outer carved-wood frame only (no inset parchment). Useful for layering behind
## a parchment panel to create double-frame depth.
static func wood_frame_style(
	wood: Color = DARK_WALNUT, trim: Color = BRONZE, radius: int = 12
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(8)
	sb.border_color = wood
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb


## Bronze decorative trim line. Used under headers or between sections.
static func bronze_separator_style(horizontal: bool = true) -> StyleBoxLine:
	var sb := StyleBoxLine.new()
	sb.color = Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.8)
	sb.thickness = 2
	sb.vertical = not horizontal
	return sb


## A premium button plaque: layered bevel, metallic edge, carved border.
## `state` must be one of: "normal", "hover", "pressed", "disabled", "selected".
static func bronze_button_style(state: StringName = &"normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	sb.set_content_margin_individual(16, 8, 16, 10)

	match state:
		&"hover":
			sb.bg_color = LEATHER_BROWN
			sb.set_border_width_all(3)
			sb.border_color = SOFT_GOLD
			sb.shadow_color = Color(SOFT_GOLD.r, SOFT_GOLD.g, SOFT_GOLD.b, 0.35)
			sb.shadow_size = 8
		&"pressed", &"selected":
			sb.bg_color = BURNT_UMBER
			sb.set_border_width_all(3)
			sb.border_color = ANTIQUE_GOLD
			sb.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
			sb.shadow_size = 2
			sb.shadow_offset = Vector2(0, 2)
		&"disabled":
			sb.bg_color = Color(PARCHMENT.r, PARCHMENT.g, PARCHMENT.b, 0.55)
			sb.set_border_width_all(2)
			sb.border_color = SMOKE
		_:
			sb.bg_color = LEATHER_BROWN
			sb.set_border_width_all(3)
			sb.border_color = BRONZE
			sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 3)
	return sb


## Old manuscript tooltip / catalog card.
static func parchment_tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = OLD_PAPER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2)
	sb.border_color = BURNT_UMBER
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Manuscript card for quest entries, museum catalog notes, and pop-up bodies.
static func manuscript_card_style(
	fill: Color = PARCHMENT, border: Color = BRONZE
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Inventory/storage slot: bronze-framed square with dark parchment interior.
static func inventory_slot_style(
	state: StringName = &"normal", rarity: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)

	match state:
		&"hover":
			sb.bg_color = PARCHMENT_LIGHT
			sb.set_border_width_all(3)
			sb.border_color = SOFT_GOLD
			sb.shadow_color = Color(SOFT_GOLD.r, SOFT_GOLD.g, SOFT_GOLD.b, 0.35)
			sb.shadow_size = 6
		&"selected":
			sb.bg_color = PARCHMENT_LIGHT
			sb.set_border_width_all(3)
			sb.border_color = ANCIENT_EMERALD
			sb.shadow_color = Color(ANCIENT_EMERALD.r, ANCIENT_EMERALD.g, ANCIENT_EMERALD.b, 0.45)
			sb.shadow_size = 8
		_:
			sb.bg_color = PARCHMENT
			sb.set_border_width_all(2)
			sb.border_color = BRONZE
			sb.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
			sb.shadow_size = 2

	if rarity.a > 0.0:
		# Blend a subtle rarity glow into the border.
		var glow := Color(rarity.r, rarity.g, rarity.b, 0.5)
		sb.border_color = sb.border_color.blend(glow)
		sb.shadow_color = Color(rarity.r, rarity.g, rarity.b, 0.25)
		sb.shadow_size = maxi(sb.shadow_size, 6)
	return sb


## Progress/meter bar rail and fill pair.
static func progress_bar_rail_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = IRON_GRAY
	return sb


static func progress_bar_fill_style(accent: Color = BRONZE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.set_corner_radius_all(4)
	sb.border_width_top = 1
	sb.border_color = Color(SOFT_GOLD.r, SOFT_GOLD.g, SOFT_GOLD.b, 0.5)
	return sb


## Ancient engraved checkbox square.
static func checkbox_style(state: StringName = &"normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	sb.set_border_width_all(2)

	match state:
		&"hover":
			sb.bg_color = PARCHMENT_LIGHT
			sb.border_color = SOFT_GOLD
		&"pressed", &"checked":
			sb.bg_color = PARCHMENT_LIGHT
			sb.border_color = ANTIQUE_GOLD
		_:
			sb.bg_color = PARCHMENT
			sb.border_color = BRONZE
	return sb


## Carved scrollbar rail.
static func scrollbar_rail_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK_WALNUT
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = BURNT_UMBER
	return sb


## Bronze scrollbar handle with hover glow.
static func scrollbar_handle_style(hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRONZE if not hover else FADED_COPPER
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = ANTIQUE_GOLD if hover else BRASS
	return sb


## Wooden slider rail + bronze knob.
static func slider_rail_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK_WALNUT
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = BURNT_UMBER
	return sb


static func slider_knob_style(hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRONZE if not hover else FADED_COPPER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	sb.set_border_width_all(2)
	sb.border_color = SOFT_GOLD if hover else ANTIQUE_GOLD
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


## Subtle rarity glow frame for inventory slots and artifact cards.
static func rarity_glow_style(rarity: int) -> StyleBoxFlat:
	var color := rarity_color(rarity)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(color.r, color.g, color.b, 0.6)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.35)
	sb.shadow_size = 8
	return sb
