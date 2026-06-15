extends Node3D

## Production Shop controller, attached to the Shop scene root. Owns the temporary
## shop orchestration and clock state for the stabilized entry scene: it runs the
## day clock, answers the HUD's intent signals, and drives the door -> visitor ->
## dialogue flow. Presentation lives in the HUD (scenes/ui/shop_hud.gd); this node
## holds state and flow, not UI widgets. Real delivery/restoration/loop systems
## replace these placeholders in later phases (see docs/phase-task.md).

const DAY_START_HOUR := 7  ## Shop opens 07:00.
const DAY_END_HOUR := 20  ## Shop closes 20:00.
const TOTAL_DAYS := 5  ## Five-day loop.
const MINUTES_PER_HOUR := 60  ## In-game minutes shown in one clock hour.

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this in the inspector to watch the clock move faster while testing.
@export var seconds_per_hour: float = 60.0

# --- Placeholder state until the delivery/restoration systems exist ---
var _day := 1
var _hour := DAY_START_HOUR
var _hour_elapsed := 0.0  ## Real seconds elapsed inside the current in-game hour.
var _clock_paused := false  ## True while dialogue (or another fullscreen UI) freezes time.

var _unrestored := {
	ShopHud.Rarity.WHITE: 3,
	ShopHud.Rarity.GREEN: 2,
	ShopHud.Rarity.BLUE: 1,
	ShopHud.Rarity.PURPLE: 0,
	ShopHud.Rarity.GOLD: 0,
}
var _restored := {
	ShopHud.Rarity.WHITE: 0,
	ShopHud.Rarity.GREEN: 1,
	ShopHud.Rarity.BLUE: 0,
	ShopHud.Rarity.PURPLE: 0,
	ShopHud.Rarity.GOLD: 0,
}
var _quest_artifacts := 1

@onready var _hud: ShopHud = $HUD
@onready var _visitor: Sprite3D = $Visitor


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_hud.door_pressed.connect(_on_door_pressed)
	_hud.workbench_pressed.connect(_on_workbench_pressed)
	_hud.journal_pressed.connect(_on_journal_pressed)
	_hud.phone_pressed.connect(_on_phone_pressed)
	_hud.dialogue_finished.connect(_on_dialogue_finished)

	_visitor.visible = false

	_refresh_ui()
	print("[Shop] ready — HUD visible, buttons connected. Click them in the running game.")


func _process(delta: float) -> void:
	_advance_clock(delta)


## True while the day clock is actively ticking (paused during dialogue). Exposed
## as a read-only seam for tests; not a gameplay system.
func is_day_running() -> bool:
	return not _clock_paused


func _refresh_ui() -> void:
	_hud.set_unrestored(_unrestored)
	_hud.set_restored(_restored)
	_hud.set_quest_count(_quest_artifacts)
	_update_clock_display()


func _update_clock_display() -> void:
	_hud.set_day(_day, TOTAL_DAYS)
	var minute := int((_hour_elapsed / maxf(seconds_per_hour, 0.0001)) * MINUTES_PER_HOUR)
	minute = clampi(minute, 0, MINUTES_PER_HOUR - 1)
	_hud.set_time(_hour, minute)


# --- Time ---------------------------------------------------------------


## Advances the clock by `delta` real seconds. Kept as a separate method so tests
## can drive it deterministically without waiting for real time.
func _advance_clock(delta: float) -> void:
	if _clock_paused or seconds_per_hour <= 0.0:
		return
	_hour_elapsed += delta
	while _hour_elapsed >= seconds_per_hour:
		_hour_elapsed -= seconds_per_hour
		_on_hour_tick()
	_update_clock_display()


func _on_hour_tick() -> void:
	_hour += 1
	if _hour > DAY_END_HOUR:
		_advance_day()


func _advance_day() -> void:
	_hour = DAY_START_HOUR
	_day += 1
	if _day > TOTAL_DAYS:
		# End of the five-day loop — wrap to Day 1 for now. The real loop reset
		# (knowledge persists, stock/cash clear) lands in Phase 2.
		_day = 1


# --- HUD intent ---------------------------------------------------------


func _on_door_pressed() -> void:
	# Demo visitor — the Elderly Auntie's Day 1 beat from aLima.twee. Phase 10
	# moves authored prose to data/routes/.
	var lines: Array = [
		{
			"name": "Elderly Auntie",
			"text": "A frail knock. She clutches a [i]cracked photo frame[/i].",
		},
		{
			"name": "You",
			"text": "Let me see it. I can free the photo without tearing the emulsion.",
		},
		"[b]Elderly Auntie Quest 1 available.[/b]",
	]
	_open_dialogue(lines, true)


func _on_workbench_pressed() -> void:
	var line := "You step over to the work desk. [i]Restoration mini-games land here soon.[/i]"
	_open_dialogue([line], false)


func _on_journal_pressed() -> void:
	var line := "You flip open the journal. [i]Entries and the fragment case land here soon.[/i]"
	_open_dialogue([line], false)


func _on_phone_pressed() -> void:
	var line := "You check your phone. [i]The marketplace to sell restored pieces lands here soon.[/i]"
	_open_dialogue([line], false)


## Opens the dialogue box, optionally showing the visitor sprite, and freezes the
## shop (clock + action buttons) until the conversation ends.
func _open_dialogue(lines: Array, show_visitor: bool) -> void:
	_clock_paused = true
	_hud.set_actions_visible(false)
	_visitor.visible = show_visitor
	_hud.start_dialogue(lines)


func _on_dialogue_finished() -> void:
	_visitor.visible = false
	_hud.set_actions_visible(true)
	_clock_paused = false
