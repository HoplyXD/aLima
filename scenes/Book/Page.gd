class_name Page
extends Control

## One page inside the 3D journal book. Page numbers are internal leaves: 1 & 2 are
## covers, 3 is the brown inside cover, 4+ are paper. The book reads `number` to
## decide how to draw each leaf.
##
## Presentation only: this node reads GameState to render the Fragment Case and
## journal entries. All persistence and archive routing live in JournalService and
## SeatingService.

const CASE_PAGE_NUMBER: int = 4  ## First paper page (left side of the open spread).
const INDEX_PAGE_NUMBER: int = 5  ## Right side of the first spread: entry list.
const FIRST_ENTRY_PAGE_NUMBER: int = 6

## Placeholder colors for the five fragment slots. These are development stand-ins
## for the final fragment art/geometry; see docs/phase-task.md P9.4.
const SLOT_COLORS: Array[Color] = [
	Color(0.75, 0.60, 0.35),
	Color(0.60, 0.70, 0.40),
	Color(0.50, 0.65, 0.75),
	Color(0.70, 0.55, 0.75),
	Color(0.80, 0.75, 0.45),
]

var number := 0

# Dynamic case UI, created on demand for the case page.
var _slot_container: Control = null
var _slot_panels: Array[Panel] = []

@onready var _text: RichTextLabel = $Background/Text
@onready var _number_label: Label = $Background/Number
@onready var _background: ColorRect = $Background


func _ready() -> void:
	set_number(0)


func set_number(value: int) -> void:
	number = value
	_clear_case_ui()
	_number_label.text = ("- " + str(value - 3) + " -") if value >= 4 else ""
	if value == CASE_PAGE_NUMBER:
		_render_case_page()
	elif value == INDEX_PAGE_NUMBER:
		_render_index_page()
	elif value >= FIRST_ENTRY_PAGE_NUMBER:
		_render_entry_page(value - FIRST_ENTRY_PAGE_NUMBER)
	else:
		_text.text = ""
		_text.visible = true


func _clear_case_ui() -> void:
	if _slot_container != null:
		_slot_container.queue_free()
		_slot_container = null
	_slot_panels.clear()


# --- Fragment Case (page 1) --------------------------------------------------


func _render_case_page() -> void:
	_text.visible = false
	_text.text = ""

	var container := VBoxContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.offset_left = 20.0
	container.offset_top = 20.0
	container.offset_right = -20.0
	container.offset_bottom = -40.0
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	_background.add_child(container)
	_slot_container = container

	var title := Label.new()
	title.text = "Fragment Case"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.1, 0.05, 0.02))
	container.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Seat all five fragments to restore the Master Artifact."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
	container.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(grid)

	var fragments: Dictionary = GameState.save_state.persistent.fragments
	var seated_slot_by_index: Dictionary = {}
	for fragment_id in fragments.keys():
		var fragment: Fragment = fragments[fragment_id]
		if fragment.state == ModelEnums.FragmentState.SEATED:
			seated_slot_by_index[fragment.case_slot_index] = fragment

	for slot_index in range(5):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(56, 80)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.95, 0.93, 0.85)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.4, 0.3, 0.2)
		panel.add_theme_stylebox_override("panel", style)

		var inner := VBoxContainer.new()
		inner.anchors_preset = Control.PRESET_FULL_RECT
		panel.add_child(inner)

		var slot_label := Label.new()
		slot_label.text = "Slot %d" % (slot_index + 1)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15))
		inner.add_child(slot_label)

		if seated_slot_by_index.has(slot_index):
			var fragment: Fragment = seated_slot_by_index[slot_index]
			var placeholder := ColorRect.new()
			placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			placeholder.color = SLOT_COLORS[slot_index % SLOT_COLORS.size()]
			placeholder.tooltip_text = "Seated: %s" % fragment.id
			inner.add_child(placeholder)

			var seated_label := Label.new()
			seated_label.text = "SEATED"
			seated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			seated_label.add_theme_font_size_override("font_size", 10)
			seated_label.add_theme_color_override("font_color", Color(0.1, 0.05, 0.02))
			inner.add_child(seated_label)
		else:
			var empty_label := Label.new()
			empty_label.text = "empty"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty_label.add_theme_font_size_override("font_size", 12)
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
			inner.add_child(empty_label)

		grid.add_child(panel)
		_slot_panels.append(panel)

	var note := Label.new()
	note.text = "Placeholder fragment art — final 3D viewers are Phase 16."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
	container.add_child(note)


# --- Entry index (page 5) ----------------------------------------------------


func _render_index_page() -> void:
	_text.visible = true
	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	var lines: Array[String] = ["[b]Object Archive[/b]\n"]
	if entries.is_empty():
		lines.append("No entries yet. Restore something to begin the archive.")
	else:
		for template_id in entries.keys():
			var entry: JournalEntry = entries[template_id]
			var verdict := ModelEnums.verdict_name(entry.player_verdict).capitalize()
			if verdict.is_empty() or entry.player_verdict == ModelEnums.Verdict.UNKNOWN:
				verdict = "—"
			lines.append(
				"• %s — condition %d — verdict: %s" % [entry.origin, entry.best_condition, verdict]
			)
	_text.text = "\n".join(lines)
	_text.scroll_to_line(0)


# --- Individual entry pages (page 6+) ----------------------------------------


func _render_entry_page(entry_index: int) -> void:
	_text.visible = true
	var entries: Array = GameState.save_state.persistent.journal_entries.values()
	if entry_index < 0 or entry_index >= entries.size():
		_text.text = "[i]No entry on this page yet.[/i]"
		return

	var entry: JournalEntry = entries[entry_index]
	var parts: Array[String] = ["[b]%s[/b]\n" % entry.origin]
	parts.append("Materials: %s" % ", ".join(entry.materials))
	parts.append("Weight: %.0f–%.0f g" % [entry.weight_range.x, entry.weight_range.y])
	parts.append("Best condition: %d/100" % entry.best_condition)
	parts.append("Value range: ₱%.0f–₱%.0f" % [entry.value_range.x, entry.value_range.y])
	parts.append("Clean method: %s" % entry.clean_method.capitalize())
	var verdict := ModelEnums.verdict_name(entry.player_verdict).capitalize()
	if verdict.is_empty() or entry.player_verdict == ModelEnums.Verdict.UNKNOWN:
		verdict = "Not judged"
	parts.append("Your verdict: %s" % verdict)

	if not entry.uncle_notes.is_empty():
		parts.append("\n[b]Uncle's notes[/b]\n[i]%s[/i]" % entry.uncle_notes)
	if not entry.ai_annotations.is_empty():
		parts.append("\n[b]Scanner annotations[/b]\n%s" % entry.ai_annotations)

	_text.text = "\n".join(parts)
	_text.scroll_to_line(0)


## Returns the number of paper pages needed to display all current journal entries.
static func entry_page_count() -> int:
	return GameState.save_state.persistent.journal_entries.size()
