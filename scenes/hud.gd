extends CanvasLayer

## HUD + shop controller. Lives on the HUD CanvasLayer. Wires the buttons, runs
## the day clock, and drives the dialogue box + visitor sprite.

const DAY_START_HOUR := 7
const DAY_END_HOUR := 20
const TOTAL_DAYS := 5

enum Rarity { WHITE, GREEN, BLUE, PURPLE, GOLD }

## Display info per rarity, indexed by the Rarity enum order.
const RARITY := [
	{"name": "W", "color": "cfd2d6"},
	{"name": "G", "color": "5bc46a"},
	{"name": "B", "color": "4c8cff"},
	{"name": "P", "color": "b066ff"},
	{"name": "Gd", "color": "e6b422"},
]

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this in the inspector to watch the clock move faster while testing.
@export var seconds_per_hour: float = 60.0

@onready var _dialogue: DialogueBox = $DialogueBox
@onready var _visitor: Sprite3D = get_node("../Visitor")

@onready var _unrestored_counts: RichTextLabel = %UnrestoredCounts
@onready var _restored_counts: RichTextLabel = %RestoredCounts
@onready var _quest_count: Label = %QuestCount
@onready var _day_label: Label = %DayLabel
@onready var _clock_label: Label = %ClockLabel

# --- Placeholder state until the delivery/restoration systems exist ---
var _day := 1
var _hour := DAY_START_HOUR
var _unrestored := {Rarity.WHITE: 3, Rarity.GREEN: 2, Rarity.BLUE: 1, Rarity.PURPLE: 0, Rarity.GOLD: 0}
var _restored := {Rarity.WHITE: 0, Rarity.GREEN: 1, Rarity.BLUE: 0, Rarity.PURPLE: 0, Rarity.GOLD: 0}
var _quest_artifacts := 1

var _clock_timer: Timer


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# DoorButton is wired via the editor signal connection to _on_door_button_pressed.
	# Connect the other three here in code (they have no editor connection).
	$WorkbenchButton.pressed.connect(_on_workbench_pressed)
	$JournalButton.pressed.connect(_on_journal_pressed)
	$PhoneButton.pressed.connect(_on_phone_pressed)
	_dialogue.finished.connect(_on_dialogue_finished)

	_visitor.visible = false

	_clock_timer = Timer.new()
	_clock_timer.wait_time = seconds_per_hour
	_clock_timer.timeout.connect(_on_hour_tick)
	add_child(_clock_timer)
	_clock_timer.start()

	_refresh_ui()
	print("[HUD] ready — all four buttons connected. Click them in the running game.")


func _refresh_ui() -> void:
	_day_label.text = "Day %d of %d" % [_day, TOTAL_DAYS]
	_clock_label.text = _format_time(_hour)
	_unrestored_counts.text = _format_counts(_unrestored)
	_restored_counts.text = _format_counts(_restored)
	_quest_count.text = str(_quest_artifacts)


# --- Time ---------------------------------------------------------------

func _on_hour_tick() -> void:
	_hour += 1
	if _hour > DAY_END_HOUR:
		_hour = DAY_START_HOUR
		_day += 1
		if _day > TOTAL_DAYS:
			_day = 1  # Loop wrap; real reset lands later.
	_refresh_ui()


# --- Buttons ------------------------------------------------------------

func _on_door_button_pressed() -> void:
	print("[HUD] Door clicked")
	# Demo visitor — the Elderly Auntie's Day 1 beat from aLima.twee.
	_open_dialogue([
		{"name": "Elderly Auntie", "text": "A frail knock. She clutches a [i]cracked photo frame[/i]."},
		{"name": "You", "text": "Let me see it. I can free the photo without tearing the emulsion."},
		"[b]Elderly Auntie Quest 1 available.[/b]",
	], true)


func _on_workbench_pressed() -> void:
	print("[HUD] Workbench clicked")
	_open_dialogue(["You step over to the work desk. [i]Restoration mini-games land here soon.[/i]"], false)


func _on_journal_pressed() -> void:
	print("[HUD] Journal clicked")
	_open_dialogue(["You flip open the journal. [i]Entries and the fragment case land here soon.[/i]"], false)


func _on_phone_pressed() -> void:
	print("[HUD] Phone clicked")
	_open_dialogue(["You check your phone. [i]The marketplace to sell restored pieces lands here soon.[/i]"], false)


## Opens the dialogue box, optionally showing the visitor, and freezes the shop
## (clock + buttons) until the conversation ends.
func _open_dialogue(lines: Array, show_visitor: bool) -> void:
	_clock_timer.stop()
	_set_buttons_visible(false)
	_visitor.visible = show_visitor
	_dialogue.start(lines)


func _on_dialogue_finished() -> void:
	_visitor.visible = false
	_set_buttons_visible(true)
	_clock_timer.start()


func _set_buttons_visible(value: bool) -> void:
	$DoorButton.visible = value
	$WorkbenchButton.visible = value
	$JournalButton.visible = value
	$PhoneButton.visible = value


# --- Formatting ---------------------------------------------------------

func _format_counts(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for i in RARITY.size():
		var info: Dictionary = RARITY[i]
		parts.append("[color=#%s]%s %d[/color]" % [info.color, info.name, int(counts.get(i, 0))])
	return "   ".join(parts)


func _format_time(hour: int) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:00 %s" % [h, suffix]
