extends Control

## Shop screen controller. Owns the (placeholder) game state, listens to the
## ShopUI's intent signals, and drives the dialogue box. As the core slice grows
## (see docs/phase-task.md) this is where the workbench, journal, and phone screens get
## pushed/popped.

const DAY_START_HOUR: int = 7   # Shop opens 07:00.
const DAY_END_HOUR: int = 20    # Shop closes 20:00.
const TOTAL_DAYS: int = 5       # Five-day loop.

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this in the inspector to watch the clock move faster while testing.
@export var seconds_per_hour: float = 60.0

@onready var _ui: ShopUI = %ShopUI
@onready var _dialogue: DialogueBox = %DialogueBox

# --- Placeholder state until the delivery/restoration systems exist ---
var _day: int = 1
var _hour: int = DAY_START_HOUR
var _unrestored := {
	ShopUI.Rarity.WHITE: 3,
	ShopUI.Rarity.GREEN: 2,
	ShopUI.Rarity.BLUE: 1,
	ShopUI.Rarity.PURPLE: 0,
	ShopUI.Rarity.GOLD: 0,
}
var _restored := {
	ShopUI.Rarity.WHITE: 0,
	ShopUI.Rarity.GREEN: 1,
	ShopUI.Rarity.BLUE: 0,
	ShopUI.Rarity.PURPLE: 0,
	ShopUI.Rarity.GOLD: 0,
}
var _quest_artifacts: int = 1

var _clock_timer: Timer


func _ready() -> void:
	_ui.door_pressed.connect(_on_door_pressed)
	_ui.workbench_pressed.connect(_on_workbench_pressed)
	_ui.journal_pressed.connect(_on_journal_pressed)
	_ui.phone_pressed.connect(_on_phone_pressed)

	# Pause/resume the day clock while a visitor is being answered.
	_dialogue.finished.connect(_on_dialogue_finished)

	_clock_timer = Timer.new()
	_clock_timer.wait_time = seconds_per_hour
	_clock_timer.timeout.connect(_on_hour_tick)
	add_child(_clock_timer)
	_clock_timer.start()

	_refresh_ui()


func _refresh_ui() -> void:
	_ui.set_day(_day, TOTAL_DAYS)
	_ui.set_time(_hour)
	_ui.set_unrestored(_unrestored)
	_ui.set_restored(_restored)
	_ui.set_quest_count(_quest_artifacts)


# --- Time ---------------------------------------------------------------

func _on_hour_tick() -> void:
	_hour += 1
	if _hour > DAY_END_HOUR:
		_advance_day()
	_refresh_ui()


func _advance_day() -> void:
	_hour = DAY_START_HOUR
	_day += 1
	if _day > TOTAL_DAYS:
		# End of the five-day loop — wrap back to Day 1 for now. The real
		# loop reset (knowledge persists, stock/cash clear) lands later.
		_day = 1


# --- UI intent ----------------------------------------------------------

func _on_door_pressed() -> void:
	_clock_timer.stop()  # Freeze the day while talking to a visitor.
	# Demo visitor — the Elderly Auntie's Day 1 beat from aLima.twee.
	_dialogue.start([
		{
			"name": "Elderly Auntie",
			"text": "A frail knock. She clutches a [i]cracked photo frame[/i].",
		},
		{
			"name": "You",
			"text": "Let me see it. I can free the photo without tearing the emulsion.",
		},
		"[b]Elderly Auntie Quest 1 available.[/b]",
	])


func _on_dialogue_finished() -> void:
	_clock_timer.start()  # Resume the day.


func _on_workbench_pressed() -> void:
	print("Shop: open Workbench (work desk)")


func _on_journal_pressed() -> void:
	print("Shop: open Journal")


func _on_phone_pressed() -> void:
	print("Shop: open Phone (marketplace)")
