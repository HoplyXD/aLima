class_name ScrapyardHud
extends CanvasLayer
## HUD for the walkable outdoor spaces (scrapyard, mall).
##
## Top-left: phone and journal quick buttons (the overlays open in-place, so
## the player never has to walk back inside just to check the marketplace or
## the book). Top-right: day/clock + quest count. Bottom: the 5-slot carry
## inventory — unsorted scrap bundles into ONE slot (it must go to Ayla before
## it can be restored); restored artifacts fill the remaining slots as 3D
## rotating preview cards.

signal phone_pressed
signal journal_pressed
signal item_inspected(slot_index: int, data: Dictionary)

const INVENTORY_SLOTS: int = 5

## Color swatch for each scrap tier, matching ScrapItem's visuals.
const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

const SLOT_EMPTY_COLOR := Color(0.12, 0.10, 0.07, 0.78)  ## Warm ink for an empty carry slot.
const SLOT_SCRAP_COLOR := Color(0.45, 0.4, 0.32)

const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")

## Every widget below is now an authored node in scrapyard_hud.tscn (editable in the
## editor); _ready() only wires signals and applies the shared UiPalette styling.
@onready var _top_panel: Panel = $TopPanel
@onready var _prompt_panel: Panel = $PromptPanel
@onready var _day_label: Label = $DayLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _money_label: Label = $MoneyLabel
@onready var _quest_label: Label = $QuestLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _phone_button: Button = $QuickActions/PhoneButton
@onready var _journal_button: Button = $QuickActions/JournalButton

var _slot_data: Array[Dictionary] = []
var _cards: Array[Preview3DCard] = []

## Who currently owns the bottom prompt ("scrap"/"ayla"/"door"/...). Used so a
## background interactable can't clear the cue the player is actually focused on.
var _prompt_owner: String = ""


func _ready() -> void:
	set_day(1, 5)
	set_time(7, 0)
	set_prompt("")
	_style_widgets()
	_wire_quick_actions()
	_build_hotbar()
	set_inventory(0, [])
	_promote_prompt_label()


## Applies the shared UiPalette styling to the authored HUD nodes (panels behind the
## readouts, coloured labels, and the outlined bottom prompt). Node creation and
## layout now live in scrapyard_hud.tscn.
func _style_widgets() -> void:
	_top_panel.add_theme_stylebox_override("panel", UiPalette.wooden_panel_style())
	_prompt_panel.add_theme_stylebox_override("panel", UiPalette.manuscript_card_style())
	_day_label.add_theme_color_override("font_color", UiPalette.BONE)
	_clock_label.add_theme_color_override("font_color", UiPalette.SOFT_GOLD)
	_money_label.add_theme_color_override("font_color", UiPalette.SOFT_GOLD)
	_quest_label.add_theme_color_override("font_color", UiPalette.BONE)
	_prompt_label.add_theme_color_override("font_color", UiPalette.BONE)
	# Readable over any yard background: dark ink outline and a soft drop shadow, so
	# the "Press E" cue never washes out against bright 3D.
	_prompt_label.add_theme_color_override("font_outline_color", UiPalette.INK)
	_prompt_label.add_theme_constant_override("outline_size", 6)
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)


## Wires the authored top-left quick-action buttons (phone / journal).
func _wire_quick_actions() -> void:
	_phone_button.pressed.connect(func() -> void: phone_pressed.emit())
	_journal_button.pressed.connect(func() -> void: journal_pressed.emit())
	# Day 0 (TUT): the journal doesn't exist yet — the player only finds it at the
	# end of Day 0, in the shop. Hide the outdoor Journal button until then.
	_journal_button.visible = not TutorialService.is_tutorial_active()


func set_quest_count(amount: int) -> void:
	if _quest_label != null:
		_quest_label.text = "Fragments: %d" % amount


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
## Shows/clears the bottom interaction prompt. `owner` tags who is driving the
## cue ("scrap"/"ayla"/"door"/...). A non-empty prompt always wins and takes
## ownership (the player's focus moved). An EMPTY prompt only clears if it comes
## from the current owner (or owner == "" for system callers) — this stops a
## background interactable's body_exited/set_enabled from wiping the prompt the
## player is actually looking at, which was the shared-label clobber.
func set_prompt(text: String, owner: String = "") -> void:
	if text.is_empty():
		if owner != "" and _prompt_owner != "" and owner != _prompt_owner:
			return
		_prompt_label.text = ""
		_prompt_label.visible = false
		# Nothing to interact with -> hide the card behind the prompt too, so an
		# empty box never sits above the inventory.
		_prompt_panel.visible = false
		_prompt_owner = ""
		return
	_prompt_label.text = text
	_prompt_label.visible = true
	_prompt_panel.visible = true
	_prompt_owner = owner


## Hides/shows the bottom carry inventory (e.g. while a dialogue box is up, so the
## slots never overlap the conversation).
func set_inventory_visible(is_visible: bool) -> void:
	_hotbar.visible = is_visible


## Draws the interaction prompt above every other HUD control (panels, hotbar and
## any later-added overlay) so a "Press E" cue can never be hidden behind siblings.
func _promote_prompt_label() -> void:
	_prompt_label.z_index = 10
	move_child(_prompt_label, get_child_count() - 1)


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "%s · Day %d of %d" % [DayClock.weekday_name(day), day, total_days]


## Day 0 (tutorial) presentation: it is Sunday, and time does not exist yet.
func set_day_zero() -> void:
	_day_label.text = "Sunday"
	_clock_label.text = ""


## hour: 24-hour value. minute: 0..59. Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Money readout under the day/clock corner (authored MoneyLabel node).
func set_money(amount: int) -> void:
	_money_label.text = "₱%d" % amount


## Refreshes the 5-slot carry inventory. Each unsorted scrap piece takes its OWN
## slot (non-stackable, tinted by its rarity from `scrap_breakdown`); when scrap
## outnumbers the slots left after the restored entries, the final scrap slot
## collapses into a stacked "Scrap xN" so nothing is ever hidden. `restored`
## entries fill the remaining slots as 3D rotating preview cards.
func set_inventory(
	scrap_total: int, restored_data: Array[Dictionary], scrap_breakdown: Dictionary = {}
) -> void:
	var slot_index := 0
	# Clear all slots first
	for i in INVENTORY_SLOTS:
		_clear_slot(i)
		_slot_data[i] = {}

	# One entry per scrap piece (its rarity name), from the breakdown when given;
	# callers without a breakdown fall back to anonymous pieces.
	var units: Array[String] = []
	if not scrap_breakdown.is_empty():
		for rarity_name in RARITY_COLORS.keys():
			for i in int(scrap_breakdown.get(rarity_name, 0)):
				units.append(rarity_name)
	else:
		for i in scrap_total:
			units.append("")

	# Restored pieces keep their slots; scrap fills what remains (min. one slot).
	var restored_slots := mini(restored_data.size(), INVENTORY_SLOTS)
	var scrap_slots := 0
	if not units.is_empty():
		scrap_slots = clampi(INVENTORY_SLOTS - restored_slots, 1, units.size())
	for s in scrap_slots:
		var is_overflow_slot := s == scrap_slots - 1 and units.size() > scrap_slots
		var rarity_name := units[s]
		var color := (
			(
				SLOT_SCRAP_COLOR
				if is_overflow_slot or rarity_name.is_empty()
				else RARITY_COLORS.get(rarity_name, SLOT_SCRAP_COLOR)
			)
			as Color
		)
		var display_name := "Scrap x%d" % (units.size() - s) if is_overflow_slot else "Scrap"
		# The same junk-heap mesh + rarity glow outline the yard pickup shows.
		var scrap_mesh := ScrapItem.build_display_node(
			"white" if rarity_name.is_empty() else rarity_name
		)
		_set_slot(slot_index, display_name, color, scrap_mesh)
		_slot_data[slot_index] = {
			"preview": scrap_mesh,
			"display_name": display_name,
			"color": color,
			"description": "Unsorted scrap from the yard.",
			"is_scrap": true,
		}
		slot_index += 1

	for raw in restored_data:
		if slot_index >= INVENTORY_SLOTS:
			# Free unused previews to prevent leaks
			var preview: Node3D = raw.get("preview") as Node3D
			if preview != null and is_instance_valid(preview):
				preview.queue_free()
			continue
		var entry: Dictionary = raw
		var display_name: String = str(entry.get("display_name", "?"))
		if entry.get("is_quest", false):
			display_name = "⭐ " + display_name
		_set_slot(
			slot_index,
			display_name,
			entry.get("color", RARITY_COLORS["white"]),
			entry.get("preview") as Node3D
		)
		_slot_data[slot_index] = entry.duplicate()
		slot_index += 1

	while slot_index < INVENTORY_SLOTS:
		_clear_slot(slot_index)
		slot_index += 1


func _set_slot(index: int, display_name: String, color: Color, preview: Node3D) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: Preview3DCard = _cards[index]
	if preview == null:
		preview = Node3D.new()
	card.set_spin(true)
	card.set_preview(preview, display_name, color, 0.9)
	# Filled carry slot: bronze-framed parchment with a subtle rarity glow.
	var style := UiPalette.inventory_slot_style(&"normal", color)
	card.add_theme_stylebox_override("panel", style)


func _clear_slot(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: Preview3DCard = _cards[index]
	card.set_spin(false)
	card.set_preview(Node3D.new(), "", Color.WHITE, 0.0)
	# Empty slot: dark parchment bronze frame.
	var style := UiPalette.inventory_slot_style(&"normal")
	card.add_theme_stylebox_override("panel", style)


## Display-only heap preview for a carry-slot scrap card: a random junk-heap mesh
## from ScrapItem's shared kit with a rarity-coloured glow outline. The tint lives
## on the inverted-hull shell (matching the yard pickups), so the same heap mesh
## serves every tier. Falls back to a plain sphere when the kit is not imported.
func _make_scrap_heap(color: Color) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var heap := ScrapItem.pick_heap_mesh()
	if heap != null:
		mesh.mesh = heap
	else:
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		mesh.mesh = ball
	root.add_child(mesh)
	var outline := MeshInstance3D.new()
	outline.mesh = mesh.mesh
	outline.material_override = ScrapItem.make_outline_material(color)
	mesh.add_child(outline)
	return root


func _build_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	_cards.clear()
	_slot_data.clear()

	# Resize hotbar to accommodate 5 Preview3DCards
	_hotbar.custom_minimum_size = Vector2(860, 210)
	_hotbar.offset_left = -430
	_hotbar.offset_right = 430
	_hotbar.offset_top = -230
	_hotbar.offset_bottom = -20

	for i in INVENTORY_SLOTS:
		var card: Preview3DCard = PREVIEW_CARD_SCENE.instantiate()
		_hotbar.add_child(card)
		_cards.append(card)
		_slot_data.append({})
		var slot_index := i
		card.clicked.connect(
			func() -> void: item_inspected.emit(slot_index, _slot_data[slot_index])
		)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
