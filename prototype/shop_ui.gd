class_name ShopUI
extends Control

## Pure presentation layer for the shop screen. It owns no game state — it only
## displays what it is told and reports player intent through signals. The Shop
## controller (shop.gd) listens to these signals and pushes updates back via the
## public set_* methods.

signal door_pressed       ## Player wants to answer the door / accept a visitor.
signal workbench_pressed  ## Player wants to go to the work desk.
signal journal_pressed    ## Player wants to view the journal.
signal phone_pressed      ## Player wants to view the phone (marketplace).

enum Rarity { WHITE, GREEN, BLUE, PURPLE, GOLD }

## Display info per rarity, indexed by the Rarity enum order.
const RARITY := [
	{"name": "W", "color": "cfd2d6"},
	{"name": "G", "color": "5bc46a"},
	{"name": "B", "color": "4c8cff"},
	{"name": "P", "color": "b066ff"},
	{"name": "Gd", "color": "e6b422"},
]

@onready var _door_button: Button = %DoorButton
@onready var _workbench_button: Button = %WorkbenchButton
@onready var _journal_button: Button = %JournalButton
@onready var _phone_button: Button = %PhoneButton

@onready var _unrestored_counts: RichTextLabel = %UnrestoredCounts
@onready var _restored_counts: RichTextLabel = %RestoredCounts
@onready var _quest_count: Label = %QuestCount
@onready var _day_label: Label = %DayLabel
@onready var _clock_label: Label = %ClockLabel


func _ready() -> void:
	_door_button.pressed.connect(func() -> void: door_pressed.emit())
	_workbench_button.pressed.connect(func() -> void: workbench_pressed.emit())
	_journal_button.pressed.connect(func() -> void: journal_pressed.emit())
	_phone_button.pressed.connect(func() -> void: phone_pressed.emit())


## counts: Dictionary keyed by Rarity enum -> int.
func set_unrestored(counts: Dictionary) -> void:
	_unrestored_counts.text = _format_counts(counts)


## counts: Dictionary keyed by Rarity enum -> int (restored, ready to sell).
func set_restored(counts: Dictionary) -> void:
	_restored_counts.text = _format_counts(counts)


func set_quest_count(amount: int) -> void:
	_quest_count.text = str(amount)


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## hour: 24-hour value (the shop runs 7..20). Shown as 12-hour AM/PM.
func set_time(hour: int) -> void:
	_clock_label.text = _format_time(hour)


func _format_counts(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for i in RARITY.size():
		var info: Dictionary = RARITY[i]
		var amount: int = int(counts.get(i, 0))
		parts.append("[color=#%s]%s %d[/color]" % [info.color, info.name, amount])
	return "   ".join(parts)


func _format_time(hour: int) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:00 %s" % [h, suffix]
