class_name ScrapyardHud
extends CanvasLayer
## HUD for the walkable outdoor spaces (scrapyard, mall).
##
## Top-left: phone and journal quick buttons (the overlays open in-place, so
## the player never has to walk back inside just to check the marketplace or
## the book). Top-right: day/clock + quest count. Bottom: the 5-slot carry
## inventory — unsorted scrap bundles into ONE slot (it must go to Ayla before
## it can be restored); restored artifacts fill the remaining slots.

signal phone_pressed
signal journal_pressed

const INVENTORY_SLOTS: int = 5

## Color swatch for each scrap tier, matching ScrapItem's visuals.
const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

const SLOT_EMPTY_COLOR := Color(0.12, 0.12, 0.12, 0.75)
const SLOT_SCRAP_COLOR := Color(0.45, 0.4, 0.32)

@onready var _day_label: Label = $DayLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _hotbar: HBoxContainer = $Hotbar

var _quest_label: Label
var _phone_button: Button
var _journal_button: Button


func _ready() -> void:
	set_day(1, 5)
	set_time(7, 0)
	set_prompt("")
	_build_top_left_buttons()
	_build_quest_label()
	_build_hotbar()
	set_inventory({}, [])


## Top-left quick actions: phone (marketplace) and journal, usable outdoors.
func _build_top_left_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.position = Vector2(24, 24)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_phone_button = Button.new()
	_phone_button.text = "Phone"
	_phone_button.custom_minimum_size = Vector2(120, 48)
	_phone_button.focus_mode = Control.FOCUS_ALL
	_phone_button.pressed.connect(func() -> void: phone_pressed.emit())
	row.add_child(_phone_button)
	_journal_button = Button.new()
	_journal_button.text = "Journal"
	_journal_button.custom_minimum_size = Vector2(120, 48)
	_journal_button.focus_mode = Control.FOCUS_ALL
	_journal_button.pressed.connect(func() -> void: journal_pressed.emit())
	row.add_child(_journal_button)


## Quest count under the day/clock readout (top right).
func _build_quest_label() -> void:
	_quest_label = Label.new()
	_quest_label.name = "QuestLabel"
	_quest_label.anchor_left = 1.0
	_quest_label.anchor_right = 1.0
	_quest_label.offset_left = -260.0
	_quest_label.offset_right = -24.0
	_quest_label.offset_top = 96.0
	_quest_label.offset_bottom = 128.0
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_label.add_theme_font_size_override("font_size", 22)
	add_child(_quest_label)


func set_quest_count(amount: int) -> void:
	if _quest_label != null:
		_quest_label.text = "Quest: %d" % amount


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## Day 0 (tutorial) presentation: time does not exist yet, so no clock readout.
func set_day_zero() -> void:
	_day_label.text = "Day 0"
	_clock_label.text = ""


## hour: 24-hour value. minute: 0..59. Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Refreshes the 5-slot carry inventory. The whole unsorted scrap pool bundles
## into ONE slot (it still needs Ayla's sorting before restoration); `restored`
## entries ({display_name, color: Color}) fill the remaining slots.
func set_inventory(scrap_pool: Dictionary, restored: Array) -> void:
	var slot_index := 0
	var scrap_total := 0
	for count in scrap_pool.values():
		scrap_total += int(count)
	if scrap_total > 0:
		_set_slot(slot_index, "Scrap x%d" % scrap_total, SLOT_SCRAP_COLOR)
		slot_index += 1
	for raw in restored:
		if slot_index >= INVENTORY_SLOTS:
			break
		var entry: Dictionary = raw
		_set_slot(
			slot_index,
			str(entry.get("display_name", "?")),
			entry.get("color", RARITY_COLORS["white"])
		)
		slot_index += 1
	while slot_index < INVENTORY_SLOTS:
		_set_slot(slot_index, "", SLOT_EMPTY_COLOR)
		slot_index += 1


func _set_slot(index: int, text: String, color: Color) -> void:
	if index < 0 or index >= _hotbar.get_child_count():
		return
	var slot: Panel = _hotbar.get_child(index)
	var label: Label = slot.get_child(0)
	label.text = text
	var style := slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = color
		style.border_color = color.darkened(0.4)


func _build_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	for i in INVENTORY_SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(96, 64)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = SLOT_EMPTY_COLOR
		style.border_width_bottom = 4
		style.border_color = SLOT_EMPTY_COLOR.darkened(0.4)
		slot.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = ""
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.anchor_left = 0.0
		label.anchor_top = 0.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 1.0))
		label.add_theme_constant_override("outline_size", 3)
		slot.add_child(label)
		_hotbar.add_child(slot)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
